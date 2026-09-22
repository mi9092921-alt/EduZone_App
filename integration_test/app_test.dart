import 'dart:async';

import 'package:app/app/app_providers.dart';
import 'package:app/app/main_app.dart';
import 'package:app/app/router/app_router.dart';
import 'package:app/app/router/main_shell.dart';
import 'package:app/core/constants/app_constants.dart';
import 'package:app/core/error/failures.dart';
import 'package:app/core/feature_flags/data/feature_flag_remote_ds.dart';
import 'package:app/core/feature_flags/feature_flag_cache.dart';
import 'package:app/core/feature_flags/feature_flag_keys.dart';
import 'package:app/core/feature_flags/feature_flag_snapshot.dart';
import 'package:app/core/feature_flags/feature_flags_provider.dart';
import 'package:app/core/l10n/arb/app_localizations_ar.dart';
import 'package:app/core/l10n/arb/app_localizations_en.dart';
import 'package:app/core/logging/infrastructure/event_dispatcher.dart' as logging;
import 'package:app/core/logging/logging_providers.dart';
import 'package:app/core/navigation/pending_deep_link_store.dart';
import 'package:app/core/utils/device_info_helper.dart';
import 'package:app/design_system/design_system.dart';
import 'package:app/features/auth/application/providers/auth_provider.dart';
import 'package:app/features/auth/presentation/screens/banned_screen.dart';
import 'package:app/features/auth/presentation/screens/force_update_screen.dart';
import 'package:app/features/auth/presentation/screens/locked_screen.dart';
import 'package:app/features/auth/presentation/screens/login_screen.dart';
import 'package:app/features/auth/presentation/screens/maintenance_screen.dart';
import 'package:app/features/auth/presentation/screens/suspended_screen.dart';
import 'package:app/features/courses/application/providers/courses_provider.dart';
import 'package:app/features/courses/domain/entities/course_enrollment.dart';
import 'package:app/features/courses/domain/repositories/courses_repository.dart';
import 'package:app/features/courses/presentation/screens/course_details_screen.dart';
import 'package:app/features/courses/presentation/screens/my_courses_screen.dart';
import 'package:app/features/downloads/application/providers/downloads_provider.dart';
import 'package:app/features/downloads/application/services/lesson_downloads_gateway_impl.dart';
import 'package:app/features/downloads/domain/entities/download_progress.dart';
import 'package:app/features/downloads/domain/repositories/download_repository.dart';
import 'package:app/features/downloads/presentation/screens/downloads_screen.dart';
import 'package:app/features/downloads/presentation/screens/offline_player_screen.dart';
import 'package:app/features/downloads/presentation/widgets/offline_player_wrapper.dart';
import 'package:app/features/home/application/providers/home_provider.dart';
import 'package:app/features/home/domain/entities/resume_lesson.dart';
import 'package:app/features/home/presentation/screens/home_screen.dart';
import 'package:app/features/notifications/application/providers/notifications_provider.dart';
import 'package:app/features/notifications/application/services/home_notifications_gateway_impl.dart';
import 'package:app/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:app/features/profile/application/providers/profile_provider.dart';
import 'package:app/features/profile/domain/entities/student_profile.dart';
import 'package:app/features/profile/domain/repositories/profile_repository.dart';
import 'package:app/features/profile/presentation/screens/profile_screen.dart';
import 'package:app/features/profile/presentation/widgets/edit_profile_bottom_sheet.dart';
import 'package:app/features/profile/presentation/widgets/user_info_card.dart';
import 'package:app/features/todo/application/providers/todo_provider.dart';
import 'package:app/features/todo/domain/repositories/todo_repository.dart';
import 'package:app/features/todo/presentation/screens/todo_screen.dart';
import 'package:app/features/todo/presentation/widgets/add_todo_bottom_sheet.dart';
import 'package:app/features/todo/presentation/widgets/variants/todo_list_tile.dart';
import 'package:app/shared/components/todo/todo_checkbox.dart';
import 'package:app/shared/models/account_status.dart';
import 'package:app/shared/models/app_notification.dart';
import 'package:app/shared/models/app_user.dart';
import 'package:app/shared/models/auth_state.dart';
import 'package:app/shared/models/course.dart';
import 'package:app/shared/models/download_enums.dart';
import 'package:app/shared/models/downloaded_lesson.dart';
import 'package:app/shared/models/lesson.dart';
import 'package:app/shared/models/section.dart';
import 'package:app/shared/models/todo_item.dart';
import 'package:app/shared/models/update_info.dart';
import 'package:app/shared/models/user_access.dart';
import 'package:app/shared/models/user_role.dart';
import 'package:app/shared/providers/home_notifications_gateway.dart';
import 'package:app/shared/providers/lesson_downloads_gateway.dart';
import 'package:app/shared/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
  tenantId: _course.tenantId,
  course: _course,
);

