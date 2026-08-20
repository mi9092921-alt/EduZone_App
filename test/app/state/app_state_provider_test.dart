import 'package:app/app/state/app_state_provider.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/update_info.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Fixtures ────────────────────────────────────────────────────────────────

const _tUser = AppUser(
  id: 'user-1',
  email: 'test@example.com',
  firstName: 'Test',
  tenantId: 'tenant-1',
);
const _tActiveAccess = UserAccess(status: AccountStatus.active);

/// Reads [appStateProvider] after overriding [authProvider] with [value].
///
/// This is the exact mapping the Router (`app_router.dart`) switches on
/// to decide redirects — every branch here corresponds 1:1 to a `case`
/// in that switch, so a mismatch here is a routing bug in production.
AppAuthState _appStateFor(AuthState value) {
  final container = ProviderContainer(
    overrides: [authProvider.overrideWithValue(value)],
  );
  addTearDown(container.dispose);
  return container.read(appStateProvider);
}

void main() {
  group('appStateProvider — AuthState → AppAuthState mapping', () {
    test('AuthInitializing → initializing', () {
      expect(_appStateFor(const AuthInitializing()), AppAuthState.initializing);
    });

    // Regression test: AuthAuthenticating previously mapped to
    // AppAuthState.initializing, which made the Router force-navigate
    // from /login to /splash the instant the login button was pressed —
    // before LoginScreen's own loading overlay (keyed on this same
    // AuthAuthenticating state) had a chance to render. It must resolve
    // to a distinct state so the Router's redirect can special-case it
    // and stay on /login instead.
    test(
        'AuthAuthenticating → authenticating (NOT initializing, so the '
        'Router does not yank the user off /login)', () {
      final result = _appStateFor(const AuthAuthenticating());
      expect(result, AppAuthState.authenticating);
      expect(
        result,
        isNot(AppAuthState.initializing),
        reason: 'a login-in-flight state must never be routed the same '
            'way as cold-start session verification, or the Router '
            'force-navigates away from /login mid-tap',
      );
    });

    test('AuthAuthenticated → authenticated', () {
      expect(
        _appStateFor(
          const AuthAuthenticated(user: _tUser, access: _tActiveAccess),
        ),
        AppAuthState.authenticated,
      );
    });

    test('AuthUnauthenticated → unauthenticated', () {
      expect(
        _appStateFor(const AuthUnauthenticated()),
        AppAuthState.unauthenticated,
      );
    });

    test('AuthLoggingOut → loggingOut', () {
      expect(_appStateFor(const AuthLoggingOut()), AppAuthState.loggingOut);
    });

    test('AuthForceUpdate → forceUpdate', () {
      expect(
        _appStateFor(
          const AuthForceUpdate(
            UpdateInfo(
              status: UpdateStatus.forceUpdate,
              message: 'Please update',
              storeUrl: 'https://example.com/store',
              latestVersion: '2.0.0',
            ),
          ),
        ),
        AppAuthState.forceUpdate,
      );
    });

    // ── The mapping this fix adds ──────────────────────────────────────────
    //
    // See EduZone_Authentication_Session_Security_Architecture.md, Phase
    // 18. Before AuthDegraded existed, a transient network error at cold
    // start produced AuthUnauthenticated, which maps to
    // AppAuthState.unauthenticated — and the Router (app_router.dart)
    // redirects that straight to /login, discarding a perfectly valid
    // local session over a network blip. This test pins the fix: a
    // degraded session must resolve to a distinct state that keeps the
    // Router on /splash instead.
    test(
        'AuthDegraded → sessionVerificationPending (NOT unauthenticated)',
        () {
      final result = _appStateFor(const AuthDegraded(error: 'errorNetwork'));
      expect(result, AppAuthState.sessionVerificationPending);
      expect(
        result,
        isNot(AppAuthState.unauthenticated),
        reason: 'a degraded (transiently-unverifiable) session must never '
            'be routed the same way as an explicit "no session" state',
      );
    });

    test('AuthRestricted(banned) → banned', () {
      expect(
        _appStateFor(
          const AuthRestricted(
            status: AccountStatus.banned,
            access: UserAccess(status: AccountStatus.banned),
          ),
        ),
        AppAuthState.banned,
      );
    });

    test('AuthRestricted(suspended) → suspended', () {
      expect(
        _appStateFor(
          const AuthRestricted(
            status: AccountStatus.suspended,
            access: UserAccess(status: AccountStatus.suspended),
          ),
        ),
        AppAuthState.suspended,
      );
    });

    test('AuthRestricted(locked) → locked', () {
      expect(
        _appStateFor(
          const AuthRestricted(
            status: AccountStatus.locked,
            access: UserAccess(status: AccountStatus.locked),
          ),
        ),
        AppAuthState.locked,
      );
    });

    test('AuthRestricted(maintenance) → maintenance', () {
      expect(
        _appStateFor(
          const AuthRestricted(
            status: AccountStatus.maintenance,
            access: UserAccess(status: AccountStatus.maintenance),
          ),
        ),
        AppAuthState.maintenance,
      );
    });

    test('AuthRestricted(appLocked) → appLocked', () {
      expect(
        _appStateFor(
          const AuthRestricted(
            status: AccountStatus.appLocked,
            access: UserAccess(status: AccountStatus.appLocked),
          ),
        ),
        AppAuthState.appLocked,
      );
    });
  });
}
