// ignore_for_file: unused_field

import 'dart:async';

import 'package:app/app/session/session_invalidation.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import '../../../../core/network/request_cancellation_manager.dart';
import '../../../../core/security/secure_storage_config.dart';
import '../../../../core/services/device_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/sentry_service.dart';
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

  // Monotonic generation used to invalidate stale async auth work. Any
  // explicit auth action (login/logout) or passive revocation increments this
  // value so an older operation cannot mutate state or clear a newer session.
  int _authOperationGeneration = 0;

  int _beginAuthOperation() => ++_authOperationGeneration;

  bool _isCurrentAuthOperation(int generation) =>
      ref.mounted && generation == _authOperationGeneration;

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
    final generation = _authOperationGeneration;
    Future.microtask(() => _initializeSession(generation: generation));

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
  Future<void> _initializeSession({int? generation}) async {
    final operationGeneration = generation ?? _authOperationGeneration;
    if (!_isCurrentAuthOperation(operationGeneration)) return;
    try {
      // ── Step 1: Check for app updates ───────────────────────────────────
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final svc = ref.read(updateServiceProvider);
      final updateInfo = await svc.checkForUpdate(currentVersion);
      if (!_isCurrentAuthOperation(operationGeneration)) return;

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

      // Session exists — the server-side device binding must still be valid.
      // A missing/inactive device is a revoked or otherwise stale session
      // boundary; do not silently re-bind the device from an existing session.
      // A fresh login is required to establish a new device binding.
      final device = ref.read(deviceServiceProvider);
      final fingerprint = device.fingerprint;
      final deviceValid = await ref.read(validateDeviceExistsUseCaseProvider)(
        session.user.id,
        fingerprint,
      );
      if (!_isCurrentAuthOperation(operationGeneration)) return;

      if (!deviceValid) {
        debugPrint(
          '[Auth] Session device is no longer authorized. Wiping session.',
        );
        await _forceLocalSignOutOnly(client);
        _safeSetStateIfStillPending(const AuthUnauthenticated());
        return;
      }

      final access = await ref.read(checkUserAccessUseCaseProvider)();
      if (!_isCurrentAuthOperation(operationGeneration)) return;

      if (access.isAllowed) {
        final appUser = await ref.read(getCurrentUserUseCaseProvider)();
        if (!_isCurrentAuthOperation(operationGeneration)) return;
        if (appUser != null) {
          if (!_isCurrentAuthOperation(operationGeneration)) return;
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
          // Guard, matching login()'s equivalent call: if a concurrent
          // logout()/passive-revocation already superseded this operation,
          // _safeSetStateIfStillPending above was a silent no-op (state is
          // no longer AuthInitializing/AuthDegraded) and that concurrent
          // path has already correctly closed the shared progress-sync
          // session -- reopening it here would undo that.
          if (!_isCurrentAuthOperation(operationGeneration)) return;

          // Section 15 ("user identification policy"): also attach on
          // session restoration (cold start), not just interactive
          // login() — this path is how most authenticated sessions in
          // production actually start, so skipping it here left almost
          // all crash reports without a user identifier attached.
          SentryService.setUserContext(appUser.id);

          openUserProgressSession(ref);

          // Track activity and session in the background (device already validated/re-bound above)
          await ref
              .read(authActivitySyncServiceProvider)
              .syncActivityAndSession(appUser, skipBind: true);
          if (!_isCurrentAuthOperation(operationGeneration)) return;

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
            '(local session retained, will retry): ${e.runtimeType}',
          );
          _scheduleDegradedRetry();
          return;
        }

        debugPrint(
          '[Auth] Session initialization deferred due to transient error: ${e.runtimeType}',
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
      debugPrint('[Auth] Session initialization failed with ${e.runtimeType}');
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
      await _initializeSession(generation: _authOperationGeneration);
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
    await _initializeSession(generation: _authOperationGeneration);
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
          ++_authOperationGeneration;
          debugPrint('[Auth] Passive revocation detected. Cleaning up.');
          _accessService?.stop();
          _accessService = null;
          closeUserProgressSession(ref);
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
    final generation = _beginAuthOperation();

    // An explicit login attempt supersedes any pending degraded-session
    // auto-retry from a previous cold start.
    _degradedRetryTimer?.cancel();
    _degradedRetryCount = 0;
    _safeSetState(const AuthAuthenticating());

    try {
      final appUser = await ref.read(loginUserUseCaseProvider)(email, password);
      if (!_isCurrentAuthOperation(generation)) return;

      // Bind device synchronously first to check limits
      final device = ref.read(deviceServiceProvider);
      final fingerprint = device.fingerprint;
      await ref.read(bindDeviceUseCaseProvider)(
        fingerprint,
        device.deviceInfoJson,
        device.platform,
      );
      if (!_isCurrentAuthOperation(generation)) return;

      final access = await ref.read(checkUserAccessUseCaseProvider)();
      if (!_isCurrentAuthOperation(generation)) return;

      if (access.isAllowed) {
        if (!_isStudentUser(appUser)) {
          debugPrint('[Auth] Non-student login blocked from student app.');
          await _forceLocalSignOutOnly(ref.read(supabaseClientProvider));
          _safeSetState(const AuthUnauthenticated(error: 'errorAuth'));
          return;
        }

        _safeSetState(AuthAuthenticated(user: appUser, access: access));
        if (!_isCurrentAuthOperation(generation)) return;

        // Section 15 ("user identification policy"): attach the opaque
        // user UUID to every subsequent Sentry event so production crash
        // reports for an authenticated session can be triaged/correlated.
        // No email/name/PII is sent — see SentryService.setUserContext doc.
        SentryService.setUserContext(appUser.id);

        openUserProgressSession(ref);

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
            debugPrint(
              '[Auth] Offline downloads purge failed: ${e.runtimeType}',
            );
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
        if (!_isCurrentAuthOperation(generation)) return;
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
          debugPrint(
            '[Auth] Restricted login sign-out failed: ${e.runtimeType}',
          );
        }
        _safeSetState(AuthRestricted(status: access.status, access: access));
      }
    } catch (e, st) {
      if (!_isCurrentAuthOperation(generation)) return;

      // Unlike _initializeSession/verifyAccess, login() has no prior
      // authenticated state worth preserving — the user is actively trying
      // to establish a session. Transient vs. non-transient only affects
      // logging clarity here; the outcome is always a mapped error on the
      // login screen.
      //
      // AUTH-BUG-01: this used to be `catch (e)` with no stack trace and
      // no GlobalErrorHandler.logError call at all (unlike every other
      // catch block in this file), so Sentry only ever received the
      // string "Login failed: errorGeneric" via the ErrorOccurredEvent
      // below -- never the real exception type, message/code, or stack
      // trace. That made a real post-authentication failure (a wrong
      // RPC contract, a missing grant, an RLS rejection) indistinguishable
      // from any other unmapped error after the fact. `InvalidCredentialsException`
      // (and its authless siblings below) are the one case that's an
      // expected, high-volume, user-caused outcome -- not a system
      // defect -- so those are deliberately kept out of Sentry to avoid
      // turning normal typo/forgotten-password attempts into alert noise.
      // Everything else reaching this catch happened *after*
      // signInWithPassword() already succeeded, so it is always worth a
      // full diagnostic record.
      if (AuthErrorPolicy.isTransient(e)) {
        debugPrint(
          '[Auth] Login failed due to transient error: ${e.runtimeType}',
        );
      } else if (e is InvalidCredentialsException ||
          e is EmailNotConfirmedException ||
          e is RateLimitedException) {
        debugPrint('[Auth] Login failed with ${e.runtimeType}');
      } else {
        GlobalErrorHandler.logError(e, st);
        debugPrint(
          '[Auth] Login failed post-authentication with ${e.runtimeType}',
        );
      }

      // Sign out from Supabase if we got an exception after successfully logging in.
      // Best-effort by design: `login()` is already about to surface a
      // mapped error to the login screen regardless of this outcome, and
      // there is no additional local state to roll back — a failure here
      // just means the (already-failed) session may linger briefly until
      // it naturally expires or the next _initializeSession()/logout()
      // cleans it up. Not logged to Sentry to avoid noise on an
      // already-failed login path (unlike the documented sign-out
      // failures in LogoutOrchestrator, which represent an explicit
      // user-initiated logout not completing).
      try {
        final client = ref.read(supabaseClientProvider);
        if (client.auth.currentSession != null) {
          await client.auth.signOut();
        }
      } catch (_) {
        // check-ignore -- documented above: best-effort, non-critical cleanup.
      }

      // Emit Error Event
      ref
          .read(eventBusProvider)
          .emit(
            ErrorOccurredEvent(
              timestamp: DateTime.now(),
              errorMessage:
                  'Login failed: ${AuthErrorPolicy.mapExceptionToKey(e)}',
            ),
          );

      _safeSetState(
        AuthUnauthenticated(error: AuthErrorPolicy.mapExceptionToKey(e)),
      );
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
    final generation = _authOperationGeneration;
    try {
      final access = await ref.read(checkUserAccessUseCaseProvider)();
      if (!_isCurrentAuthOperation(generation)) return;

      if (access.isAllowed) {
        final appUser = await ref.read(getCurrentUserUseCaseProvider)();
        if (!_isCurrentAuthOperation(generation)) return;
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
        debugPrint(
          '[Auth] Verify access deferred due to transient error: ${e.runtimeType}',
        );
      } else {
        // Background/system-triggered call, not direct user input — an
        // unexpected exception type here is worth investigating.
        GlobalErrorHandler.logError(e, st);
        debugPrint('[Auth] Verify access failed with ${e.runtimeType}');
      }
    }
  }

  // ─── Refresh User (used by profile after updates) ─────────────────────────

  Future<void> refreshUser() async {
    try {
      final appUser = await ref.read(getCurrentUserUseCaseProvider)();
      if (appUser != null && state is AuthAuthenticated) {
        final currentState = state as AuthAuthenticated;
        _safeSetState(
          AuthAuthenticated(user: appUser, access: currentState.access),
        );
      }
    } catch (e, st) {
      // Called from the profile screen after an update, not user input —
      // an unexpected failure here is worth investigating.
      GlobalErrorHandler.logError(e, st);
      debugPrint('[Auth] Refresh user error: ${e.runtimeType}');
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
      secureStorage: hardenedSecureStorage,
      cancellationManager: ref.read(requestCancellationManagerProvider),
      fcmConfigured: AppConfig.fcmEnabled,
    );
    await flushAndCloseUserProgressSession(ref);
    await orchestrator.forceLocalCleanup();
    _invalidateAllUserProviders();

    // Defense-in-depth companion to the logout() call site: this helper
    // is also reachable directly (device rejected, non-student blocked)
    // without going through logout(), so clear unconditionally here too
    // — a no-op if setUserContext was never called for this session.
    SentryService.clearUserContext();
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

    // Invalidate every in-flight auth operation before starting cleanup so
    // a late login/session-restore result can never sign out or overwrite a
    // newer session.
    final generation = _beginAuthOperation();

    final client = ref.read(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;

    // ── Phase 1: Set Logging Out state ──────────────────────────────────────
    _safeSetState(const AuthLoggingOut());

    // Clear the Sentry user context immediately: from this point the
    // session is being torn down, so subsequent crash events (including
    // ones raised by this very logout's cleanup phases) must not keep
    // being attributed to the outgoing user.
    SentryService.clearUserContext();

    // Stop security monitoring immediately
    _accessService?.stop();
    _accessService = null;

    // Stop any pending degraded-session auto-retry — logging out is an
    // explicit action that must win over a stale retry attempt.
    _degradedRetryTimer?.cancel();

    final orchestrator = LogoutOrchestrator(
      supabase: client,
      secureStorage: hardenedSecureStorage,
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
      debugPrint(
        '[Logout] Server cleanup error (non-critical): ${e.runtimeType}',
      );
    }

    // A new login/passive revocation may have superseded this logout while
    // server cleanup was in flight. Do not clear the newer session locally.
    if (!_isCurrentAuthOperation(generation)) return;

    // Flush any pending lesson-progress writes while the about-to-be-cleared
    // session's token is still valid, then close the shared queue so it
    // stops accepting new items and discards anything left over instead of
    // silently retrying it under whatever account signs in next on this
    // device (see LessonProgressSyncEngine.closeSession doc comment, and
    // video_player_remote_ds.dart's syncProgressBatch, which reads the
    // *ambient* Supabase currentUser.id at flush time -- not at enqueue
    // time -- so a stale retry after a new login would otherwise be
    // attributed to the new account, corrupting their progress data).
    await flushAndCloseUserProgressSession(ref);

    // ── Phase 3: Clear local session securely ───────────────────────────────
    await orchestrator.forceLocalCleanup();

    if (!_isCurrentAuthOperation(generation)) return;

    // ── Phase 4: Invalidate user data Providers ─────────────────────────────
    // Now that the session is wiped, clear memory safely.
    _invalidateAllUserProviders();

    // ── Phase 5: Finalize State ─────────────────────────────────────────────
    // This triggers GoRouter to immediately snap to /login natively.
    if (_isCurrentAuthOperation(generation)) {
      _safeSetState(const AuthUnauthenticated());
    }
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