/// Course fixture carrying a real section + preview lesson so the
/// feature-flag scenarios can drive the actual lesson-tap →
/// player-choice-sheet flow through the real SectionsAccordion widget.
const _courseWithLesson = Course(
  id: 'course-1',
  tenantId: 'tenant-1',
  title: 'Flutter Mastery',
  status: 'published',
  sections: [
    Section(
      id: 'section-1',
      courseId: 'course-1',
      tenantId: 'tenant-1',
      title: 'Getting Started',
      lessons: [
        // Preview lessons are tappable without enrollment, so the
        // scenario does not depend on the enrollment fixture.
        Lesson(
          id: 'lesson-1',
          sectionId: 'section-1',
          courseId: 'course-1',
          tenantId: 'tenant-1',
          title: 'Intro Lesson',
          isPreview: true,
        ),
      ],
    ),
  ],
);

/// Stand-in for [FeatureFlagRemoteDataSource] at the external backend
/// boundary: returns configurable evaluator verdicts without touching
/// Supabase.
class _FakeFeatureFlagRemoteDataSource
    implements FeatureFlagRemoteDataSource {
  List<FeatureFlagEvaluation> verdicts = const [];

  @override
  String? get currentUserId => _user.id;

  @override
  Future<List<FeatureFlagEvaluation>> evaluate(
    List<FeatureFlagKey> keys,
  ) async =>
      verdicts;
}

