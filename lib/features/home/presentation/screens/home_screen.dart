import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/feature_flags/feature_flag_keys.dart';
import '../../../../core/feature_flags/feature_flags_provider.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
// Documented architecture debt (5c): the home dashboard refreshes the
// notifications list after realtime pushes; there is no event/shared-model
// representation of that list, so this remains a direct provider import
// (same debt class as the WorkManager isolate in the downloads feature).
import '../../../../features/notifications/application/providers/notifications_provider.dart'; // check-ignore: home dashboard refresh needs the notifications list (documented debt)
import '../../../../shared/components/course_card.dart';
import '../../../../shared/components/optional_update_dialog.dart';
import '../../../../shared/components/todo/todo_preview_tile.dart';
import '../../../../shared/models/auth_state.dart';
import '../../../../shared/models/todo_item.dart';
import '../../../../shared/models/update_info.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../application/providers/home_provider.dart';
import '../../domain/entities/home_course_summary.dart';
import '../../domain/entities/home_todo_summary.dart';
import '../../domain/entities/resume_lesson.dart';
import '../widgets/discovery_banner.dart';
import '../widgets/notifications_preview.dart';
import '../widgets/resume_card.dart';
import '../widgets/section_header.dart';
import '../widgets/welcome_header.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger optional update dialog after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOptionalUpdate());
  }

  void _checkOptionalUpdate() {
    final authState = ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;
    final updateInfo = authState.updateInfo;
    if (updateInfo == null ||
        updateInfo.status != UpdateStatus.optionalUpdate) {
      return;
    }
    // Show dialog — persistence is handled inside OptionalUpdateDialog
    OptionalUpdateDialog.maybeShow(context, updateInfo);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Watch relevant data streams. The resume provider is watched inside
    // the gated section below, so a kill-switched carousel never fetches.
    final recentCoursesAsync = ref.watch(recentCoursesProvider);
    final recentTodosAsync = ref.watch(recentTodosProvider);

    return AppScreen(
      useScaffold: false, // Nested inside MainShell
      onRefresh: () async {
        // Parallel invalidation for performance
        ref.invalidate(resumeLessonProvider);
        ref.invalidate(resumeLessonsProvider);
        ref.invalidate(recentCoursesProvider);
        ref.invalidate(recentTodosProvider);
        ref.invalidate(notificationsProvider);
      },
      child: Column(
        children: [
          // 1. Hero Section: Welcome & Greeting
          const WelcomeHeader(),

          // 2. Discovery Section (New)
          const DiscoveryBanner(),

          const SizedBox(height: AppSpacing.md),

          // 3. Notifications Preview (Hidden if no unread)
          const NotificationsPreview(),

          // 4. Primary Action: Resume Learning (Contextual)
          //
          // Remote kill switch (FeatureFlagKey.homeResumeCarousel): when
          // disabled the section — including its provider subscription and
          // loading/error states — is skipped entirely, so a killed resume
          // backend is not queried either. The default (true) preserves
          // today's behavior for an unregistered/unevaluated flag.
          if (ref
              .watch(featureFlagsProvider)
              .isEnabled(FeatureFlagKey.homeResumeCarousel)) ...[
            _RecentLessonsSection(
              lessonsAsync: ref.watch(resumeLessonsProvider),
              l10n: l10n,
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // 5. Subsection: My Recent Courses
          _RecentCoursesSection(coursesAsync: recentCoursesAsync, l10n: l10n),

          const SizedBox(height: AppSpacing.md),

          // 6. Subsection: Daily Tasks
          _DailyTasksSection(todosAsync: recentTodosAsync, l10n: l10n),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _RecentLessonsSection extends ConsumerWidget {
  final AsyncValue<List<ResumeLesson>> lessonsAsync;
  final AppLocalizations l10n;

  const _RecentLessonsSection({required this.lessonsAsync, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return lessonsAsync.when(
      data: (lessons) {
        if (lessons.isEmpty) return const SizedBox.shrink();
        final visibleLessons = lessons.take(3).toList();
        return Column(
          children: [
            SectionHeader(
              // Audit P0 (M5): the recent-lessons and recent-courses
              // sections both rendered "Continue Learning"; the lessons
              // section now uses the existing continueWatching key.
              title: l10n.continueWatching,
              onTrailingTapped: () => context.go(AppRoutes.courses),
              trailing: Text(
                l10n.see_all,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildResumeLessonsCarousel(
              visibleLessons
                  .map(
                    (lesson) => ResumeCard(
                      key: ValueKey(lesson.courseId),
                      resumeLesson: lesson,
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
      loading: () =>
          _buildResumeLessonsCarousel(const [ResumeCard(isLoading: true)]),
      error: (err, _) {
        if (kDebugMode) {
          debugPrint('[HomeScreen] Error loading resume lessons: ${err.runtimeType}');
        }
        // Audit P1 (M3): was a silent SizedBox.shrink() — the section
        // vanished on error. Now shows a retryable state like the
        // sibling sections.
        return AppEmptyState(
          isFullPage: false,
          icon: Icons.error_outline_rounded,
          title: ErrorHandler.getMessage(context, err),
          actionLabel: l10n.retryButton,
          onActionPressed: () => ref.invalidate(resumeLessonsProvider),
        );
      },
    );
  }

  Widget _buildResumeLessonsCarousel(List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth - (AppSpacing.lg * 2);
        final cardWidth = math.min(
          AppSizes.resumeCardMaxWidth,
          availableWidth,
        ).toDouble();

        return SizedBox(
          height: AppSizes.resumeCardHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) => SizedBox(
              width: cardWidth,
              height: AppSizes.resumeCardHeight,
              child: cards[index],
            ),
          ),
        );
      },
    );
  }
}

class _RecentCoursesSection extends ConsumerWidget {
  final AsyncValue<List<dynamic>> coursesAsync;
  final AppLocalizations l10n;

  const _RecentCoursesSection({required this.coursesAsync, required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SectionHeader(
          title: l10n.continue_learning,
          onTrailingTapped: () => context.go(AppRoutes.courses),
          trailing: Text(
            l10n.see_all,
            style: AppTextStyles.label.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 208,
          child: coursesAsync.when(
            data: (courses) {
              if (courses.isEmpty) {
                return AppEmptyState(
                  isFullPage: false,
                  title: l10n.no_recent_courses,
                  actionLabel: l10n.explore_courses,
                  onActionPressed: () => context.go(AppRoutes.courses),
                );
              }
              final visibleCourseCount = courses.length < 3
                  ? courses.length
                  : 3;

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                scrollDirection: Axis.horizontal,
                itemCount: visibleCourseCount,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  try {
                    final HomeCourseSummary course = courses[index];

                    final vm = RecentCourseVM(
                      id: course.id,
                      title: course.title,
                      thumbnailUrl: course.thumbnailUrl ?? '',
                      level: course.level,
                      totalLessons: course.totalLessons,
                      progress: (course.progressPct ?? 0.0) / 100.0,
                      currentLessonTitle: course.completedLessons != null
                          // Audit P0 (M6): was a hardcoded English
                          // 'Lesson N' — now localized via ARB.
                          ? l10n.lessonNumber(course.completedLessons! + 1)
                          : null,
                    );

                    return SizedBox(
                      width: 208,
                      child: RecentCourseCard(
                        // P8.8 fix: stable key so list diffing matches
                        // cards by course identity, not slot position,
                        // when recentCoursesProvider re-emits a reordered
                        // list — mirrors DiscoverCourseCard's existing
                        // key: ValueKey(course.id).
                        key: ValueKey(course.id),
                        data: vm,
                        onTap: () =>
                            context.push('${AppRoutes.courses}/${course.id}'),
                      ),
                    );
                  } catch (e) {
                    // Section 15: debugPrint is not release-gated in this
                    // codebase — gate raw exception detail behind
                    // kDebugMode, consistent with every other catch block
                    // touched in this pass.
                    if (kDebugMode) {
                      debugPrint(
                        '[HomeScreen] Rendering error for course at index $index: $e',
                      );
                    }
                    return const SizedBox.shrink();
                  }
                },
              );
            },
            loading: () => ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, index) =>
                  const SizedBox(width: 180, child: RecentCourseCardShimmer()),
            ),
            error: (err, _) => ErrorState(
              message: ErrorHandler.getMessage(context, err),
              onRetry: () => ref.invalidate(recentCoursesProvider),
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyTasksSection extends ConsumerWidget {
  final AsyncValue<List<HomeTodoSummary>> todosAsync;
  final AppLocalizations l10n;

  const _DailyTasksSection({required this.todosAsync, required this.l10n});

  /// Adapts a `home`-owned [HomeTodoSummary] into a full [TodoItem] so it can
  /// be rendered by `todo`'s own [TodoPreviewTile] widget. This mapping is a
  /// presentation-layer concern only — `home`'s domain/data layers never
  /// construct a [TodoItem] themselves (see ARCH-004).
  static TodoItem _toDisplayTodoItem(HomeTodoSummary t) => TodoItem(
    id: t.id,
    userId: t.userId,
    tenantId: t.tenantId,
    title: t.title,
    dueAt: t.dueAt,
    isCompleted: t.isCompleted,
    priority: t.priority,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SectionHeader(
          title: l10n.today_todos,
          onTrailingTapped: () => context.go(AppRoutes.todo),
          trailing: Text(
            l10n.see_all,
            style: AppTextStyles.label.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        todosAsync.when(
          data: (todos) {
            if (todos.isEmpty) {
              return AppEmptyState(
                isFullPage: false,
                title: l10n.no_recent_todos,
                actionLabel: l10n.addTask,
                onActionPressed: () => context.go(AppRoutes.todo),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];
                // P8.8 fix: stable key so list diffing matches tiles by
                // todo identity, not slot position, when this preview
                // list re-sorts/shrinks.
                return TodoPreviewTile(
                  key: ValueKey(todo.id),
                  todo: _toDisplayTodoItem(todo),
                );
              },
            );
          },
          loading: () => AppSkeleton(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return TodoPreviewTile(
                  todo: TodoItem(
                    id: 'skeleton_$index',
                    title: 'Loading Task Title', // check-ignore
                    createdAt: DateTime.now(),
                    userId: '',
                    tenantId: '',
                  ),
                );
              },
            ),
          ),
          error: (err, _) => ErrorState(
            message: ErrorHandler.getMessage(context, err),
            onRetry: () {
              ref.invalidate(recentTodosProvider);
            },
          ),
        ),
      ],
    );
  }
}
