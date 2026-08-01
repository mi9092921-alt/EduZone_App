import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/components/course_card.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../../auth/domain/entities/update_info.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/optional_update_dialog.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../todo/domain/entities/todo_item.dart';
import '../../../todo/presentation/widgets/variants/todo_preview_tile.dart';
import '../../domain/entities/home_course_summary.dart';
import '../../domain/entities/home_todo_summary.dart';
import '../providers/home_provider.dart';
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

    // Watch relevant data streams
    final resumeLessonAsync = ref.watch(resumeLessonProvider);
    final recentCoursesAsync = ref.watch(recentCoursesProvider);
    final recentTodosAsync = ref.watch(recentTodosProvider);

    return AppScreen(
      useScaffold: false, // Nested inside MainShell
      onRefresh: () async {
        // Parallel invalidation for performance
        ref.invalidate(resumeLessonProvider);
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
          resumeLessonAsync.when(
            data: (lesson) => lesson == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: ResumeCard(resumeLesson: lesson),
                  ),
            loading: () => const ResumeCard(isLoading: true),
            error: (err, stack) {
              debugPrint('[HomeScreen] Error loading resume lesson: $err');
              return const SizedBox.shrink();
            },
          ),

          const SizedBox(height: AppSpacing.md),

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
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                scrollDirection: Axis.horizontal,
                itemCount: 3,
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
                          ? 'Lesson ${course.completedLessons! + 1}'
                          : null,
                    );

                    return SizedBox(
                      width: 208,
                      child: RecentCourseCard(
                        data: vm,
                        onTap: () =>
                            context.push('${AppRoutes.courses}/${course.id}'),
                      ),
                    );
                  } catch (e) {
                    debugPrint(
                      '[HomeScreen] Rendering error for course at index $index: $e',
                    );
                    return const SizedBox.shrink();
                  }
                },
              );
            },
            loading: () => ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (_, index) => const SizedBox(
                width: 180,
                child: RecentCourseCardShimmer(),
              ),
            ),
            error: (err, _) => AppEmptyState(
              isFullPage: false,
              icon: Icons.error_outline_rounded,
              title: l10n.failedToLoadCourses,
              description: l10n.errorLoading(err.toString()),
              actionLabel: l10n.retryButton,
              onActionPressed: () => ref.invalidate(recentCoursesProvider),
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
            return Column(
              children: todos
                  .map((todo) => TodoPreviewTile(todo: _toDisplayTodoItem(todo)))
                  .toList(),
            );
          },
          loading: () => AppSkeleton(
            child: Column(
              children: List.generate(
                3,
                (index) => TodoPreviewTile(
                  todo: TodoItem(
                    id: 'skeleton_$index',
                    title: 'Loading Task Title',
                    createdAt: DateTime.now(),
                    userId: '',
                    tenantId: '',
                  ),
                ),
              ),
            ),
          ),
          error: (err, _) => AppEmptyState(
            isFullPage: false,
            icon: Icons.error_outline_rounded,
            title: l10n.errorLoadingTasks,
            description: l10n.errorLoading(err.toString()),
            actionLabel: l10n.retryButton,
            onActionPressed: () {
              ref.invalidate(recentTodosProvider);
            },
          ),
        ),
      ],
    );
  }
}
