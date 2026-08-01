import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import '../../../../core/network/request_cancellation_manager.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/services/device_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../courses/presentation/providers/courses_provider.dart';
import '../../../home/presentation/providers/home_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
// Feature providers to invalidate on logout
import '../../../todo/presentation/providers/todo_provider.dart';
import '../../application/services/check_user_access_service.dart';
import '../../application/services/logout_orchestrator.dart';
import '../../application/services/update_service.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../../data/datasources/update_remote_ds.dart';
import '../../data/repositories/auth_repo_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/update_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/bind_device.dart';
import '../../domain/usecases/check_user_access.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/logout_user.dart';
import '../../domain/usecases/validate_device_exists.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => SupabaseService.client;

@Riverpod(keepAlive: true)
AuthRemoteDataSource authRemoteDataSource(Ref ref) => AuthRemoteDataSource();

// ─── Domain layer wiring (Phase 2) ──────────────────────────────────────────
// AuthRepository is built on top of the same authRemoteDataSourceProvider
// used above, so overriding authRemoteDataSourceProvider in tests (as
// auth_notifier_test.dart already does) transparently flows through to the
// repository and every use case below — no test changes required.

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));

@Riverpod(keepAlive: true)
LoginUser loginUserUseCase(Ref ref) =>
    LoginUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
