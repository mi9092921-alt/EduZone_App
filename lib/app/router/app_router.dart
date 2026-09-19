import 'package:app/design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/arb/app_localizations.dart';
import '../../core/navigation/app_page_transition.dart';
import '../../core/navigation/pending_deep_link_provider.dart';
import '../../core/security/security_service.dart';
import '../../features/auth/presentation/screens/banned_screen.dart';
import '../../features/auth/presentation/screens/force_update_screen.dart';
import '../../features/auth/presentation/screens/locked_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/maintenance_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/suspended_screen.dart';
import '../../features/courses/application/providers/courses_provider.dart';
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
import '../../features/video_player/presentation/screens/video_player/video_player_skeleton.dart';
import '../../features/video_player/presentation/screens/video_player_screen.dart';
import '../../features/video_player/presentation/widgets/modern_player_wrapper.dart';
import '../../features/video_player/presentation/widgets/player4_wrapper.dart';
import '../../features/video_player/presentation/widgets/youtube_player_wrapper.dart';
import '../../shared/models/auth_state.dart';
import '../../shared/utils/error_handler.dart';
import '../../shared/widgets/error_state.dart';
import '../state/app_state_provider.dart';
import 'main_shell.dart';

part 'app_router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Top-level path prefixes a deep link may target to be honourable after
/// login. Anything else (login/splash itself, legal, guard screens,
/// force-update, foreign paths like `//evil.com`) is discarded — this
/// keeps the pending-deep-link restore from becoming an open redirect.
const List<String> _deepLinkAllowedPrefixes = [
  AppRoutes.home,
  AppRoutes.discover,
  AppRoutes.courses,
  AppRoutes.todo,
  AppRoutes.profile,
];

/// Whether [candidate] (a full location string, possibly with a query) is
/// a protected app location worth restoring after the session resolves.
bool _isHonourableDeepLink(String? candidate) {
  if (candidate == null || !candidate.startsWith('/')) return false;
  // Scheme-relative (`//host/...`) or absolute-URL forms are never paths.
  if (candidate.startsWith('//')) return false;
  final path = candidate.split('?').first;
  return _deepLinkAllowedPrefixes.any(
    (prefix) => path == prefix || path.startsWith('$prefix/'),
  );
}

/// Read/write seam over [pendingDeepLinkProvider] so the redirect decision
/// ([evaluateAppRedirect]) stays a pure, directly testable function without
/// a Riverpod container.
abstract interface class PendingLinkStore {
  String? consume();
  void stash(String location);
  void clear();
}

class _ProviderPendingLinkStore implements PendingLinkStore {
  _ProviderPendingLinkStore(this._ref);

  final Ref _ref;

  @override
  String? consume() => _ref.read(pendingDeepLinkProvider.notifier).consume();

  @override
  void stash(String location) =>
      _ref.read(pendingDeepLinkProvider.notifier).stash(location);

  @override
  void clear() => _ref.read(pendingDeepLinkProvider.notifier).clear();
}

