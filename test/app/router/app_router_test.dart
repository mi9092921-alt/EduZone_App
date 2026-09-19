import 'package:app/app/router/app_router.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/security/security_service.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for the COMPLETE router redirect decision
/// ([evaluateAppRedirect]) — a pure function, so every rule (security kill
/// switch, session-state matrix, deep-link stash/restore) is covered
/// headlessly without a widget tree or any feature provider.
///
/// Regression coverage for the security-kill-switch audit finding: an
/// engaged kill switch must pin the router to /locked even while
/// AppAuthState is `authenticated` — previously the authenticated-state
/// restricted-routes guard bounced /locked straight back to /home,
/// silently defeating the RASP kill switch.
void main() {
  /// In-memory pending-link store; records mutations so tests can assert
  /// stash/consume/clear side effects.
  final linkStore = _FakePendingLinkStore();

  String? redirect({
    required AppAuthState appState,
    required String location,
    bool killSwitch = false,
    String? uri,
  }) {
    return evaluateAppRedirect(
      appState: appState,
      location: location,
      killSwitchEngaged: killSwitch,
      uri: uri ?? location,
      linkStore: linkStore,
    );
  }

  tearDown(() {
    SecurityService.resetKillSwitchForTest();
    linkStore.reset();
  });

  group('security kill switch (highest redirect priority)', () {
    test('kill-handler navigation to /locked sticks for an authenticated user',
        () {
      // Mirrors wireSecurityKillHandler: latch first, then go('/locked').
      SecurityService.engageKillSwitch();

      expect(
        redirect(
          appState: AppAuthState.authenticated,
          location: AppRoutes.locked,
          killSwitch: true,
        ),
        isNull,
        reason: 'the kill-switch screen must STICK for an authenticated user '
            '— the old redirect bounced it straight back to /home, silently '
            'defeating the RASP kill switch',
      );
    });

    test('an engaged kill switch bounces every other location to /locked',
        () {
      expect(
        redirect(
          appState: AppAuthState.authenticated,
          location: AppRoutes.home,
          killSwitch: true,
        ),
        AppRoutes.locked,
      );
      expect(
        redirect(
          appState: AppAuthState.unauthenticated,
          location: AppRoutes.todo,
          killSwitch: true,
        ),
        AppRoutes.locked,
        reason: 'the latch outlives auth-state changes: a user on a '
            'compromised device cannot browse even after logging out',
      );
    });

    test('without the latch, manual /locked navigation still bounces to /home '
        'while authenticated (guard screens are not manually reachable)', () {
      expect(
        redirect(
          appState: AppAuthState.authenticated,
          location: AppRoutes.locked,
        ),
        AppRoutes.home,
      );
    });
  });

  group('session-state routing basics', () {
    test('initializing forces splash', () {
      expect(
        redirect(
          appState: AppAuthState.initializing,
          location: AppRoutes.home,
        ),
        AppRoutes.splash,
      );
      expect(
        redirect(
          appState: AppAuthState.initializing,
          location: AppRoutes.splash,
        ),
        isNull,
      );
    });

    test('authenticating stays on /login and /splash', () {
      expect(
        redirect(
          appState: AppAuthState.authenticating,
          location: AppRoutes.login,
        ),
        isNull,
      );
      expect(
        redirect(
          appState: AppAuthState.authenticating,
          location: AppRoutes.splash,
        ),
        isNull,
      );
      expect(
        redirect(
          appState: AppAuthState.authenticating,
          location: AppRoutes.home,
        ),
        AppRoutes.splash,
      );
    });

    test('sessionVerificationPending holds splash (no network-blip logout)',
        () {
      expect(
        redirect(
          appState: AppAuthState.sessionVerificationPending,
          location: AppRoutes.courses,
        ),
        AppRoutes.splash,
        reason: 'degraded sessions must never be treated as unauthenticated',
      );
    });

    test('forceUpdate blocks everything', () {
      expect(
        redirect(appState: AppAuthState.forceUpdate, location: AppRoutes.home),
        AppRoutes.forceUpdate,
      );
      expect(
        redirect(
          appState: AppAuthState.forceUpdate,
          location: AppRoutes.forceUpdate,
        ),
        isNull,
      );
    });

    test('unauthenticated keeps public routes and bounces the rest to /login',
        () {
      expect(
        redirect(
          appState: AppAuthState.unauthenticated,
          location: AppRoutes.login,
        ),
        isNull,
      );
      expect(
        redirect(
          appState: AppAuthState.unauthenticated,
          location: '${AppRoutes.legal}/terms',
        ),
        isNull,
      );
      expect(
        redirect(
          appState: AppAuthState.unauthenticated,
          location: AppRoutes.profile,
        ),
        AppRoutes.login,
      );
    });

    test('loggingOut sends everything to /login', () {
      expect(
        redirect(appState: AppAuthState.loggingOut, location: AppRoutes.home),
        AppRoutes.login,
      );
      expect(
        redirect(appState: AppAuthState.loggingOut, location: AppRoutes.login),
        isNull,
      );
    });

    test('authenticated bounces login/splash/force-update/restricted to /home',
        () {
      for (final blocked in [
        AppRoutes.login,
        AppRoutes.splash,
        AppRoutes.forceUpdate,
        AppRoutes.locked,
        AppRoutes.appLocked,
        AppRoutes.suspended,
        AppRoutes.banned,
        AppRoutes.maintenance,
      ]) {
        expect(
          redirect(appState: AppAuthState.authenticated, location: blocked),
          AppRoutes.home,
          reason: 'authenticated + $blocked must land on /home',
        );
      }
    });

    test('each restricted state pins to its dedicated screen', () {
      expect(
        redirect(appState: AppAuthState.banned, location: AppRoutes.home),
        AppRoutes.banned,
      );
      expect(
        redirect(appState: AppAuthState.suspended, location: AppRoutes.home),
        AppRoutes.suspended,
      );
      expect(
        redirect(appState: AppAuthState.locked, location: AppRoutes.home),
        AppRoutes.locked,
      );
      expect(
        redirect(appState: AppAuthState.appLocked, location: AppRoutes.home),
        AppRoutes.appLocked,
      );
      expect(
        redirect(appState: AppAuthState.maintenance, location: AppRoutes.home),
        AppRoutes.maintenance,
      );
    });
  });

  group('deep-link restore (pendingDeepLinkProvider semantics)', () {
    test('unauthenticated + protected deep link stashes the destination and '
        'goes to /login', () {
      final result = redirect(
        appState: AppAuthState.unauthenticated,
        location: '${AppRoutes.courses}/42',
      );

      expect(result, AppRoutes.login);
      expect(linkStore.pending, '${AppRoutes.courses}/42');
    });

    test('unauthenticated + /login does not re-stash (stays put)', () {
      // Pre-existing stash must survive a no-op /login visit.
      linkStore.pending = '${AppRoutes.courses}/42';

      final result = redirect(
        appState: AppAuthState.unauthenticated,
        location: AppRoutes.login,
      );

      expect(result, isNull);
      expect(linkStore.pending, '${AppRoutes.courses}/42',
          reason: 'the stash must not be clobbered while the user sits on '
              'the login screen');
    });

    test('authenticated + /login consumes the stash and lands on the '
        'deep link instead of /home', () {
      linkStore.pending = '${AppRoutes.courses}/42';

      final result = redirect(
        appState: AppAuthState.authenticated,
        location: AppRoutes.login,
      );

      expect(result, '${AppRoutes.courses}/42');
      expect(linkStore.pending, isNull, reason: 'the stash must be consumed');
    });

    test('authenticated + /login falls back to /home when nothing is stashed',
        () {
      final result = redirect(
        appState: AppAuthState.authenticated,
        location: AppRoutes.login,
      );

      expect(result, AppRoutes.home);
    });

    test('initializing + deep link stashes and forces splash; the stash is '
        'honoured once authenticated', () {
      var result = redirect(
        appState: AppAuthState.initializing,
        location: AppRoutes.todo,
      );

      expect(result, AppRoutes.splash);
      expect(linkStore.pending, AppRoutes.todo);

      result = redirect(
        appState: AppAuthState.authenticated,
        location: AppRoutes.splash,
      );

      expect(result, AppRoutes.todo);
      expect(linkStore.pending, isNull);
    });

    test('logging out clears the pending destination', () {
      linkStore.pending = '${AppRoutes.courses}/42';

      redirect(appState: AppAuthState.loggingOut, location: AppRoutes.home);

      expect(linkStore.pending, isNull,
          reason: 'a destination requested under the outgoing session must '
              'not resurface for the next one');
    });

    test('non-honourable destinations are never stashed', () {
      // Legal is public: no stash.
      redirect(
        appState: AppAuthState.unauthenticated,
        location: '${AppRoutes.legal}/terms',
      );
      expect(linkStore.pending, isNull);

      // Scheme-relative foreign URL: bounced to /login, still no stash.
      final result = redirect(
        appState: AppAuthState.unauthenticated,
        location: '//evil.com',
        uri: '//evil.com',
      );
      expect(result, AppRoutes.login);
      expect(linkStore.pending, isNull);

      // Guard screens / force-update are never valid deep-link targets.
      redirect(
        appState: AppAuthState.unauthenticated,
        location: AppRoutes.maintenance,
      );
      expect(linkStore.pending, isNull);
    });

    test('authenticating + a mid-flight deep link is stashed too (FCM tap '
        'while a login request is in flight)', () {
      final result = redirect(
        appState: AppAuthState.authenticating,
        location: '${AppRoutes.courses}/7/lesson/9',
      );

      expect(result, AppRoutes.splash);
      expect(linkStore.pending, '${AppRoutes.courses}/7/lesson/9');
    });
  });
}

class _FakePendingLinkStore implements PendingLinkStore {
  String? pending;

  void reset() {
    pending = null;
  }

  @override
  String? consume() {
    final value = pending;
    pending = null;
    return value;
  }

  @override
  void stash(String location) => pending = location;

  @override
  void clear() => pending = null;
}