CheckUserAccess checkUserAccessUseCase(Ref ref) =>
    CheckUserAccess(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
BindDevice bindDeviceUseCase(Ref ref) =>
    BindDevice(ref.watch(authRepositoryProvider));

// Intentionally unused in production — see doc comment on LogoutUser for why
// Auth.logout() uses LogoutOrchestrator instead. Kept as a documented,
// tested fallback.
@Riverpod(keepAlive: true)
LogoutUser logoutUserUseCase(Ref ref) =>
    LogoutUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
ValidateDeviceExists validateDeviceExistsUseCase(Ref ref) =>
    ValidateDeviceExists(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
GetCurrentUser getCurrentUserUseCase(Ref ref) =>
    GetCurrentUser(ref.watch(authRepositoryProvider));

@Riverpod(keepAlive: true)
UpdateRemoteDataSource updateRemoteDataSource(Ref ref) =>
    UpdateRemoteDataSource();

@Riverpod(keepAlive: true)
UpdateService updateService(Ref ref) =>
    UpdateService(ref.watch(updateRemoteDataSourceProvider));

// ─── Auth Notifier (Single Source of Truth) ─────────────────────────────────

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  StreamSubscription? _authSubscription;
  late final AuthRemoteDataSource _remoteDataSource;
  CheckUserAccessService? _accessService;

  @override
  AuthState build() {
    _remoteDataSource = ref.watch(authRemoteDataSourceProvider);
    _listenToSupabaseAuthChanges();
    ref.onDispose(() {
      _authSubscription?.cancel();
      _accessService?.stop();
    });

    // Kick off session check — UI shows splash via AuthInitializing.
    Future.microtask(() => _initializeSession());

    return const AuthInitializing();
  }

  void _safeSetState(AuthState nextState) {
    if (ref.mounted) {
      state = nextState;
    }
  }

  /// Like [_safeSetState], but only for writes coming from
  /// [_initializeSession].
  ///
  /// [_initializeSession] is kicked off unawaited from [build] (see the
  /// `Future.microtask(() => _initializeSession())` call above) purely to
  /// decide the FIRST transition away from [AuthInitializing] on cold
  /// start. Because it isn't awaited, it can still be running when an
  /// explicit user action — login(), logout(), or verifyAccess() — starts
  /// and finishes first. If that happens, _initializeSession's eventual
  /// result is stale by definition: a real, more recent state decision has
  /// already superseded it, and writing over it would silently undo a
  /// successful login (or any other explicit transition).
  ///
  /// Guarding on `state is AuthInitializing` scopes _initializeSession to
  /// only ever perform the one transition it exists to make, and never
  /// interferes with anything that happens after.
  void _safeSetStateIfStillInitializing(AuthState nextState) {
    if (ref.mounted && state is AuthInitializing) {
      state = nextState;
    }
  }

  // ─── Unified Error Policy ──────────────────────────────────────────────
  //
  // Applies to _initializeSession(), login(), and verifyAccess() whenever
  // an unexpected exception is caught (i.e. NOT an explicit
  // access.isAllowed == false from checkUserAccess(), which is always
  // handled as AuthRestricted regardless of this policy).
  //
  // - Transient error (no internet, timeout, socket failure, or a
  //   ServerException whose message indicates a network/connection issue):
  //   the server did not actually deny access — it was unreachable.
  //   We must NOT force the user out of an authenticated/restricted state
  //   on a network blip. Behavior: log and preserve the current state
  //   (return without calling _safeSetState).
  //
  // - Non-transient error (anything else — unexpected parsing errors,
  //   null appUser, programming errors, etc.): treated as unsafe to trust,
  //   fall back to AuthUnauthenticated so the user re-authenticates
  //   cleanly rather than being stuck in an inconsistent state.
  //
  // login() is a special case: there is no prior authenticated state to
  // preserve (the user is actively trying to establish one), so on any
  // exception — transient or not — it still resolves to
  // AuthUnauthenticated(error: ...) with a mapped error key so the login
  // screen can show the right message. The distinction there is only used
  // for logging clarity, not for a different state outcome.
  bool _isTransientAuthError(Object error) {
    if (error is NoInternetException ||
        error is TimeoutException ||
        error is SocketException) {
      return true;
    }

    if (error is ServerException) {
      final message = error.message.toLowerCase();
      return message.contains('network') ||
          message.contains('timeout') ||
          message.contains('connection');
    }

    return false;
  }

  // ─── Session Initialization (App Start) ──────────────────────────────────

  /// Checks for existing Supabase session on cold start.
  /// Drives the router from splash → home/login/restricted.
  ///
  /// Update check runs FIRST — before any session check — so that:
  /// 1. Force updates block access even before login.
  /// 2. Optional update info is carried into [AuthAuthenticated].
  Future<void> _initializeSession() async {
    try {
      // ── Step 1: Check for app updates ───────────────────────────────────
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final svc = ref.read(updateServiceProvider);
      final updateInfo = await svc.checkForUpdate(currentVersion);

      // Force update → block immediately, skip auth
      if (updateInfo.status == UpdateStatus.forceUpdate) {
        _safeSetStateIfStillInitializing(AuthForceUpdate(updateInfo));
        return;
      }

      // ── Step 2: Normal auth session check ───────────────────────────────
      final client = ref.read(supabaseClientProvider);
      final session = client.auth.currentSession;

      if (session == null) {
        _safeSetStateIfStillInitializing(const AuthUnauthenticated());
        return;
      }

      // Session exists — verify access status
      final device = ref.read(deviceServiceProvider);
      final fingerprint = device.fingerprint;
      final deviceValid = await ref.read(validateDeviceExistsUseCaseProvider)(
        session.user.id,
        fingerprint,
      );

      if (!deviceValid) {
        debugPrint(
          '[Auth] Device not in DB — attempting re-bind before logout.',
        );
        try {
          await ref.read(bindDeviceUseCaseProvider)(
            fingerprint,
            device.deviceInfoJson,
            device.platform,
          );
          // Re-bind succeeded — device is now registered; continue normally.
          debugPrint('[Auth] Device re-bound successfully. Resuming session.');
        } catch (e) {
          // Re-bind failed (e.g. max devices reached) — must force logout.
          debugPrint('[Auth] Device re-bind failed: $e. Wiping session.');
          final orchestrator = LogoutOrchestrator(
            supabase: client,
            secureStorage: const FlutterSecureStorage(),
            cancellationManager: ref.read(requestCancellationManagerProvider),
            fcmConfigured: AppConfig.fcmEnabled,
          );
          await orchestrator.forceLocalCleanup();
          _invalidateAllUserProviders();
          _safeSetStateIfStillInitializing(const AuthUnauthenticated());
          return;
        }
      }

      final access = await ref.read(checkUserAccessUseCaseProvider)();

      if (access.isAllowed) {
        final appUser = await ref.read(getCurrentUserUseCaseProvider)();
        if (appUser != null) {
          _safeSetStateIfStillInitializing(
            AuthAuthenticated(
              user: appUser,
              access: access,
              // Carry optional update info so HomeScreen can show the dialog
              updateInfo: updateInfo.status == UpdateStatus.optionalUpdate
                  ? updateInfo
                  : null,
            ),
          );

          // Track activity and session in the background (device already validated/re-bound above)
          await _syncActivityAndSession(appUser, skipBind: true);

          // Start security monitoring (polling + Realtime token_version check)
          _startAccessMonitoring(appUser.id, appUser.tenantId);

          // Log location on app open — fire-and-forget, non-blocking
          await LocationService.logOnAppOpen();
        } else {
          _safeSetStateIfStillInitializing(const AuthUnauthenticated());
        }
      } else {
        // Explicit denial from the server — always AuthRestricted,
        // regardless of the transient-error policy below.
        _safeSetStateIfStillInitializing(
          AuthRestricted(status: access.status, access: access),
        );
      }
    } catch (e) {
      if (_isTransientAuthError(e)) {
        // Network blip, not a real access decision — do not kick the user
        // out of whatever state they're currently in. Splash will simply
        // remain until the app is backgrounded/foregrounded or retried.
        debugPrint(
          '[Auth] Session initialization deferred due to transient error: ${e.runtimeType}: $e',
        );
        return;
      }

      debugPrint('[Auth] Session initialization failed with ${e.runtimeType}: $e');
      _safeSetStateIfStillInitializing(const AuthUnauthenticated());
    }
  }

  // ─── Supabase Auth Stream ────────────────────────────────────────────────

  void _listenToSupabaseAuthChanges() {
    final client = ref.read(supabaseClientProvider);

    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      // Server-side token revocation detected → force logout
      if (data.event == AuthChangeEvent.signedOut ||
          (data.event == AuthChangeEvent.tokenRefreshed &&
              data.session == null)) {
        // Guard: skip if we're already logging out or already unauthenticated.
        // This prevents a race condition where our own signOut() call in
        // forceLocalCleanup() triggers this listener concurrently.
        if (state is! AuthLoggingOut && state is! AuthUnauthenticated) {
          debugPrint('[Auth] Passive revocation detected. Cleaning up.');
          _invalidateAllUserProviders();
          _safeSetState(const AuthUnauthenticated());
        }
      }
    });
  }

  // ─── Login ───────────────────────────────────────────────────────────────

  /// Entry point for LoginScreen.
  /// Transitions: AuthAuthenticating → AuthAuthenticated | AuthRestricted | AuthUnauthenticated(error)
  Future<void> login(String email, String password) async {
    _safeSetState(const AuthAuthenticating());

    try {
      final appUser = await ref.read(loginUserUseCaseProvider)(email, password);

      // Bind device synchronously first to check limits
      final device = ref.read(deviceServiceProvider);
      final fingerprint = device.fingerprint;
      await ref.read(bindDeviceUseCaseProvider)(
        fingerprint,
        device.deviceInfoJson,
        device.platform,
      );

      final access = await ref.read(checkUserAccessUseCaseProvider)();

      if (access.isAllowed) {
        _safeSetState(AuthAuthenticated(user: appUser, access: access));

        // Track activity and session in the background (skip bindDevice — already done above)
        await _syncActivityAndSession(appUser, skipBind: true);

        // Start security monitoring (polling + Realtime token_version check)
        _startAccessMonitoring(appUser.id, appUser.tenantId);

        // Log location on login — fire-and-forget, non-blocking
        await LocationService.logOnAppOpen();

        // Emit Login Event
        ref
            .read(eventBusProvider)
            .emit(
              AuthLoginEvent(
                timestamp: DateTime.now(),
                userId: appUser.id,
                tenantId: appUser.tenantId,
              ),
            );
      } else {
        // Sign out if not allowed, but do not let a cleanup failure override
        // the user-facing restricted-state screen.
        final client = ref.read(supabaseClientProvider);
        try {
          await client.auth.signOut();
        } catch (e) {
          debugPrint('[Auth] Restricted login sign-out failed: $e');
        }
        _safeSetState(AuthRestricted(status: access.status, access: access));
      }
    } catch (e) {
      // Unlike _initializeSession/verifyAccess, login() has no prior
      // authenticated state worth preserving — the user is actively trying
      // to establish a session. Transient vs. non-transient only affects
      // logging clarity here; the outcome is always a mapped error on the
      // login screen.
      if (_isTransientAuthError(e)) {
        debugPrint('[Auth] Login failed due to transient error: ${e.runtimeType}: $e');
      } else {
        debugPrint('[Auth] Login failed with ${e.runtimeType}: $e');
      }

      // Sign out from Supabase if we got an exception after successfully logging in
      try {
        final client = ref.read(supabaseClientProvider);
        if (client.auth.currentSession != null) {
          await client.auth.signOut();
        }
      } catch (_) {}

      // Emit Error Event
      ref
          .read(eventBusProvider)
          .emit(
            ErrorOccurredEvent(
              timestamp: DateTime.now(),
              errorMessage: 'Login failed: $e',
            ),
          );

      _safeSetState(AuthUnauthenticated(error: _mapExceptionToKey(e)));
    }
  }

  void _startAccessMonitoring(String userId, String tenantId) {
    _accessService?.stop();
    _accessService = CheckUserAccessService(
      supabase: ref.read(supabaseClientProvider),
      onAccessDenied: ({required String reason}) =>
          handleAccessDenied(reason: reason),
    );
    _accessService!.start(userId: userId, tenantId: tenantId);
  }

  /// Refreshes state and background tracking after login or cold start.
  Future<void> _syncActivityAndSession(AppUser user, {bool skipBind = false}) async {
    try {
      final device = ref.read(deviceServiceProvider);
      final fingerprint = device.fingerprint;

      // 1. Ensure device is bound (skip if already done in the calling flow)
      if (!skipBind) {
        await ref.read(bindDeviceUseCaseProvider)(
          fingerprint,
          device.deviceInfoJson,
          device.platform,
        );
      }

      // 2. Sync activity timestamps (users.last_seen_at, devices.last_seen)
      await _remoteDataSource.syncUserActivity(
        userId: user.id,
        tenantId: user.tenantId,
        deviceFingerprint: fingerprint,
      );

      // 3. Record session only on fresh login (skipBind=false means this is a login call)
      // On app resume (skipBind=true), skip to avoid flooding the sessions table.
      if (!skipBind) {
        await _remoteDataSource.recordSession(
          userId: user.id,
          tenantId: user.tenantId,
          deviceFingerprint: fingerprint,
          regionId: user.regionId,
          userAgent:
              '${device.platform}: ${device.deviceInfoJson['model'] ?? 'Unknown'}',
        );
      }
    } catch (e) {
      debugPrint('[Auth] Background sync error: $e');
    }
  }

  String _mapExceptionToKey(Object e) {
    if (e is InvalidCredentialsException) return 'errorAuth';
    if (e is EmailNotConfirmedException) return 'errorEmailNotConfirmed';
    if (e is NoInternetException) return 'errorNetwork';
    if (e is RateLimitedException) {
      return 'errorRateLimit:${e.retryAfterSeconds}';
    }
    if (e is MaxDevicesReachedException) return 'errorMaxDevices';
    if (e is DeviceAlreadyBoundException) return 'errorDeviceBound';
    // All typed exceptions are handled above — fall back for unexpected cases.
    // Log the concrete runtime type so an unclassified error is never lost
    // silently behind the generic key.
    debugPrint('[Auth] Unmapped exception type in _mapExceptionToKey: ${e.runtimeType}: $e');
    return 'errorGeneric';
  }

  // ─── Verify Access (used by restricted screens to re-check) ──────────────

  Future<void> verifyAccess() async {
    try {
      final access = await ref.read(checkUserAccessUseCaseProvider)();

      if (access.isAllowed) {
        final appUser = await ref.read(getCurrentUserUseCaseProvider)();
        if (appUser != null) {
          _safeSetState(AuthAuthenticated(user: appUser, access: access));
        } else {
          _safeSetState(const AuthUnauthenticated());
        }
      } else {
        _safeSetState(AuthRestricted(status: access.status, access: access));
      }
    } catch (e) {
      // Unified policy: transient errors never move the user out of their
      // current state. Non-transient errors also stay put here (unlike
      // _initializeSession) because verifyAccess() is called FROM an
      // already-restricted screen — there is no "safe" state to fall back
      // to that's better than what's already showing, so we log and let
      // the user retry explicitly.
      if (_isTransientAuthError(e)) {
        debugPrint('[Auth] Verify access deferred due to transient error: ${e.runtimeType}: $e');
      } else {
        debugPrint('[Auth] Verify access failed with ${e.runtimeType}: $e');
      }
    }
  }

  // ─── Refresh User (used by profile after updates) ─────────────────────────

  Future<void> refreshUser() async {
    try {
      final appUser = await ref.read(getCurrentUserUseCaseProvider)();
      if (appUser != null && state is AuthAuthenticated) {
        final currentState = state as AuthAuthenticated;
        _safeSetState(AuthAuthenticated(user: appUser, access: currentState.access));
      }
    } catch (e) {
      debugPrint('[Auth] Refresh user error: $e');
    }
  }

  // ─── Handle Access Denied (called by CheckUserAccessService) ──────────────

  void handleAccessDenied({required String reason}) {
    debugPrint('[Auth] Access denied — reason: $reason');

    // Emit Access Denied Event
    final currentState = state;
    ref
        .read(eventBusProvider)
        .emit(
          AuthAccessDeniedEvent(
            timestamp: DateTime.now(),
            reason: reason,
            userId: currentState is AuthAuthenticated
                ? currentState.user.id
                : null,
            tenantId: currentState is AuthAuthenticated
                ? currentState.user.tenantId
                : null,
          ),
        );

    logout(flow: 'forced_$reason');
  }

  // ─── Logout (Centralized) ────────────────────────────────────────────────

  /// Centralized logout:
  /// 1. Set state to LoggingOut (router → /login immediately)
  /// 2. Best-effort server cleanup runs FIRST while the session is still
  ///    intact, so server-side revocation actually has a valid token to act on
  /// 3. Clear local session (forceLocalCleanup — the critical step)
  /// 4. Invalidate all user-scoped providers (prevent stale data)
  /// 5. Set state to Unauthenticated
  ///
  /// Deliberately uses LogoutOrchestrator rather than the LogoutUser use
  /// case — see the doc comment on LogoutUser for why.
  Future<void> logout({String flow = 'manual'}) async {
    // Prevent double-logout
    if (state is AuthLoggingOut || state is AuthUnauthenticated) return;

    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;

    // ── Phase 1: Set Logging Out state ──────────────────────────────────────
    _safeSetState(const AuthLoggingOut());

    // Stop security monitoring immediately
    _accessService?.stop();
    _accessService = null;

    final orchestrator = LogoutOrchestrator(
      supabase: client,
      secureStorage: const FlutterSecureStorage(),
      cancellationManager: ref.read(requestCancellationManagerProvider),
      fcmConfigured: AppConfig.fcmEnabled,
    );

    // ── Phase 2: Best-effort server cleanup ────────────────────────────────
    // Keep the current session intact until server-side revocation is attempted.
    try {
      final result = await orchestrator.execute(
        userId: userId,
        logoutFlow: flow,
      );
      debugPrint('[Logout] Server cleanup: ${result.toLog()}');

      ref
          .read(eventBusProvider)
          .emit(
            AuthLogoutEvent(
              timestamp: DateTime.now(),
              userId: userId,
              flow: flow,
            ),
          );
    } catch (e) {
      debugPrint('[Logout] Server cleanup error (non-critical): $e');
    }

    // ── Phase 3: Clear local session securely ───────────────────────────────
    await orchestrator.forceLocalCleanup();

    // ── Phase 4: Invalidate user data Providers ─────────────────────────────
    // Now that the session is wiped, clear memory safely.
    _invalidateAllUserProviders();

    // ── Phase 5: Finalize State ─────────────────────────────────────────────
    // This triggers GoRouter to immediately snap to /login natively.
    _safeSetState(const AuthUnauthenticated());
  }

  /// Centralized provider invalidation — ensures zero data leakage
  /// between user sessions.
  ///
  /// Delegates to each feature's own `invalidateXProviders(ref)` helper
  /// (defined alongside that feature's providers) instead of listing every
  /// individual provider here. This was previously a hand-maintained list
  /// duplicated from each feature file, which had already drifted out of
  /// sync in one case (`todoProvider`, which never existed —
  /// `TodoNotifier` generates `todoNotifierProvider`). Keeping the
  /// invalidation list next to the providers it invalidates means adding a
  /// new user-scoped provider to a feature can no longer silently forget
  /// to wire up its own cleanup.
  void _invalidateAllUserProviders() {
    invalidateProfileProviders(ref);
    invalidateCoursesProviders(ref);
    invalidateTodoProviders(ref);
    invalidateHomeProviders(ref);
    invalidateNotificationsProviders(ref);
  }
}