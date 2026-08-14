// ignore_for_file: unused_field

import 'dart:async';

import 'package:app/app/session/session_invalidation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/config/app_config.dart';
import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import '../../../../core/network/request_cancellation_manager.dart';
import '../../../../core/services/device_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../shared/cross_feature/downloads_shared.dart';
import '../../../../shared/utils/global_error_handler.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/update_info.dart';
import '../../domain/entities/user_access.dart';
import '../../domain/enums/user_role.dart';
import '../policies/auth_error_policy.dart';
import '../services/check_user_access_service.dart';
import '../services/logout_orchestrator.dart';
import 'auth_di_providers.dart';

export 'auth_di_providers.dart';

part 'auth_provider.g.dart';

// ─── Auth Notifier (Single Source of Truth) ─────────────────────────────────
//
// This file now holds only the `Auth` notifier itself. The plain
// dependency-injection providers it depends on (supabaseClientProvider,
// authRepositoryProvider, the use-case providers, updateServiceProvider,
// authActivitySyncServiceProvider, ...) live in `auth_di_providers.dart`
// and are re-exported above so existing imports of `auth_provider.dart`
// across the app keep working unchanged.
//
// Two pieces of logic that used to be private methods on this class were
// also extracted so they're independently unit-testable:
//   - `_isTransientAuthError` / `_mapExceptionToKey` → `AuthErrorPolicy`
//     (application/policies/auth_error_policy.dart)
//   - `_syncActivityAndSession`                     → `AuthActivitySyncService`
//     (application/services/auth_activity_sync_service.dart)

@Riverpod(keepAlive: true)
class Auth extends _$Auth {
  StreamSubscription? _authSubscription;
  late final AuthRemoteDataSource _remoteDataSource;
  CheckUserAccessService? _accessService;

  // ─── Degraded-session retry (AuthDegraded) ───────────────────────────────
  Timer? _degradedRetryTimer;
  int _degradedRetryCount = 0;
  static const _maxDegradedAutoRetries = 5;

  @override
  AuthState build() {
    _remoteDataSource = ref.watch(authRemoteDataSourceProvider);
    _listenToSupabaseAuthChanges();
    ref.onDispose(() {
      _authSubscription?.cancel();
      _accessService?.stop();
      _degradedRetryTimer?.cancel();
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
  /// Guarding on `state is AuthInitializing || state is AuthDegraded`
  /// scopes _initializeSession (including its automatic degraded-session
  /// retries — see `_scheduleDegradedRetry`) to only ever write a state
  /// nobody has explicitly superseded yet, and never interferes with
  /// anything that happens after an explicit user action.
  ///
  /// [AuthDegraded] is included alongside [AuthInitializing] because a
  /// retry attempt re-enters `_initializeSession()` from an
  /// already-[AuthDegraded] state (not [AuthInitializing]) — without this,
  /// every write after the first transient failure would be silently
  /// dropped, including the eventual success/failure that resolves it.
  void _safeSetStateIfStillPending(AuthState nextState) {
    if (ref.mounted && (state is AuthInitializing || state is AuthDegraded)) {
      state = nextState;
    }
  }

  bool _isStudentUser(AppUser user) => user.primaryRole == UserRole.student;

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
        _safeSetStateIfStillPending(AuthForceUpdate(updateInfo));
        return;
      }

      // ── Step 2: Normal auth session check ───────────────────────────────
      final client = ref.read(supabaseClientProvider);
      final session = client.auth.currentSession;

      if (session == null) {
        _safeSetStateIfStillPending(const AuthUnauthenticated());
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
        } catch (e, st) {
          // Re-bind failed (e.g. max devices reached) — must force logout.
          // Sentry-worthy: this forces a real user out of a session they
          // held a moment ago, and "max devices reached" aside, an
          // unexpected failure here is worth knowing the frequency of.
          GlobalErrorHandler.logError(e, st);
          debugPrint('[Auth] Device re-bind failed: $e. Wiping session.');
          final orchestrator = LogoutOrchestrator(
            supabase: client,
            secureStorage: const FlutterSecureStorage(),
            cancellationManager: ref.read(requestCancellationManagerProvider),
            fcmConfigured: AppConfig.fcmEnabled,
          );
          await orchestrator.forceLocalCleanup();
          _invalidateAllUserProviders();
          _safeSetStateIfStillPending(const AuthUnauthenticated());
          return;
        }
      }

      final access = await ref.read(checkUserAccessUseCaseProvider)();

      if (access.isAllowed) {
        final appUser = await ref.read(getCurrentUserUseCaseProvider)();
        if (appUser != null) {
          if (!_isStudentUser(appUser)) {
            debugPrint('[Auth] Non-student user blocked from student app.');
            await _forceLocalSignOutOnly(client);
            _safeSetStateIfStillPending(const AuthUnauthenticated());
            return;
          }

          _safeSetStateIfStillPending(
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
          await ref
              .read(authActivitySyncServiceProvider)
              .syncActivityAndSession(appUser, skipBind: true);

          // Start security monitoring (polling + Realtime token_version check)
          _startAccessMonitoring(appUser.id, appUser.tenantId);

          // Log location on app open — fire-and-forget, non-blocking
          await LocationService.logOnAppOpen();
        } else {
          _safeSetStateIfStillPending(const AuthUnauthenticated());
        }
      } else {
        // Explicit denial from the server — always AuthRestricted,
        // regardless of the transient-error policy below.
        _safeSetStateIfStillPending(
          AuthRestricted(status: access.status, access: access),
        );
      }
    } catch (e, st) {
      if (AuthErrorPolicy.isTransient(e)) {
        // A transient error (no connectivity, timeout, DNS failure, 5xx)
        // is not an explicit denial. If a local session already exists,
        // we must never treat "server unreachable" as "log the user
        // out" — see EduZone_Authentication_Session_Security_Architecture.md
        // Phase 18. `currentSession` is read from local persisted state
        // by the Supabase SDK and does not itself require network access.
        final hasLocalSession =
            ref.read(supabaseClientProvider).auth.currentSession != null;

        if (hasLocalSession) {
          debugPrint(
            '[Auth] Session verification deferred due to transient error '
            '(local session retained, will retry): ${e.runtimeType}: $e',
          );
          _scheduleDegradedRetry();
          return;
        }

        debugPrint(
          '[Auth] Session initialization deferred due to transient error: ${e.runtimeType}: $e',
        );
        _safeSetStateIfStillPending(
          AuthUnauthenticated(error: AuthErrorPolicy.mapExceptionToKey(e)),
        );
        return;
      }

      // Not transient: an unexpected exception type reached the end of
      // _initializeSession (this runs at app startup / cold-start
      // session-restore, not from direct user input like login() does —
      // so unlike a wrong password, this genuinely indicates something
      // worth investigating).
      GlobalErrorHandler.logError(e, st);
      debugPrint('[Auth] Session initialization failed with ${e.runtimeType}: $e');
      _safeSetStateIfStillPending(const AuthUnauthenticated());
    }
  }