/// Stand-in for [CoursesRepository] at the external backend boundary. Only
/// [updateLessonProgress] is reachable from the lesson-tap flow under test
/// (the tap marks the lesson watched before opening the sheet); the failure
/// it returns is swallowed by the UI exactly like a network error would be.
class _FakeCoursesRepository implements CoursesRepository {
  @override
  Future<Either<Failure, void>> updateLessonProgress({
    required String courseId,
    required String lessonId,
    required bool completed,
    required double progressPct,
    int? watchTimeSec,
  }) async =>
      const Left(ServerFailure('offline in test'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

/// Completed download fixture rendered by the downloads manager and
/// resolved by the offline player route.
final _download = DownloadedLesson(
  id: 'download-1',
  lessonId: 'lesson-9',
  courseId: 'course-1',
  courseTitle: 'Flutter Mastery',
  title: 'Offline Lesson',
  localPath: '/tmp/downloads/local.mp4',
  encryptedPath: '/tmp/downloads/enc.bin',
  videoUrl: 'https://example.com/lesson-9.mp4',
  quality: VideoQuality.p720,
  fileSize: 13212057, // ~12.6 MB, matches the storage-indicator assertion
  status: DownloadStatus.completed,
  downloadedAt: DateTime(2024),
  expiresAt: DateTime(2030),
);

/// Records calls made through [NotificationsRepository] so the "mark all
/// read" integration test can assert the real user id flowed all the way
/// from the authenticated [AuthState] through the tapped button to the
/// repository, without a live Supabase client (see notifications_screen.dart
/// — Section 6/8: no direct backend-singleton reads from widget code).
class _RecordingNotificationsRepository implements NotificationsRepository {
  String? lastMarkedAllAsReadUserId;
  String? lastMarkAsReadId;

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications(
    String userId,
  ) async =>
      Right([_notification(isRead: false)]);

  @override
  Stream<void> watchChanges(String userId) => const Stream<void>.empty();

  @override
  Future<Either<Failure, void>> markAsRead(String notificationId) async {
    lastMarkAsReadId = notificationId;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> markAllAsRead(String userId) async {
    lastMarkedAllAsReadUserId = userId;
    return const Right(null);
  }
}

/// Stand-in for [DownloadRepository] at the external backend boundary.
///
/// The downloads feature never touches Supabase directly — everything goes
/// through this interface — so faking here keeps the whole notifier →
/// usecase → repository chain real. [downloads] is mutated by the scenario
/// and (re)served on every read so the notifier's change-stream listener
/// observes the mutation the same way the real [DownloadRepositoryImpl]'s
/// broadcast stream + database reload would.
class _FakeDownloadsRepository implements DownloadRepository {
  final List<DownloadedLesson> downloads = [];

  /// When set, [getDownloadById] awaits this gate forever. Used to hold the
  /// offline player screen on its loading skeleton without ever
  /// instantiating real playback (see the offline-player scenario for the
  /// exact boundary).
  Completer<DownloadedLesson?>? getDownloadByIdGate;

  final _changes = StreamController<void>.broadcast();

  /// Mirrors the real repository's change notification (insert/update/
  /// delete on the downloads table → [changeStream] event → notifier
  /// reload).
  void emitChange() => _changes.add(null);

  void dispose() => _changes.close();

  @override
  Future<Either<Failure, List<DownloadedLesson>>> getDownloads() async =>
      Right(List.of(downloads));

  @override
  Future<Either<Failure, DownloadedLesson?>> getDownloadByLessonId(
    String lessonId,
  ) async => Right(
        downloads.where((d) => d.lessonId == lessonId).firstOrNull,
      );

  @override
  Future<Either<Failure, DownloadedLesson?>> getDownloadById(
    String downloadId,
  ) async {
    final gate = getDownloadByIdGate;
    if (gate != null) {
      final download = await gate.future;
      return Right(download);
    }
    return Right(
      downloads.where((d) => d.id == downloadId).firstOrNull,
    );
  }

  @override
  Future<Either<Failure, List<DownloadedLesson>>> getDownloadsByCourse(
    String courseId,
  ) async => Right(downloads.where((d) => d.courseId == courseId).toList());

  @override
  Future<Either<Failure, List<DownloadedLesson>>> getDownloadsByStatus(
    DownloadStatus status,
  ) async => Right(downloads.where((d) => d.status == status).toList());

  @override
  Stream<DownloadProgress> watchProgress(String downloadId) =>
      const Stream<DownloadProgress>.empty();

  @override
  Future<Either<Failure, List<DownloadedLesson>>> getExpiredDownloads()
      async => const Right([]);

  @override
  Future<Either<Failure, int>> cleanupExpiredDownloads() async =>
      const Right(0);

  @override
  Future<Either<Failure, int>> getTotalStorageUsed() async => Right(
        downloads.fold(0, (total, download) => total + download.fileSize),
      );

  @override
  Future<Either<Failure, void>> updateLastAccessed(String downloadId) async =>
      const Right(null);

  @override
  Stream<void> get changeStream => _changes.stream;

  // Mutations below are unreachable from the scenarios under test (no
  // download is started/paused/cancelled/deleted there); they fail loudly
  // rather than silently pretending success.
  @override
  Future<Either<Failure, DownloadedLesson>> startDownload({
    required String lessonId,
    required String courseId,
    required String courseTitle,
    required String title,
    required String videoUrl,
    required VideoQuality quality,
  }) async => const Left(ServerFailure('startDownload not used in test'));

  @override
  Future<Either<Failure, void>> pauseDownload(String downloadId) async =>
      const Left(ServerFailure('pauseDownload not used in test'));

  @override
  Future<Either<Failure, void>> resumeDownload(String downloadId) async =>
      const Left(ServerFailure('resumeDownload not used in test'));

  @override
  Future<Either<Failure, void>> cancelDownload(String downloadId) async =>
      const Left(ServerFailure('cancelDownload not used in test'));

  @override
  Future<Either<Failure, void>> deleteDownload(String downloadId) async =>
      const Left(ServerFailure('deleteDownload not used in test'));
}

/// Stand-in for [TodoRepository] at the external backend boundary: the
/// real usecases (GetTodos/AddTodo/ToggleTodo/DeleteTodo/UpdateTodo) and
/// [TodoNotifier] run against this in-memory store.
class _FakeTodoRepository implements TodoRepository {
  final List<TodoItem> todos = [];

  /// Recorded toggle calls as (todoId, newIsCompleted).
  final List<(String, bool)> toggleCalls = [];
  String? lastDeletedId;
  List<TodoItem>? lastUpdatedWith;

  @override
  Future<Either<Failure, List<TodoItem>>> fetchTodos() async =>
      Right(List.of(todos));

  @override
  Future<Either<Failure, void>> toggleTodoStatus(
    String todoId,
    bool isCompleted,
  ) async {
    toggleCalls.add((todoId, isCompleted));
    final index = todos.indexWhere((t) => t.id == todoId);
    if (index != -1) {
      todos[index] = todos[index].copyWith(isCompleted: isCompleted);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> addTodo(TodoItem todo) async {
    todos.insert(0, todo);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteTodo(String todoId) async {
    lastDeletedId = todoId;
    todos.removeWhere((t) => t.id == todoId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateTodo(TodoItem todo) async {
    (lastUpdatedWith ??= []).add(todo);
    final index = todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) todos[index] = todo;
    return const Right(null);
  }
}

/// Stand-in for [ProfileRepository] at the external backend boundary. The
/// real [GetProfile]/[UpdateProfile] usecases and [ProfileActions] run
/// against this store; [updateProfile] applies only the non-null params,
/// exactly like the RPC-backed implementation contract.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);

  StudentProfile profile;
  int updateCalls = 0;

  @override
  Future<StudentProfile> getProfile() async => profile;

  @override
  Future<StudentProfile> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
    updateCalls++;
    profile = profile.copyWith(firstName: firstName, lastName: lastName);
    return profile;
  }

  @override
  Future<String> uploadAvatar(String filePath) async =>
      'https://example.com/avatar.png';
}

class _ScenarioAuth extends Auth {
  _ScenarioAuth(this._initialState);

  final AuthState _initialState;
  Completer<void>? loginCompletion;
  Completer<void>? logoutCompletion;
  AuthState? loginResult;
  AuthState? logoutResult;
  AuthState? retryResult;

  /// When set, [refreshUser] swaps the authenticated user for this one —
  /// mirroring the real `Auth.refreshUser()` contract (re-read the user and
  /// re-emit [AuthAuthenticated]) without touching the Supabase-backed
  /// getCurrentUser chain. Consumed by the profile edit-name scenario.
  AppUser? refreshUserResult;

  @override
  AuthState build() => _initialState;

  void transitionTo(AuthState nextState) {
    state = nextState;
  }

  @override
  Future<void> refreshUser() async {
    final updated = refreshUserResult;
    final current = state;
    if (updated != null && current is AuthAuthenticated) {
      state = AuthAuthenticated(user: updated, access: current.access);
    }
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
  bool useRealProfileProvider = false,
}) {
  return ProviderContainer(
    overrides: [
      authProvider.overrideWith(
        () => auth ?? _ScenarioAuth(state),
      ),
      appLocaleProvider.overrideWithValue(locale),
      appThemeModeProvider.overrideWithValue(ThemeMode.light),
      resumeLessonsProvider.overrideWith((ref) async => const <ResumeLesson>[]),
      recentCoursesProvider.overrideWith((ref) async => const []),
      recentTodosProvider.overrideWith((ref) async => const []),
      if (!useRealProfileProvider)
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
  // The router's pending deep-link store is process-wide static (it must
  // be, for the redirect to mutate it during the build phase) — reset it
  // per scenario so a destination stashed by an earlier scenario can never
  // hijack this scenario's initial redirect.
  PendingDeepLinkStore.resetForTest();
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
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump(step);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // FLAG_KEEP_SCREEN_ON via the app itself: when the device display turns
  // off mid-run, no frames are produced and every tester.pump() blocks
  // until the whole suite times out ("did not complete"). The wakelock is
  // released automatically when the app process ends.
  unawaited(WakelockPlus.enable());
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
      // Disposed explicitly in the body (not via addTearDown): the tester's
      // end-of-test verification runs BEFORE tearDowns, so a handle still
      // registered at that point fails the test with
      // "A SemanticsHandle was active at the end of the test".

      final container = _containerFor(const AuthUnauthenticated());
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(LoginScreen));

      // These are real, evidence-based accessibility checks (Section 16/17):
      // they inspect the actual rendered Semantics/RenderObject tree rather
      // than merely asserting that a tooltip string exists somewhere.
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    // KNOWN DEVICE-LAB FLAKE (diagnosed 2026-09-22, Phase 13): on a real
    // Android device with accessibility services enabled
    // (`settings get secure accessibility_enabled` == 1), the OS can announce
    // semantics mid-test. SemanticsBinding then holds a PLATFORM-owned
    // SemanticsHandle (`_handleSemanticsEnabledChanged`) that outlives this
    // test and trips flutter_test's end-of-test delta check ("A
    // SemanticsHandle was active at the end of the test") even though every
    // functional expectation below already passed. Neither the app nor this
    // file creates that handle (only the a11y scenario calls
    // tester.ensureSemantics, and it disposes its own handle). If this
    // scenario fails ONLY on that harness assertion, re-run it in isolation
    // (--plain-name) before treating it as a regression; do NOT "fix" it by
    // touching production code.
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
          resumeLessonsProvider.overrideWith((ref) async => const <ResumeLesson>[]),
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
          // Composition-root gateway wiring (mirrors main.dart): the home
          // dashboard preview must render the same unread notification the
          // full screen shows, through the shared contract implemented by
          // the real notifications-feature gateway on top of the
          // [_RecordingNotificationsRepository].
          homeNotificationsGatewayProvider.overrideWith(
            (ref) => HomeNotificationsGatewayImpl(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(MainShell));

      // The home dashboard preview (NotificationsPreview) is fed through
      // the shared gateway and renders the unread fixture notification
      // before any navigation happens. On a device viewport it can sit
      // below the fold (unbuilt sliver children are not in the tree), so
      // scroll the home list until it exists — bounded and silent if it
      // never appears; the expectation below is the real assertion.
      for (var i = 0;
          i < 10 &&
              find.text('New lesson available').evaluate().isEmpty;
          i++) {
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -250),
        );
        // pump (NOT pumpAndSettle): loading skeletons use infinite shimmer
        // animations, so pumpAndSettle would never settle here.
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('New lesson available'), findsOneWidget);

      final router = container.read(routerProvider);
      unawaited(router.push(AppRoutes.notifications));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      // The title renders twice: once in the home preview (the shell branch
      // stays alive behind the pushed screen — OFFSTAGE, so default finders
      // skip it) and once in the full NotificationsScreen.
      expect(
        find.text('New lesson available', skipOffstage: false),
        findsNWidgets(2),
      );

      final l10n = AppLocalizationsEn();
      await tester.tap(find.text(l10n.markAllRead));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.lastMarkedAllAsReadUserId, _user.id);
    });

    testWidgets(
        'downloads manager starts empty, renders a completed download '
        'broadcast by the repository change stream, and opens the offline '
        'player route up to its loading boundary', (tester) async {
      final repository = _FakeDownloadsRepository();
      final container = _containerFor(
        const AuthAuthenticated(user: _user, access: _activeAccess),
        extraOverrides: [
          downloadRepositoryProvider.overrideWithValue(repository),
          // Composition-root gateway wiring (mirrors main.dart): the
          // courses feature reads per-lesson download state through the
          // shared LessonDownloadsGateway contract implemented by the
          // real downloads-feature gateway on top of the faked repository.
          lessonDownloadsGatewayProvider.overrideWith(
            (ref) => LessonDownloadsGatewayImpl(ref),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(MainShell));

      final router = container.read(routerProvider);
      router.go(AppRoutes.downloads);
      await _pumpUntil(tester, find.byType(DownloadsScreen));

      final l10n = AppLocalizationsEn();

      // 1. Empty state before anything was downloaded.
      expect(find.text(l10n.downloadsEmpty), findsOneWidget);

      // 2. A completed download arrives through the repository's broadcast
      //    change stream — the same notification path the real
      //    DownloadRepositoryImpl uses for database insert/update events.
      //    DownloadsNotifier reloads through the REAL
      //    downloadsProvider/downloadRepository chain against the fake.
      //
      //    The getDownloadById gate is armed BEFORE navigation: it holds
      //    the offline player screen on its loading skeleton without ever
      //    instantiating real playback (see the boundary note below).
      repository.getDownloadByIdGate = Completer<DownloadedLesson?>();
      repository.downloads.add(_download);
      repository.emitChange();
      await _pumpUntil(tester, find.text(_download.title));

      expect(find.text(_download.title), findsOneWidget);
      expect(find.text(l10n.downloadStatusCompleted), findsOneWidget);
      // Storage indicator reflects the fixture's ~12.6 MB file size.
      expect(find.textContaining('Storage Used: 12.6 MB'), findsOneWidget);

      // 3. Tapping the completed tile pushes the offline player route
      //    (the real DownloadTile onTap → context.push flow).
      await tester.ensureVisible(find.text(_download.title));
      // pump, not pumpAndSettle — shimmer skeletons never settle.
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text(_download.title));
      await _pumpUntil(tester, find.byType(OfflinePlayerScreen));

      // NOTE: routeInformationProvider.value does NOT reflect routes added
      // via push() (the tile uses context.push) on the device binding —
      // read the delegate's matched configuration instead.
      expect(
        container
            .read(routerProvider)
            .routerDelegate
            .currentConfiguration
            .last
            .matchedLocation,
        '${AppRoutes.downloads}/offline-player/${_download.id}',
      );
      expect(find.byType(OfflinePlayerScreen), findsOneWidget);

      // FAKE BOUNDARY — offline playback stops here, deliberately. The
      // screen resolves the download through the REAL downloadByIdProvider
      // chain, but the fake repository's getDownloadById gate (armed above,
      // before navigation) never completes, so the screen stays on its
      // AppSkeleton loading state: the player widget itself is never
      // built. Instantiating it would read encryptionService/
      // downloadLocalDataSource/downloadRemoteDataSource (the latter
      // resolves supabaseClientProvider → SupabaseService.client, which
      // throws without a live Supabase.initialize), then run
      // OfflinePolicyEngine entitlement revalidation over the network and
      // drive media_kit's libmpv via platform channels — none of which can
      // initialize in the widget-test environment. Documented in
      // integration_test/README_TEST_GAPS.md.
      expect(
        find.descendant(
          of: find.byType(OfflinePlayerScreen),
          matching: find.byType(AppSkeleton),
        ),
        findsOneWidget,
      );
      expect(find.byType(OfflinePlayerWrapper), findsNothing);
      expect(find.text(l10n.offlineModeLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'authenticated user adds a todo from the real bottom sheet, toggles '
        'it complete, and deletes it through the ConfirmDialog flow',
        (tester) async {
      final todoRepository = _FakeTodoRepository();
      final container = _containerFor(
        const AuthAuthenticated(user: _user, access: _activeAccess),
        extraOverrides: [
          todoRepositoryProvider.overrideWithValue(todoRepository),
        ],
      );
      addTearDown(container.dispose);

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(MainShell));

      final router = container.read(routerProvider);
      router.go(AppRoutes.todo);
      await _pumpUntil(tester, find.byType(TodoScreen));

      final l10n = AppLocalizationsEn();

      // 1. Empty state.
      await _pumpUntil(tester, find.text(l10n.noTasks));
      expect(find.text(l10n.noTasks), findsOneWidget);

      // 2. Add through the real AddTodoBottomSheet: FAB → sheet → title →
      //    Add. The sheet sources userId/tenantId from the authenticated
      //    auth state machine, so the fake receives the real session ids.
      await tester.tap(find.byType(FloatingActionButton));
      await _pumpUntil(tester, find.byType(AddTodoBottomSheet));

      final sheetFields = find.descendant(
        of: find.byType(AddTodoBottomSheet),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(sheetFields.first, 'Buy groceries');
      await tester.tap(find.text(l10n.addBtn));
      // The success feedback appears once the mutation (and its queued
      // post-success work) settles; the optimistic list update always
      // precedes it, so waiting on the snackbar is race-free.
      await _pumpUntil(tester, find.text(l10n.taskAdded));

      expect(find.text('Buy groceries'), findsOneWidget);
      // Let the bottom-sheet exit animation finish before asserting it is
      // gone (the pop runs alongside the success feedback).
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AddTodoBottomSheet), findsNothing);
      final stored = todoRepository.todos.single;
      expect(stored.title, 'Buy groceries');
      expect(stored.userId, _user.id);
      expect(stored.tenantId, _user.tenantId);
      // Success feedback surfaced by FeedbackService through the app-level
      // scaffold messenger.
      expect(find.text(l10n.taskAdded), findsOneWidget);

      // 3. Toggle complete via the real TodoCheckbox → optimistic notifier
      //    update → ToggleTodo usecase → fake repository.
      final todoId = container.read(todoProvider).todos.single.id;
      final checkboxFinder = find.descendant(
        of: find.byType(TodoListTile),
        matching: find.byType(TodoCheckbox),
      );
      expect(tester.widget<TodoCheckbox>(checkboxFinder).value, isFalse);
      await tester.tap(checkboxFinder);
      // Two pumps so the optimistic notifier update lands in the tile.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.widget<TodoCheckbox>(checkboxFinder).value, isTrue);
      expect(todoRepository.toggleCalls.single, (todoId, true));

      // 4. Delete via the real Dismissible → ConfirmDialog flow. The
      //    tile's swipe background carries the same 'Delete' label as the
      //    dialog button, so taps are scoped to the dialog.
      final tileFinder = find.byKey(ValueKey('dismiss_$todoId'));
      await tester.fling(tileFinder, const Offset(-400, 0), 1200);
      await _pumpUntil(tester, find.text(l10n.confirmDeleteTitle));

      expect(find.text(l10n.confirmDeleteMsg), findsOneWidget);
      // Cancel keeps the todo.
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.text(l10n.cancel),
        ),
      );
      await tester.pump();
      expect(find.text('Buy groceries'), findsOneWidget);
      expect(todoRepository.lastDeletedId, isNull);

      // Swipe again and confirm for real.
      await tester.fling(tileFinder, const Offset(-400, 0), 1200);
      await _pumpUntil(tester, find.text(l10n.confirmDeleteTitle));
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.text(l10n.deleteButton),
        ),
      );
      // The delete's post-success refresh runs inside the mutation, so the
      // empty state appears first, then the deletion feedback.
      await _pumpUntil(tester, find.text(l10n.noTasks));
      await _pumpUntil(tester, find.text(l10n.taskDeleted));

      expect(find.text('Buy groceries'), findsNothing);
      expect(todoRepository.lastDeletedId, todoId);
      expect(find.text(l10n.taskDeleted), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'profile screen renders the fake profile and the edit-name flow '
        'updates the display, the session user, and shows success feedback',
        (tester) async {
      final repository = _FakeProfileRepository(
        StudentProfile(
          id: _user.id,
          email: _user.email,
          firstName: _user.firstName,
          lastName: _user.lastName,
          tenantId: _user.tenantId,
        ),
      );
      final auth = _ScenarioAuth(
        const AuthAuthenticated(user: _user, access: _activeAccess),
      );
      // The real ProfileActions.updateName refreshes the global auth user
      // after a successful backend write; the scenario auth mirrors that
      // contract with an updated session user instead of the Supabase
      // getCurrentUser chain.
      auth.refreshUserResult = AppUser(
        id: _user.id,
        email: _user.email,
        firstName: 'Nova',
        lastName: 'User',
        tenantId: _user.tenantId,
      );
      final container = _containerFor(
        const AuthAuthenticated(user: _user, access: _activeAccess),
        auth: auth,
        // The real profileProvider (→ GetProfile usecase → fake
        // repository) replaces the base container's static override.
        useRealProfileProvider: true,
        extraOverrides: [
          profileRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // DeviceInfoWidget on the profile screen asserts DeviceInfoHelper was
      // initialized (the real app inits it in AppInitializer before
      // runApp). On a real device the platform channels are live, so run
      // the real init here.
      await DeviceInfoHelper.init();

      await _pumpApp(tester, container);
      await _pumpUntil(tester, find.byType(MainShell));

      final router = container.read(routerProvider);
      router.go(AppRoutes.profile);
      await _pumpUntil(tester, find.byType(ProfileScreen));

      final l10n = AppLocalizationsEn();

      // 1. Name and email render from the fake profile through the real
      //    profileProvider → GetProfile → repository chain.
      await _pumpUntil(tester, find.text('Integration User'));
      expect(find.text('Integration User'), findsOneWidget);
      expect(find.text(_user.email), findsOneWidget);

      // 2. Open the real EditProfileBottomSheet from the user card's edit
      //    (camera) affordance.
      await tester.tap(
        find.descendant(
          of: find.byType(UserInfoCard),
          matching: find.byIcon(AppIcons.camera),
        ),
      );
      await _pumpUntil(tester, find.text(l10n.editProfile));

      // 3. Change the first name and submit through the real
      //    ProfileActions.updateName flow.
      final sheetFields = find.descendant(
        of: find.byType(EditProfileBottomSheet),
        matching: find.byType(TextFormField),
      );
      expect(sheetFields, findsNWidgets(2));
      expect(
        tester.widget<TextFormField>(sheetFields.first).controller!.text,
        'Integration',
      );
      await tester.enterText(sheetFields.first, 'Nova');
      await tester.tap(find.text(l10n.saveChanges));
      // Success feedback + sheet pop happen after the backend write, the
      // profile refetch, and the auth-user refresh have all settled.
      await _pumpUntil(tester, find.text(l10n.profileUpdated));
      await _pumpUntil(tester, find.text('Nova User'));

      expect(find.text('Nova User'), findsOneWidget);
      expect(find.text('Integration User'), findsNothing);
      expect(find.text(l10n.profileUpdated), findsOneWidget);
      // Let the bottom-sheet exit animation finish before asserting it is
      // gone.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(EditProfileBottomSheet), findsNothing);
      expect(repository.updateCalls, 1);
      expect(repository.profile.firstName, 'Nova');
      // The successful update propagated to the auth state machine.
      final authState = container.read(authProvider);
      expect(authState, isA<AuthAuthenticated>());
      expect(
        (authState as AuthAuthenticated).user.firstName,
        'Nova',
      );
      expect(tester.takeException(), isNull);
    });

    group('feature flags (core/feature_flags)', () {
      Future<ProviderContainer> pumpFlaggedApp(
        WidgetTester tester, {
        required _FakeFeatureFlagRemoteDataSource flagRepository,
        bool refreshAfterPump = true,
        bool disableCache = false,
      }) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final container = _containerFor(
          const AuthAuthenticated(user: _user, access: _activeAccess),
          extraOverrides: [
            featureFlagPrefsProvider.overrideWithValue(prefs),
            featureFlagRepositoryProvider.overrideWithValue(flagRepository),
            if (disableCache)
              featureFlagCacheProvider.overrideWithValue(
                FeatureFlagCache(prefs: null),
              ),
            myCoursesProvider.overrideWith((ref) async => [_enrollment]),
            courseDetailsProvider(_courseWithLesson.id).overrideWith(
              (ref) async => _courseWithLesson,
            ),
            myCourseEnrollmentProvider(_courseWithLesson.id).overrideWith(
              (ref) async => null,
            ),
            coursesRepositoryProvider.overrideWithValue(
              _FakeCoursesRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await _pumpApp(tester, container);
        await _pumpUntil(tester, find.byType(MainShell));

        // Mirror the real Auth notifier's post-authentication hook: the
        // scenario replaces Auth with _ScenarioAuth, so the refresh that
        // production fires on AuthAuthenticated must be triggered explicitly
        // here — otherwise the provider serves cache/defaults and the
        // repository's configured verdicts never reach the UI. Scenarios
        // that assert the PRE-refresh state pass refreshAfterPump: false.
        if (refreshAfterPump) {
          await container.read(featureFlagsProvider.notifier).refresh();
        }
        return container;
      }

      Future<void> openPlayerChoiceSheet(
        WidgetTester tester,
        GoRouter router,
      ) async {
        router.go('${AppRoutes.courses}/${_courseWithLesson.id}');
        await tester.pumpAndSettle();
        expect(find.byType(CourseDetailsScreen), findsOneWidget);

        // Expand the section to reveal the lesson tile, then tap it — the
        // real SectionsAccordion._handleLessonTap flow. Tapping the section
        // header TOGGLES the ExpansionTile, so a second open in the same
        // test (sheet dismissed, section already expanded) must not tap it
        // again or the lesson tile disappears.
        if (find.text('Intro Lesson').evaluate().isEmpty) {
          await tester.tap(find.text('Getting Started'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Intro Lesson'));
        await tester.pumpAndSettle();
      }

      Future<void> dismissSheet(WidgetTester tester) async {
        await tester.tapAt(const Offset(30, 30));
        await tester.pumpAndSettle();
      }

      testWidgets(
          'unregistered flag preserves production behavior in the real '
          'player-choice sheet', (tester) async {
        // No verdicts at all — exactly what the canonical evaluator returns
        // when `player_direct_player` has no row registered yet. The app
        // must behave as it did before feature flags existed.
        final flagRepository = _FakeFeatureFlagRemoteDataSource()
          ..verdicts = const [];
        final container = await pumpFlaggedApp(
          tester,
          flagRepository: flagRepository,
        );
        final router = container.read(routerProvider);

        final l10n = AppLocalizationsEn();
        await openPlayerChoiceSheet(tester, router);

        expect(find.text(l10n.directPlayer), findsOneWidget);
        expect(find.text(l10n.youtubePlayer), findsOneWidget);
        expect(find.text(l10n.modernPlayer), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'server kill switch (enabled=false) removes the direct-player '
          'option from the real sheet, and a refresh restores it',
          (tester) async {
        final flagRepository = _FakeFeatureFlagRemoteDataSource()
          ..verdicts = const [
            FeatureFlagEvaluation(
              key: FeatureFlagKey.playerDirectPlayer,
              enabled: false,
              version: 2,
            ),
          ];
        final container = await pumpFlaggedApp(
          tester,
          flagRepository: flagRepository,
        );
        final router = container.read(routerProvider);
        final l10n = AppLocalizationsEn();

        await openPlayerChoiceSheet(tester, router);

        // Kill switch active: only the direct player disappears.
        expect(find.text(l10n.directPlayer), findsNothing);
        expect(find.text(l10n.youtubePlayer), findsOneWidget);
        expect(find.text(l10n.modernPlayer), findsOneWidget);

        await dismissSheet(tester);

        // Rollback path: the operator re-enables server-side; the next
        // evaluation restores the option without any app update.
        flagRepository.verdicts = const [
          FeatureFlagEvaluation(
            key: FeatureFlagKey.playerDirectPlayer,
            enabled: true,
            version: 3,
          ),
        ];
        await container.read(featureFlagsProvider.notifier).refresh();
        await tester.pump();

        await openPlayerChoiceSheet(tester, router);
        expect(find.text(l10n.directPlayer), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'flags provider in the real app tree starts from safe defaults '
          'synchronously and reflects the server verdict after refresh',
          (tester) async {
        final flagRepository = _FakeFeatureFlagRemoteDataSource()
          ..verdicts = const [
            FeatureFlagEvaluation(
              key: FeatureFlagKey.playerDirectPlayer,
              enabled: false,
              version: 1,
            ),
          ];
        final container = await pumpFlaggedApp(
          tester,
          flagRepository: flagRepository,
          // Assert the PRE-refresh state: the disk cache is deliberately
          // DISABLED here (a supported configuration — see
          // FeatureFlagCache's nullable-prefs contract) so the scenario is
          // deterministic even though integration tests share one process
          // and a previous test may have persisted a user-keyed snapshot.
          refreshAfterPump: false,
          disableCache: true,
        );

        // First read (no fetch triggered by the auth hook here because the
        // scenario replaces the real Auth notifier): safe defaults, no
        // network, no throw.
        final initial = container.read(featureFlagsProvider);
        expect(initial.source, FeatureFlagSource.defaults);
        expect(
          initial.isEnabled(FeatureFlagKey.playerDirectPlayer),
          isTrue, // client default mirrors current production behavior
        );
        expect(initial.evaluatedAt, isNull);

        await container.read(featureFlagsProvider.notifier).refresh();

        final after = container.read(featureFlagsProvider);
        expect(after.source, FeatureFlagSource.server);
        expect(after.isEnabled(FeatureFlagKey.playerDirectPlayer), isFalse);
        expect(after.versionOf(FeatureFlagKey.playerDirectPlayer), 1);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
