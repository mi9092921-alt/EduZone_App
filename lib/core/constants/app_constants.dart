class AppConstants {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
}

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const locked = '/locked';
  static const appLocked = '/app-locked';
  static const suspended = '/suspended';
  static const banned = '/banned';
  static const maintenance = '/maintenance';
  static const forceUpdate = '/force-update';
  static const home = '/home';
  static const courses = '/courses';
  static const discover = '/discover';
  static const todo = '/todo';
  static const profile = '/profile';
  static const legal = '/legal';

  // Shell-branch children — MUST match the paths declared in
  // app_router.dart. (Previously these pointed at top-level paths like
  // '/notifications' that no route declared: navigating with them hit the
  // 404 screen.)
  static const notifications = '/home/notifications';
  static const downloads = '/courses/downloads';
  static const coursePreview = '/discover/course-preview';
}

class StorageKeys {
  static const String downloadWifiOnly = 'download_wifi_only';

  /// Last-watched lesson pointer per course. Keyed by the signed-in user id
  /// (Phase 9 account isolation): the pointer is an optimistic resume hint
  /// written by whichever account is watching and must never resolve for a
  /// different account after an app kill or passive revocation skipped the
  /// logout preferences wipe. An empty [ownerId] yields a key that no
  /// caller may read or write (callers guard on it first).
  static String lastWatchedLesson(String ownerId, int courseId) =>
      'last_watched_lesson_${ownerId}_$courseId';

  /// Stores the latest version string the user dismissed the optional dialog for.
  /// Prevents re-showing the dialog on every app launch for the same version.
  static const String lastDismissedUpdateVersion = 'last_dismissed_update_version';
}