/// The COMPLETE redirect decision for the app router, extracted as a pure
/// function so every rule (kill switch, session states, deep-link stash/
/// restore) is unit-testable headlessly — the go_router redirect closure
/// below only adapts its inputs/outputs.
///
/// Navigation side effects on the pending deep link go through [linkStore].
String? evaluateAppRedirect({
  required AppAuthState appState,
  required String location,
  required bool killSwitchEngaged,
  required String uri,
  required PendingLinkStore linkStore,
}) {
  // Public routes — never redirect away from these. Note: AppRoutes.legal
  // ('/legal') is a prefix, not a real route — only '/legal/:type' is
  // declared; the exact-match below can never hit and the
  // startsWith('/legal') check at the unauthenticated case does the
  // real work.
  final publicRoutes = {AppRoutes.login, AppRoutes.legal};

  // Restricted-state routes (screens for banned/suspended/locked/maintenance)
  final restrictedRoutes = {
    AppRoutes.locked,
    AppRoutes.appLocked,
    AppRoutes.suspended,
    AppRoutes.banned,
    AppRoutes.maintenance,
  };

  void stashIfHonourable(String candidate) {
    if (_isHonourableDeepLink(candidate)) {
      linkStore.stash(candidate);
    }
  }

  // Security kill switch — highest priority, checked before any appState
  // branch. Once a RASP threat has fired, the ONLY permitted location is
  // /locked for the lifetime of the process: the appState switch below
  // would otherwise bounce an authenticated user from /locked straight
  // back to /home, silently defeating the kill switch. Logout from the
  // lock screen keeps the user here too (the flag outlives auth-state
  // changes); a process restart clears it and the RASP guards re-evaluate
  // from scratch.
  if (killSwitchEngaged) {
    return location == AppRoutes.locked ? null : AppRoutes.locked;
  }

  switch (appState) {
    // Initializing: auth check in progress → stay on splash
    case AppAuthState.initializing:
      if (location != AppRoutes.splash) {
        stashIfHonourable(uri);
      }
      return location == AppRoutes.splash ? null : AppRoutes.splash;

    // Login form submitted, waiting for the server response. Stay
    // put on /login (or /splash, if reached that way) instead of
    // forcing a navigation to /splash — LoginScreen shows its own
    // loading overlay for this state. See AppAuthState.authenticating.
    case AppAuthState.authenticating:
      if (location != AppRoutes.login && location != AppRoutes.splash) {
        stashIfHonourable(uri);
      }
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
      if (location != AppRoutes.splash) {
        stashIfHonourable(uri);
      }
      return location == AppRoutes.splash ? null : AppRoutes.splash;

    // Force update: block ALL routes until the app is updated
    case AppAuthState.forceUpdate:
      return location == AppRoutes.forceUpdate
          ? null
          : AppRoutes.forceUpdate;

    // Logging out: cleanup in progress → redirect to login immediately.
    // Also drop any pending deep link: a destination requested under
    // the outgoing session must not resurface for the next one.
    case AppAuthState.loggingOut:
      linkStore.clear();
      if (location == AppRoutes.login) return null;
      return AppRoutes.login;

    // Unauthenticated: block all protected routes
    case AppAuthState.unauthenticated:
      if (publicRoutes.contains(location) ||
          location.startsWith(AppRoutes.legal)) {
        return null;
      }
      if (location != AppRoutes.login) {
        // Preserve the requested destination so a successful login
        // lands there instead of unconditionally on /home (fixes
        // deep-link destination loss after login).
        stashIfHonourable(uri);
      }
      return AppRoutes.login;

    // Authenticated: block login/splash/restricted screens
    case AppAuthState.authenticated:
      if (location == AppRoutes.login ||
          location == AppRoutes.splash ||
          location == AppRoutes.forceUpdate ||
          restrictedRoutes.contains(location)) {
        // Restore a deep link intercepted while the session was still
        // being established (or while unauthenticated), if any.
        final pending = linkStore.consume();
        if (pending != null &&
            _isHonourableDeepLink(pending) &&
            pending != location) {
          return pending;
        }
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
}

/// Wires [SecurityService.killAppHandler] to navigate to [AppRoutes.locked]
/// via the root navigator key when a security threat is detected.
///
/// The handler MUST latch [SecurityService.killSwitchEngaged] before
/// navigating: the redirect below honours that latch ahead of its
/// appState switch, so the `/locked` destination survives instead of being
/// bounced back to `/home` by the authenticated-state restricted-routes
/// guard (which is exactly what happened before the latch existed).
void wireSecurityKillHandler() {
  SecurityService.killAppHandler = (reason) {
    debugPrint('[SECURITY] Threat termination requested: $reason');
    SecurityService.engageKillSwitch();
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

    // The full redirect decision lives in [evaluateAppRedirect] (pure,
    // unit-testable); this closure only adapts go_router's inputs.
    redirect: (context, state) => evaluateAppRedirect(
          appState: ref.read(appStateProvider),
          location: state.matchedLocation,
          killSwitchEngaged: SecurityService.killSwitchEngaged,
          uri: state.uri.toString(),
          linkStore: _ProviderPendingLinkStore(ref),
        ),


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
                          child: _VideoLessonRoute(
                            courseId: state.pathParameters['courseId']!,
                            lessonId: state.pathParameters['lessonId']!,
                            playerType: PlayerType.youtube,
                            playerBuilder: (courseId, lessonId, content) =>
                                (context, isFS, toggleFS, isVertical) =>
                                    YoutubePlayerWrapper(
                              courseId: courseId,
                              lessonId: lessonId,
                              lessonContent: content,
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
                          child: _VideoLessonRoute(
                            courseId: state.pathParameters['courseId']!,
                            lessonId: state.pathParameters['lessonId']!,
                            playerType: PlayerType.modern,
                            playerBuilder: (courseId, lessonId, content) =>
                                (context, isFS, toggleFS, isVertical) =>
                                    ModernPlayerWrapper(
                              courseId: courseId,
                              lessonId: lessonId,
                              lessonContent: content,
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
                          child: _VideoLessonRoute(
                            courseId: state.pathParameters['courseId']!,
                            lessonId: state.pathParameters['lessonId']!,
                            playerType: PlayerType.player4,
                            playerBuilder: (courseId, lessonId, content) =>
                                (context, isFS, toggleFS, isVertical) =>
                                    Player4Wrapper(
                              courseId: courseId,
                              lessonId: lessonId,
                              lessonContent: content,
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
    // UI-001: this screen has no app bar, no bottom navigation, and — when
    // reached from a stale/typo'd in-app link with earlier screens still on
    // the stack — nothing but the device's own back button/edge-swipe to
    // get out of it. That's an especially poor experience on iOS, where
    // there is no persistent OS-level back control to fall back on. Only
    // show an explicit in-app back affordance when there's actually
    // somewhere to go back to (`context.canPop()`); when this is the very
    // first thing shown (e.g. the app was cold-started from a bad deep
    // link), there genuinely is nothing to pop back to, and "Go to Home"
    // below remains the correct, sole way out.
    final canGoBack = context.canPop();
    return AppScreen(
      appBar: canGoBack
          ? AppBar(
              elevation: 0,
              leading: BackButton(onPressed: () => context.pop()),
            )
          : null,
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

/// Route composition for the video lesson player.
///
/// Watches the courses providers (course details + lesson content) here —
/// in the app's composition layer — and hands the resolved data down to
/// [VideoPlayerScreen] and the player wrappers as constructor parameters.
/// This keeps video_player free of imports from the courses feature: the
/// feature widgets accept plain data, and loading/error states (including
/// provider invalidation retries) live in this single wrapper.
class _VideoLessonRoute extends ConsumerWidget {
  final String courseId;
  final String lessonId;
  final PlayerType playerType;
  final VideoPlayerBuilderFactory playerBuilder;

  const _VideoLessonRoute({
    required this.courseId,
    required this.lessonId,
    required this.playerType,
    required this.playerBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailsProvider(courseId));
    final lessonContentAsync = ref.watch(lessonContentProvider(lessonId));
    final isEnrolled = ref
        .watch(isEnrolledProvider(courseId))
        .when(data: (v) => v, loading: () => false, error: (_, _) => false);

    return courseAsync.when(
      data: (course) {
        return lessonContentAsync.when(
          data: (content) => VideoPlayerScreen(
            courseId: courseId,
            lessonId: lessonId,
            course: course,
            lessonContent: content,
            isEnrolled: isEnrolled,
            playerType: playerType,
            playerBuilder: playerBuilder(courseId, lessonId, content),
          ),
          loading: () => const AppSkeleton(child: VideoPlayerSkeleton()),
          error: (e, _) => _VideoLessonError(
            message: ErrorHandler.getMessage(context, e),
            onRetry: () => ref.invalidate(lessonContentProvider(lessonId)),
          ),
        );
      },
      loading: () => const AppSkeleton(child: VideoPlayerSkeleton()),
      error: (e, _) => _VideoLessonError(
        message: ErrorHandler.getMessage(context, e),
        onRetry: () => ref.invalidate(courseDetailsProvider(courseId)),
      ),
    );
  }
}

/// Retryable error state for the video lesson route (Audit P1 (M3)).
class _VideoLessonError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _VideoLessonError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      child: ErrorState(message: message, onRetry: onRetry),
    );
  }
}
