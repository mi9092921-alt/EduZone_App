import 'package:app/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/arb/app_localizations.dart';
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

    // Section 21 (Navigation) gap fix: previously any unmatched/invalid
    // location (bad deep link, stale notification link, typo'd path,
    // removed route) fell through to go_router's built-in error page,
    // which renders the raw GoException/exception message to the user —
    // unlocalized, unstyled, and a minor internal-detail leak. This keeps
    // the failure inside the app's normal navigation/redirect flow instead:
    // the screen below still passes through `redirect` on every subsequent
    // navigation attempt (e.g. tapping "Home"), so an unauthenticated user
    // hitting a bad link is still safely bounced to /login rather than home.
    errorBuilder: (context, state) => const _RouteNotFoundScreen(),

    redirect: (context, state) {
      final appState = ref.read(appStateProvider);
      final location = state.matchedLocation;

      // Public routes — never redirect away from these
      final publicRoutes = {AppRoutes.login, AppRoutes.legal};

      // Restricted-state routes (screens for banned/suspended/locked/maintenance)
      final restrictedRoutes = {
        AppRoutes.locked,
        AppRoutes.appLocked,
        AppRoutes.suspended,
        AppRoutes.banned,
        AppRoutes.maintenance,
      };

      switch (appState) {
        // Initializing: auth check in progress → stay on splash
        case AppAuthState.initializing:
          return location == AppRoutes.splash ? null : AppRoutes.splash;

        // Login form submitted, waiting for the server response. Stay
        // put on /login (or /splash, if reached that way) instead of
        // forcing a navigation to /splash — LoginScreen shows its own
        // loading overlay for this state. See AppAuthState.authenticating.
        case AppAuthState.authenticating:
          return (location == AppRoutes.login || location == AppRoutes.splash)
              ? null
              : AppRoutes.splash;

        // A local session exists but couldn't be verified yet because of
        // a transient/network error — stay on splash and let the Auth
        // notifier retry in the background. Deliberately NOT treated
        // like `unauthenticated`: redirecting to /login here would be
        // exactly the "network blip forces logout" behavior this state
        // exists to prevent (see AuthDegraded's doc comment).
        case AppAuthState.sessionVerificationPending:
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

        case AppAuthState.appLocked:
          return location == AppRoutes.appLocked ? null : AppRoutes.appLocked;

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
        path: AppRoutes.appLocked,
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

/// Shown for any location that doesn't match a defined route (invalid/stale
/// deep link, removed route, typo'd path). Reuses existing design-system
/// primitives and localization keys only — no new copy/keys were added so
/// this doesn't require a localization regeneration step.
class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppScreen(
      child: AppEmptyState(
        icon: AppIcons.error,
        title: l10n.errorGeneric,
        actionLabel: l10n.homeTab,
        // Deliberately context.go (not push) through the normal router API
        // so the top-level `redirect` above still applies: an unauthenticated
        // user landing here via a bad/expired link is bounced to /login,
        // not silently handed the home screen.
        onActionPressed: () => context.go(AppRoutes.home),
      ),
    );
  }
}

/// Bridges Riverpod → GoRouter's Listenable refresh API.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(appStateProvider, (_, _) => notifyListeners());
  }
}
