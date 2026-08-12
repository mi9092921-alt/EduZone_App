import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/navigation/app_page_transition.dart';
import '../../core/security/security_service.dart';
import '../../features/auth/domain/entities/auth_state.dart';
import '../../features/auth/presentation/screens/banned_screen.dart';
import '../../features/auth/presentation/screens/force_update_screen.dart';
import '../../features/auth/presentation/screens/locked_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/maintenance_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/suspended_screen.dart';
import '../../features/courses/presentation/screens/course_details_screen.dart';
import '../../features/courses/presentation/screens/course_preview_screen.dart';
import '../../features/courses/presentation/screens/discover_screen.dart';
import '../../features/courses/presentation/screens/my_courses_screen.dart';
import '../../features/courses/presentation/screens/saved_courses_screen.dart';
import '../../features/downloads/presentation/screens/downloads_screen.dart';
import '../../features/downloads/presentation/screens/offline_player_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/legal_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/todo/presentation/screens/todo_screen.dart';
import '../../features/video_player/presentation/screens/video_player_screen.dart';
import '../../features/video_player/presentation/widgets/modern_player_wrapper.dart';
import '../../features/video_player/presentation/widgets/player4_wrapper.dart';
import '../../features/video_player/presentation/widgets/proxy_player_wrapper.dart';
import '../../features/video_player/presentation/widgets/youtube_player_wrapper.dart';
import '../state/app_state_provider.dart';
import 'main_shell.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Wires [SecurityService.killAppHandler] to navigate to [AppRoutes.locked]
/// via the root navigator key when a security threat is detected.
void wireSecurityKillHandler() {
  SecurityService.killAppHandler = (reason) {
    debugPrint('[SECURITY] Threat termination requested: $reason');
    final context = _rootNavigatorKey.currentContext;
    if (context != null && context.mounted) {
      GoRouter.of(context).go(AppRoutes.locked);
    } else {
      debugPrint(
        '[SECURITY] Root navigator context unavailable for threat navigation.',
      );
    }
  };
}

/// Observes and logs navigation events — debug builds only.
class AppNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (kDebugMode) {
      debugPrint(
        '--- [Navigation] Pushed: ${route.settings.name} (from: ${previousRoute?.settings.name}) ---',
      );
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (kDebugMode) {
      debugPrint(
        '--- [Navigation] Popped: ${route.settings.name} (to: ${previousRoute?.settings.name}) ---',
      );
    }
  }
}

