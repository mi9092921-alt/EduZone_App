import 'dart:async';

import 'package:app/app/app_providers.dart';
import 'package:app/app/main_app.dart';
import 'package:app/app/router/app_router.dart';
import 'package:app/app/router/main_shell.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/core/l10n/arb/app_localizations_ar.dart';
import 'package:app/core/l10n/arb/app_localizations_en.dart';
import 'package:app/core/logging/infrastructure/event_dispatcher.dart' as logging;
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/domain/entities/app_user.dart';
import 'package:app/features/auth/domain/entities/auth_state.dart';
import 'package:app/features/auth/domain/entities/update_info.dart';
import 'package:app/features/auth/domain/entities/user_access.dart';
import 'package:app/features/auth/domain/enums/account_status.dart';
import 'package:app/features/auth/domain/enums/user_role.dart';
import 'package:app/features/auth/presentation/screens/banned_screen.dart';
import 'package:app/features/auth/presentation/screens/force_update_screen.dart';
import 'package:app/features/auth/presentation/screens/locked_screen.dart';
import 'package:app/features/auth/presentation/screens/login_screen.dart';
import 'package:app/features/auth/presentation/screens/maintenance_screen.dart';
import 'package:app/features/auth/presentation/screens/suspended_screen.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/presentation/screens/course_details_screen.dart';
import 'package:app/features/courses/presentation/screens/my_courses_screen.dart';
import 'package:app/features/home/application/providers/home_provider.dart';
import 'package:app/features/home/presentation/screens/home_screen.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/notifications/domain/entities/app_notification.dart';
import 'package:app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:app/features/profile/application/providers/profile_provider.dart';
import 'package:app/features/profile/domain/entities/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

const _user = AppUser(
  id: 'integration-user',
  email: 'integration@example.com',
  firstName: 'Integration',
  lastName: 'User',
  tenantId: 'tenant-1',
);

const _activeAccess = UserAccess(
  status: AccountStatus.active,
  role: UserRole.student,
);

final _profile = StudentProfile(
  id: _user.id,
  email: _user.email,
  firstName: _user.firstName,
  lastName: _user.lastName,
  tenantId: _user.tenantId,
);

const _course = Course(
  id: 'course-1',
  tenantId: 'tenant-1',
  title: 'Flutter Mastery',
  status: 'published',
);

final _enrollment = CourseEnrollment(
  id: 'enrollment-1',
  userId: _user.id,
  courseId: _course.id,
  tenantId: 'tenant-1',
  course: _course,
);

AppNotification _notification({required bool isRead}) => AppNotification(
      id: 'notification-1',
      userId: _user.id,
      tenantId: 'tenant-1',
      isRead: isRead,
      createdAt: DateTime(2024),
      details: const NotificationDetails(
        title: 'New lesson available',
        body: 'A new lesson was just published.',
      ),
    );

/// Records calls made through [NotificationsRepository] so the "mark all
/// read" integration test can assert the real user id flowed all the way
/// from the authenticated [AuthState] through the tapped button to the
/// repository, without a live Supabase client (see notifications_screen.dart
/// — Section 6/8: no direct backend-singleton reads from widget code).
class _RecordingNotificationsRepository implements NotificationsRepository {
  String? lastMarkedAllAsReadUserId;

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications(
    String userId,
  ) async =>
      Right([_notification(isRead: false)]);

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> markAllAsRead(String userId) async {
    lastMarkedAllAsReadUserId = userId;
    return const Right(null);
  }
}

class _ScenarioAuth extends Auth {
  _ScenarioAuth(this._initialState);

  final AuthState _initialState;
  Completer<void>? loginCompletion;
  Completer<void>? logoutCompletion;
  AuthState? loginResult;
  AuthState? logoutResult;
  AuthState? retryResult;

  @override
  AuthState build() => _initialState;

  void transitionTo(AuthState nextState) {
    state = nextState;
  }

  @override
  Future<void> login(String email, String password) async {
    state = const AuthAuthenticating();
    final completion = loginCompletion;
    if (completion != null) {
      await completion.future;
    }
    if (!ref.mounted) return;
    state = loginResult ?? const AuthUnauthenticated(error: 'errorAuth');
  }

  @override
  Future<void> logout({String flow = 'manual'}) async {
    state = const AuthLoggingOut();
    final completion = logoutCompletion;
    if (completion != null) {
      await completion.future;
    }
    if (!ref.mounted) return;
    state = logoutResult ?? const AuthUnauthenticated();
  }

  @override
  Future<void> retryDegradedSession() async {
    if (!ref.mounted || state is! AuthDegraded) return;
    state = retryResult ?? state;
  }
}

