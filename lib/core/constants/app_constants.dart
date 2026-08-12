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
  static const coursePreview = '/course-preview';
  static const todo = '/todo';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const legal = '/legal';
  static const downloads = '/downloads';
}

class StorageKeys {
  static String lastWatchedLesson(int courseId) => 'last_watched_lesson_$courseId';

  /// Stores the latest version string the user dismissed the optional dialog for.
  /// Prevents re-showing the dialog on every app launch for the same version.
  static const String lastDismissedUpdateVersion = 'last_dismissed_update_version';
}