  // ─── Degraded-session retry ────────────────────────────────────────────

  /// Enters/updates [AuthDegraded] and schedules an automatic retry of
  /// [_initializeSession] with capped exponential backoff (2s, 4s, 8s,
  /// 16s, 32s — [_maxDegradedAutoRetries] attempts). The local Supabase
  /// session is never touched by this path.
  ///
  /// After the retry cap is reached, auto-retrying stops (to avoid an
  /// unbounded retry storm — see the project's networking-reliability
  /// rules), but the state stays [AuthDegraded] rather than falling back
  /// to [AuthUnauthenticated]: the session is still valid as far as we
  /// know, we simply couldn't confirm it. [retryDegradedSession] lets the
  /// UI offer a manual retry at that point.
  void _scheduleDegradedRetry() {
    if (!ref.mounted) return;

    if (_degradedRetryCount >= _maxDegradedAutoRetries) {
      _safeSetStateIfStillPending(
        AuthDegraded(error: 'errorNetwork', retryAttempt: _degradedRetryCount),
      );
      return;
    }

    _degradedRetryCount++;
    _safeSetStateIfStillPending(
      AuthDegraded(error: 'errorNetwork', retryAttempt: _degradedRetryCount),
    );

    final delaySeconds = 1 << _degradedRetryCount; // 2, 4, 8, 16, 32
    _degradedRetryTimer?.cancel();
    _degradedRetryTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (!ref.mounted || state is! AuthDegraded) return;
      await _initializeSession();
      // A successful (or explicitly-denied) retry moves state out of
      // AuthDegraded — reset the counter so a *future*, unrelated outage
      // starts its own fresh backoff instead of inheriting this one's.
      if (ref.mounted && state is! AuthDegraded) {
        _degradedRetryCount = 0;
      }
    });
  }

  /// Lets the UI (e.g. a "Retry" affordance shown while [AuthDegraded])
  /// force an immediate re-verification instead of waiting for the next
  /// scheduled backoff tick. No-op outside [AuthDegraded].
  Future<void> retryDegradedSession() async {
    if (state is! AuthDegraded) return;
    _degradedRetryTimer?.cancel();
    await _initializeSession();
    if (ref.mounted && state is! AuthDegraded) {
      _degradedRetryCount = 0;
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
    // An explicit login attempt supersedes any pending degraded-session
    // auto-retry from a previous cold start.
    _degradedRetryTimer?.cancel();
    _degradedRetryCount = 0;
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
        if (!_isStudentUser(appUser)) {
          debugPrint('[Auth] Non-student login blocked from student app.');
          await _forceLocalSignOutOnly(ref.read(supabaseClientProvider));
          _safeSetState(const AuthUnauthenticated(error: 'errorAuth'));
          return;
        }

        _safeSetState(AuthAuthenticated(user: appUser, access: access));

        // Offline downloads account isolation (P6.20): purge any local
        // download files/keys left behind by a *different* account that
        // was previously signed into this device, so this login can never
        // inherit or see that account's offline content. Best-effort,
        // fire-and-forget — must never block or fail login. (Playback of
        // another account's downloads is already independently denied by
        // OfflinePolicyEngine even if this purge is delayed or fails.)
        unawaited(
          OfflineAccountGuard(
            localDataSource: ref.read(downloadLocalDataSourceProvider),
            encryptionService: ref.read(encryptionServiceProvider),
          ).purgeDownloadsForOtherAccounts(appUser.id).catchError((e) {
            debugPrint('[Auth] Offline downloads purge failed: $e');
            return 0;
          }),
        );

        // Track activity and session in the background (skip bindDevice — already done above)
        await ref
            .read(authActivitySyncServiceProvider)
            .syncActivityAndSession(appUser, skipBind: true);

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
        } catch (e, st) {
          // A restricted (banned/suspended/locked) account's client-side
          // sign-out failing is worth knowing about: the UI still shows
          // the restricted screen either way, but a real Supabase session
          // may remain locally active until it naturally expires.
          GlobalErrorHandler.logError(e, st);
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
      if (AuthErrorPolicy.isTransient(e)) {
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

      _safeSetState(AuthUnauthenticated(error: AuthErrorPolicy.mapExceptionToKey(e)));
    }
  }

  void _startAccessMonitoring(String userId, String tenantId) {
    _accessService?.stop();
    _accessService = CheckUserAccessService(
      supabase: ref.read(supabaseClientProvider),
      onAccessDenied: ({required String reason}) =>
          handleAccessDenied(reason: reason),
      onAccessRestricted: ({required UserAccess access}) =>
          handleAccessRestricted(access: access),
    );
    _accessService!.start(userId: userId, tenantId: tenantId);
  }

  // ─── Verify Access (used by restricted screens to re-check) ──────────────

  Future<void> verifyAccess() async {
    try {
      final access = await ref.read(checkUserAccessUseCaseProvider)();

      if (access.isAllowed) {
        final appUser = await ref.read(getCurrentUserUseCaseProvider)();
        if (appUser != null) {
          if (!_isStudentUser(appUser)) {
            debugPrint('[Auth] Non-student user blocked during access verify.');
            await _forceLocalSignOutOnly(ref.read(supabaseClientProvider));
            _safeSetState(const AuthUnauthenticated(error: 'errorAuth'));
            return;
          }

          _safeSetState(AuthAuthenticated(user: appUser, access: access));
        } else {
          _safeSetState(const AuthUnauthenticated());
        }
      } else {
        _safeSetState(AuthRestricted(status: access.status, access: access));
      }
    } catch (e, st) {
      // Unified policy: transient errors never move the user out of their
      // current state. Non-transient errors also stay put here (unlike
      // _initializeSession) because verifyAccess() is called FROM an
      // already-restricted screen — there is no "safe" state to fall back
      // to that's better than what's already showing, so we log and let
      // the user retry explicitly.
      if (AuthErrorPolicy.isTransient(e)) {
        debugPrint('[Auth] Verify access deferred due to transient error: ${e.runtimeType}: $e');
      } else {
        // Background/system-triggered call, not direct user input — an
        // unexpected exception type here is worth investigating.
        GlobalErrorHandler.logError(e, st);
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
    } catch (e, st) {
      // Called from the profile screen after an update, not user input —
      // an unexpected failure here is worth investigating.
      GlobalErrorHandler.logError(e, st);
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

  void handleAccessRestricted({required UserAccess access}) {
    debugPrint('[Auth] Access restricted without logout: ${access.status}');
    _safeSetState(AuthRestricted(status: access.status, access: access));
  }

  Future<void> _forceLocalSignOutOnly(SupabaseClient client) async {
    final orchestrator = LogoutOrchestrator(
      supabase: client,
      secureStorage: const FlutterSecureStorage(),
      cancellationManager: ref.read(requestCancellationManagerProvider),
      fcmConfigured: AppConfig.fcmEnabled,
    );
    await orchestrator.forceLocalCleanup();
    _invalidateAllUserProviders();
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

    // Stop any pending degraded-session auto-retry — logging out is an
    // explicit action that must win over a stale retry attempt.
    _degradedRetryTimer?.cancel();

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
  /// Delegates to `invalidateAllUserScopedProviders` (lib/app/session/
  /// session_invalidation.dart), which in turn delegates to each feature's
  /// own `invalidateXProviders(ref)` helper (defined alongside that
  /// feature's providers) instead of listing every individual provider
  /// here. This was previously a hand-maintained list duplicated from each
  /// feature file, which had already drifted out of sync in one case
  /// (`todoProvider`, which never existed — `TodoNotifier` generates
  /// `todoNotifierProvider`). Keeping the invalidation list next to the
  /// providers it invalidates means adding a new user-scoped provider to a
  /// feature can no longer silently forget to wire up its own cleanup.
  ///
  /// The aggregation itself lives in lib/app/ (a composition-root, per
  /// tool/check_architecture.py's EXEMPT_PATH_FRAGMENTS) rather than here,
  /// so this `auth` feature no longer imports courses/home/notifications/
  /// profile/todo internals directly (see ARCH-001).
  void _invalidateAllUserProviders() {
    invalidateAllUserScopedProviders(ref);
  }
}