ProviderContainer _containerFor(
  AuthState state, {
  _ScenarioAuth? auth,
  Locale locale = const Locale('en'),
  List<Override> extraOverrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      authProvider.overrideWith(
        () => auth ?? _ScenarioAuth(state),
      ),
      appLocaleProvider.overrideWithValue(locale),
      appThemeModeProvider.overrideWithValue(ThemeMode.light),
      resumeLessonProvider.overrideWith((ref) async => null),
      recentCoursesProvider.overrideWith((ref) async => const []),
      recentTodosProvider.overrideWith((ref) async => const []),
      profileProvider.overrideWith((ref) async => _profile),
      notificationsProvider.overrideWith((ref) async => const []),
      eventDispatcherProvider.overrideWithValue(
        logging.EventDispatcher(const []),
      ),
      ...extraOverrides,
    ],
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const EduZoneApp(),
    ),
  );
  await tester.pump();
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxPumps = 40,
}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(step);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo.setMockInitialValues(
    appName: 'EduZone',
    packageName: 'com.eduzone.app',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );

  group('EduZone application integration', () {
    testWidgets(
        'startup resolves from splash to login for a cold unauthenticated state',
        (tester) async {
      final container = _containerFor(const AuthInitializing());
      addTearDown(container.dispose);
      final auth = container.read(authProvider.notifier) as _ScenarioAuth;

      await _pumpApp(tester, container);
      expect(find.byType(EduZoneApp), findsOneWidget);

      auth.transitionTo(const AuthUnauthenticated());
      await _pumpUntil(tester, find.byType(LoginScreen));

      expect(find.byType(LoginScreen), findsOneWidget);
      final l10n = AppLocalizationsEn();
      expect(find.text(l10n.loginTitle), findsOneWidget);
    });

    testWidgets(
        'login form validates input, exposes authenticating state, then routes to home',
        (tester) async {
      final auth = _ScenarioAuth(const AuthUnauthenticated());
      auth.loginCompletion = Completer<void>();
      auth.loginResult = const AuthAuthenticated(
        user: _user,
        access: _activeAccess,
      );
      final container = _containerFor(
        const AuthUnauthenticated(),
        auth: auth,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(LoginScreen));

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(2));

      final l10n = AppLocalizationsEn();
      await tester.tap(find.text(l10n.loginButton));
      await tester.pump();
      expect(find.text(l10n.agreeToTermsError), findsOneWidget);

      await tester.tap(find.byType(Checkbox));
      await tester.enterText(fields.at(0), 'invalid-email');
      await tester.enterText(fields.at(1), 'short');
      await tester.tap(find.text(l10n.loginButton));
      await tester.pump();
      expect(find.text(l10n.errorInvalidEmail), findsOneWidget);
      expect(find.text(l10n.errorPasswordTooShort), findsOneWidget);

      await tester.enterText(fields.at(0), _user.email);
      await tester.enterText(fields.at(1), 'valid-password');
      await tester.tap(find.text(l10n.loginButton));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(container.read(authProvider), isA<AuthAuthenticating>());

      auth.loginCompletion!.complete();
      await _pumpUntil(tester, find.byType(MainShell));

      expect(find.byType(MainShell), findsOneWidget);
    });

    testWidgets(
        'authenticated session restoration bypasses login and enters home shell',
        (tester) async {
      final container = _containerFor(
        const AuthAuthenticated(user: _user, access: _activeAccess),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(MainShell));

      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
        'logout state drives the router to login and blocks protected navigation',
        (tester) async {
      final auth = _ScenarioAuth(
        const AuthAuthenticated(user: _user, access: _activeAccess),
      );
      auth.logoutCompletion = Completer<void>();
      auth.logoutResult = const AuthUnauthenticated();
      final container = _containerFor(
        const AuthAuthenticated(user: _user, access: _activeAccess),
        auth: auth,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      final GoRouter router = container.read(routerProvider);
      await _pumpUntil(tester, find.byType(MainShell));

      final logoutFuture = auth.logout();
      await tester.pump();
      expect(container.read(authProvider), isA<AuthLoggingOut>());
      final RouteInformationProvider routeInfo = router.routeInformationProvider;
      expect(routeInfo.value.uri.path, AppRoutes.login);

      auth.logoutCompletion!.complete();
      await logoutFuture;
      await _pumpUntil(tester, find.byType(LoginScreen));

      router.go(AppRoutes.profile);
      await tester.pumpAndSettle();
      expect(routeInfo.value.uri.path, AppRoutes.login);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets(
        'navigation guard redirects restricted account states to dedicated screens',
        (tester) async {
      final cases = <AuthState, Type>{
        const AuthRestricted(
          status: AccountStatus.banned,
          access: UserAccess(status: AccountStatus.banned),
        ): BannedScreen,
        const AuthRestricted(
          status: AccountStatus.suspended,
          access: UserAccess(status: AccountStatus.suspended),
        ): SuspendedScreen,
        const AuthRestricted(
          status: AccountStatus.locked,
          access: UserAccess(status: AccountStatus.locked),
        ): LockedScreen,
        const AuthRestricted(
          status: AccountStatus.maintenance,
          access: UserAccess(status: AccountStatus.maintenance),
        ): MaintenanceScreen,
        const AuthForceUpdate(
          UpdateInfo(
            status: UpdateStatus.forceUpdate,
            message: 'Update required',
            storeUrl: '',
            latestVersion: '9.9.9',
          ),
        ): ForceUpdateScreen,
      };

      for (final entry in cases.entries) {
        final container = _containerFor(entry.key);
        addTearDown(container.dispose);

        await _pumpApp(tester, container);
        await _pumpUntil(tester, find.byType(entry.value));

        expect(find.byType(entry.value), findsOneWidget);
        expect(container.read(authProvider), entry.key);
      }
    });

    testWidgets(
        'degraded session stays on splash until an explicit retry restores access',
        (tester) async {
      final auth = _ScenarioAuth(
        const AuthDegraded(error: 'errorNetwork', retryAttempt: 1),
      );
      auth.retryResult = const AuthAuthenticated(
        user: _user,
        access: _activeAccess,
      );
      final container = _containerFor(
        const AuthDegraded(error: 'errorNetwork', retryAttempt: 1),
        auth: auth,
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await tester.pump();

      final GoRouter router = container.read(routerProvider);
      final RouteInformationProvider routeInfo = router.routeInformationProvider;
      expect(routeInfo.value.uri.path, AppRoutes.splash);
      expect(find.byType(LoginScreen), findsNothing);

      await auth.retryDegradedSession();
      await _pumpUntil(tester, find.byType(MainShell));

      expect(container.read(authProvider), isA<AuthAuthenticated>());
      expect(find.byType(MainShell), findsOneWidget);
    });

    testWidgets(
        'switching locale to Arabic renders an RTL layout with localized strings',
        (tester) async {
      final container = _containerFor(
        const AuthUnauthenticated(),
        locale: const Locale('ar'),
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(LoginScreen));

      expect(find.byType(LoginScreen), findsOneWidget);

      final loginScreenContext = tester.element(find.byType(LoginScreen));
      expect(Directionality.of(loginScreenContext), TextDirection.rtl);

      final arL10n = AppLocalizationsAr();
      expect(find.text(arL10n.loginTitle), findsOneWidget);
    });

    testWidgets(
        'login screen meets minimum tap-target and text-contrast accessibility guidelines',
        (tester) async {
      // Enables the semantics tree so the accessibility guideline matchers
      // below can inspect real Semantics nodes instead of a stripped tree.
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);

      final container = _containerFor(const AuthUnauthenticated());
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(LoginScreen));

      // These are real, evidence-based accessibility checks (Section 16/17):
      // they inspect the actual rendered Semantics/RenderObject tree rather
      // than merely asserting that a tooltip string exists somewhere.
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    });

    testWidgets(
        'authenticated user loads My Courses and opens a course into '
        'CourseDetailsScreen', (tester) async {
      final container = _containerFor(
        const AuthAuthenticated(user: _user, access: _activeAccess),
        extraOverrides: [
          myCoursesProvider.overrideWith((ref) async => [_enrollment]),
          courseDetailsProvider(_course.id).overrideWith(
            (ref) async => _course,
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(MainShell));

      final router = container.read(routerProvider);
      router.go(AppRoutes.courses);
      await tester.pumpAndSettle();

      expect(find.byType(MyCoursesScreen), findsOneWidget);
      expect(find.text(_course.title), findsOneWidget);

      await tester.tap(find.text(_course.title));
      await tester.pumpAndSettle();

      final routeInfo = router.routeInformationProvider;
      expect(routeInfo.value.uri.path, '${AppRoutes.courses}/${_course.id}');
      expect(find.byType(CourseDetailsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'authenticated user opens Notifications and "Mark all read" reaches '
        "the repository with the authenticated user's id", (tester) async {
      final repository = _RecordingNotificationsRepository();
      // Built directly (not via `_containerFor`) so the real
      // `notificationsProvider` override below — needed because the fixture
      // notification list must actually render — is the *only* override
      // for that provider, rather than layering a second override on top
      // of `_containerFor`'s empty-list default for it.
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _ScenarioAuth(
              const AuthAuthenticated(user: _user, access: _activeAccess),
            ),
          ),
          appLocaleProvider.overrideWithValue(const Locale('en')),
          appThemeModeProvider.overrideWithValue(ThemeMode.light),
          resumeLessonProvider.overrideWith((ref) async => null),
          recentCoursesProvider.overrideWith((ref) async => const []),
          recentTodosProvider.overrideWith((ref) async => const []),
          profileProvider.overrideWith((ref) async => _profile),
          eventDispatcherProvider.overrideWithValue(
            logging.EventDispatcher(const []),
          ),
          notificationsProvider.overrideWith(
            (ref) async => [_notification(isRead: false)],
          ),
          notificationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(MainShell));

      final router = container.read(routerProvider);
      unawaited(router.push('${AppRoutes.home}/notifications'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('New lesson available'), findsOneWidget);

      final l10n = AppLocalizationsEn();
      await tester.tap(find.text(l10n.markAllRead));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.lastMarkedAllAsReadUserId, _user.id);
    });
  });
}