@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  // Wire security kill handler to app router navigator
  wireSecurityKillHandler();

  // Notifier bridges Riverpod state changes to GoRouter's Listenable API
  final notifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    observers: [if (kDebugMode) AppNavigatorObserver()],

    redirect: (context, state) {
      final appState = ref.read(appStateProvider);
      final location = state.matchedLocation;

      // Public routes — never redirect away from these
      final publicRoutes = {AppRoutes.login, AppRoutes.legal};

      // Restricted-state routes (screens for banned/suspended/locked/maintenance)
      final restrictedRoutes = {
        AppRoutes.locked,
        AppRoutes.suspended,
        AppRoutes.banned,
        AppRoutes.maintenance,
      };

      switch (appState) {
        // Initializing: auth check in progress → stay on splash
        case AppAuthState.initializing:
          return location == AppRoutes.splash ? null : AppRoutes.splash;

        // Force update: block ALL routes until the app is updated
        case AppAuthState.forceUpdate:
          return location == AppRoutes.forceUpdate
              ? null
              : AppRoutes.forceUpdate;

        // Logging out: cleanup in progress → redirect to login immediately.
        case AppAuthState.loggingOut:
          if (location == AppRoutes.login) return null;
          return AppRoutes.login;

        // Unauthenticated: block all protected routes
        case AppAuthState.unauthenticated:
          if (publicRoutes.contains(location) ||
              location.startsWith(AppRoutes.legal)) {
            return null;
          }
          return AppRoutes.login;

        // Authenticated: block login/splash/restricted screens
        case AppAuthState.authenticated:
          if (location == AppRoutes.login ||
              location == AppRoutes.splash ||
              location == AppRoutes.forceUpdate ||
              restrictedRoutes.contains(location)) {
            return AppRoutes.home;
          }
          return null;

        // Account restriction states — redirect to dedicated screens
        case AppAuthState.banned:
          return location == AppRoutes.banned ? null : AppRoutes.banned;

        case AppAuthState.suspended:
          return location == AppRoutes.suspended ? null : AppRoutes.suspended;

        case AppAuthState.locked:
          return location == AppRoutes.locked ? null : AppRoutes.locked;

        case AppAuthState.maintenance:
          return location == AppRoutes.maintenance
              ? null
              : AppRoutes.maintenance;
      }
    },

    routes: [
      GoRoute(
        path: AppRoutes.forceUpdate,
        pageBuilder: (context, state) => buildTransitionPage(
          state: state,
          child: const ForceUpdateScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            buildTransitionPage(state: state, child: const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => buildTransitionPage(
          state: state,
          child: LoginScreen(reason: state.uri.queryParameters['reason']),
        ),
      ),
      GoRoute(
        path: AppRoutes.locked,
        pageBuilder: (context, state) =>
            buildTransitionPage(state: state, child: const LockedScreen()),
      ),
      GoRoute(
        path: AppRoutes.suspended,
        pageBuilder: (context, state) =>
            buildTransitionPage(state: state, child: const SuspendedScreen()),
      ),
      GoRoute(
        path: AppRoutes.banned,
        pageBuilder: (context, state) =>
            buildTransitionPage(state: state, child: const BannedScreen()),
      ),
      GoRoute(
        path: AppRoutes.maintenance,
        pageBuilder: (context, state) =>
            buildTransitionPage(state: state, child: const MaintenanceScreen()),
      ),
      GoRoute(
        path: '${AppRoutes.legal}/:type',
        pageBuilder: (context, state) => buildTransitionPage(
          state: state,
          child: LegalScreen(type: state.pathParameters['type'] ?? 'terms'),
        ),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (context, state) => buildTransitionPage(
                  state: state,
                  child: const HomeScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => buildTransitionPage(
                      state: state,
                      child: const NotificationsScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                pageBuilder: (context, state) => buildTransitionPage(
                  state: state,
                  child: const DiscoverScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'saved',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => buildTransitionPage(
                      state: state,
                      child: const SavedCoursesScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'course-preview/:courseId',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => buildTransitionPage(
                      state: state,
                      child: CoursePreviewScreen(
                        courseId: state.pathParameters['courseId']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.courses,
                pageBuilder: (context, state) => buildTransitionPage(
                  state: state,
                  child: const MyCoursesScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'downloads',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => buildTransitionPage(
                      state: state,
                      child: const DownloadsScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'offline-player/:downloadId',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) => buildTransitionPage(
                          state: state,
                          child: OfflinePlayerScreen(
                            downloadId: state.pathParameters['downloadId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':courseId',
                    parentNavigatorKey: _rootNavigatorKey,
                    pageBuilder: (context, state) => buildTransitionPage(
                      state: state,
                      child: CourseDetailsScreen(
                        courseId: state.pathParameters['courseId']!,
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'lesson/:lessonId',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) => buildTransitionPage(
                          state: state,
                          child: VideoPlayerScreen(
                            courseId: state.pathParameters['courseId']!,
                            lessonId: state.pathParameters['lessonId']!,
                            playerBuilder: (context, isFS, toggleFS, isVertical) =>
                                YoutubePlayerWrapper(
                              courseId: state.pathParameters['courseId']!,
                              lessonId: state.pathParameters['lessonId']!,
                              isFullScreen: isFS,
                              onToggleFullScreen: toggleFS,
                              isVertical: isVertical,
                            ),
                          ),
                        ),
                      ),
                      // مسار المشغّل الوسيط (Proxy Player)
                      GoRoute(
                        path: 'lesson2/:lessonId',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) => buildTransitionPage(
                          state: state,
                          child: VideoPlayerScreen(
                            courseId: state.pathParameters['courseId']!,
                            lessonId: state.pathParameters['lessonId']!,
                            playerType: PlayerType.proxy,
                            playerBuilder: (context, isFS, toggleFS, isVertical) =>
                                ProxyPlayerWrapper(
                              courseId: state.pathParameters['courseId']!,
                              lessonId: state.pathParameters['lessonId']!,
                              isFullScreen: isFS,
                              onToggleFullScreen: toggleFS,
                              isVertical: isVertical,
                            ),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'lesson3/:lessonId',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) => buildTransitionPage(
                          state: state,
                          child: VideoPlayerScreen(
                            courseId: state.pathParameters['courseId']!,
                            lessonId: state.pathParameters['lessonId']!,
                            playerType: PlayerType.modern,
                            playerBuilder: (context, isFS, toggleFS, isVertical) =>
                                ModernPlayerWrapper(
                              courseId: state.pathParameters['courseId']!,
                              lessonId: state.pathParameters['lessonId']!,
                              isFullScreen: isFS,
                              onToggleFullScreen: toggleFS,
                              isVertical: isVertical,
                            ),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'lesson4/:lessonId',
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) => buildTransitionPage(
                          state: state,
                          child: VideoPlayerScreen(
                            courseId: state.pathParameters['courseId']!,
                            lessonId: state.pathParameters['lessonId']!,
                            playerType: PlayerType.player4,
                            playerBuilder: (context, isFS, toggleFS, isVertical) =>
                                Player4Wrapper(
                              courseId: state.pathParameters['courseId']!,
                              lessonId: state.pathParameters['lessonId']!,
                              isFullScreen: isFS,
                              onToggleFullScreen: toggleFS,
                              isVertical: isVertical,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.todo,
                pageBuilder: (context, state) => buildTransitionPage(
                  state: state,
                  child: const TodoScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) => buildTransitionPage(
                  state: state,
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Bridges Riverpod → GoRouter's Listenable refresh API.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(appStateProvider, (_, _) => notifyListeners());
  }
}
