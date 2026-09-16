import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../app/app_initializer.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/models/course.dart';
import '../../../../shared/models/section.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../../../shared/widgets/app_course_thumbnail.dart';
import '../../../../shared/widgets/app_refresh_indicator.dart';
import '../../../../shared/widgets/collapsing_tab_bar_delegate.dart';
import '../../application/providers/courses_provider.dart';
import '../widgets/course_about_tab_content.dart';
import '../widgets/course_enroll_price_row.dart';
import '../widgets/sections_accordion.dart';

class CourseDetailsScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CourseDetailsScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailsScreen> createState() =>
      _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends ConsumerState<CourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final courseAsync = ref.watch(courseDetailsProvider(widget.courseId));
    final ds = AppColors.of(context);

    return Scaffold(
      backgroundColor: ds.background,
      body: AppRefreshIndicator(
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () async {
          ref.invalidate(courseDetailsProvider(widget.courseId));
          ref.invalidate(myCoursesProvider);
          ref.invalidate(myCourseEnrollmentProvider(widget.courseId));
          ref.invalidate(courseProgressProvider(widget.courseId));
        },
        child: courseAsync.when(
          data: (course) => _buildContent(context, course, ref, l10n, ds),
          loading: () => AppSkeleton(
            child: _buildContent(context, Course.skeleton(), ref, l10n, ds),
          ),
          error: (err, stack) => AppEmptyState(
            icon: Icons.error_outline_rounded,
            title: ErrorHandler.getMessage(context, err),
            actionLabel: l10n.retryButton,
            onActionPressed: () {
              ref.invalidate(courseDetailsProvider(widget.courseId));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Course course,
    WidgetRef ref,
    AppLocalizations l10n,
    DesignSystemColors ds,
  ) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // Parallax Header with Fade-in Title
            SliverAppBar(
              expandedHeight: 240.0,
              pinned: true,
              leading: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    child: BackButton(
                      color: Colors.white,
                      // Audit P1 (M4): go_router instead of Navigator.
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
              ),
              backgroundColor: ds.background,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    final top = constraints.biggest.height;
                    final isCollapsed = top <= (MediaQuery.paddingOf(context).top + kToolbarHeight + 10);
                    
                    return AnimatedOpacity(
                      duration: AppMotion.fast,
                      opacity: isCollapsed ? 1.0 : 0.0,
                      child: Text(
                        course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(
                          color: ds.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppCourseThumbnail(
                      thumbnailUrl: course.thumbnailUrl,
                      ds: ds,
                      alignment: Alignment.bottomCenter,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black26,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Header (Title)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  course.title,
                  style: AppTextStyles.h2.copyWith(
                    color: ds.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: CollapsingTabBarDelegate(
                tabBar: TabBar(
                  controller: _tabController,
                  labelColor: ds.primary,
                  unselectedLabelColor: ds.textMuted,
                  indicatorColor: ds.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: AppTextStyles.bodyMedium,
                  tabs: [
                    Tab(text: l10n.courseDescriptionLabel),
                    Tab(text: l10n.courseCurriculumLabel),
                  ],
                ),
                backgroundColor: ds.background,
                dividerColor: ds.border,
              ),
            ),

            // Tab Content
            if (_tabController.index == 1) ...[
              // Curriculum Tab content
              if (course.sections == null || course.sections!.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Text(
                        l10n.noContentAvailable,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: ds.textMuted,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final isEnrolled = ref
                        .watch(isEnrolledProvider(course.id))
                        .when(
                          data: (v) => v,
                          loading: () => false,
                          error: (_, _) => false,
                        );
                    return SectionsAccordion(
                      section: course.sections![index],
                      courseId: course.id,
                      courseTitle: course.title,
                      isEnrolled: isEnrolled,
                    );
                  }, childCount: course.sections!.length),
                ),
            ] else ...[
              // About Tab content (Description, Learning Points, etc.)
              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    buildCourseAboutTabContent(course: course, l10n: l10n, ds: ds),
                  ),
                ),
              ),
            ],

            // Extra space for sticky footer
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),

        // Sticky footer
        _buildStickyFooter(context, course, ref, l10n, ds),
      ],
    );
  }

  Widget _buildStickyFooter(
    BuildContext context,
    Course course,
    WidgetRef ref,
    AppLocalizations l10n,
    DesignSystemColors ds,
  ) {
    // P8.5 fix: this footer only needs to know whether *this* course is
    // enrolled, but previously watched the entire myCoursesProvider list
    // (every enrollment for the user) and filtered it locally. That meant
    // Course Details rebuilt this footer whenever *any* enrollment
    // anywhere changed, and forced a full-list fetch as a side effect of
    // opening a single course's page — duplicate network work per P8.16.
    // myCourseEnrollmentProvider(courseId) is a single-row fetch and is
    // already the exact provider _buildEnrolledFooterWithProgress uses
    // right below; watching it here too is free (same cached instance)
    // and the existing onRefresh handler above already invalidates it
    // alongside myCoursesProvider, so refresh/enroll-status semantics are
    // unchanged.
    final enrollmentAsync = ref.watch(myCourseEnrollmentProvider(course.id));

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom > 0
              ? MediaQuery.paddingOf(context).bottom
              : AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: ds.surface,
          boxShadow: AppElevation.shadowLg,
        ),
        child: Builder(
          builder: (context) {
            final isEnrolled = enrollmentAsync.value != null;

            if (isEnrolled) {
              return _buildEnrolledFooterWithProgress(course, ref, l10n, ds);
            } else if (enrollmentAsync.isLoading) {
              // Audit P1 (M2): skeleton instead of a spinner, matching the
              // enrollment skeleton below.
              return AppSkeleton(
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: ds.surface2,
                    borderRadius: AppRadius.smBorder,
                  ),
                ),
              );
            } else {
              return _buildNotEnrolledFooter(course, l10n, ds);
            }
          },
        ),
      ),
    );
  }

  Widget _buildEnrolledFooterWithProgress(
    Course course,
    WidgetRef ref,
    AppLocalizations l10n,
    DesignSystemColors ds,
  ) {
    final enrollmentAsync = ref.watch(myCourseEnrollmentProvider(course.id));

    return Builder(
      builder: (context) {
        final enrollment = enrollmentAsync.value;

        if (enrollment != null) {
          final isCompleted = enrollment.status == 'completed';
          final isNotStarted = enrollment.progressPct == 0;
          final normalizedProgress = enrollment.progressPct / 100.0;

          return Row(
            children: [
              AppProgressRing(
                progress: normalizedProgress,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isCompleted
                          ? l10n.courseCompleted
                          : isNotStarted
                              ? l10n.notStarted
                              : l10n.courseProgress,
                      style: AppTextStyles.label.copyWith(
                        color: isCompleted ? ds.successText : ds.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.lessonsCompleted(
                        enrollment.completedLessons,
                        enrollment.totalLessons,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: ds.textMuted,
                      ),
                    ),
                    if (enrollment.lastWatchedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.lastWatched(
                          timeago.format(
                            enrollment.lastWatchedAt!,
                            // Audit P0 (H4): timeago has no default locale
                            // registered via setDefaultLocale, so this
                            // previously rendered English relative time
                            // inside the Arabic string.
                            locale: Localizations.localeOf(
                              context,
                            ).languageCode,
                          ),
                        ),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: ds.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: isCompleted
                      ? l10n.reviewCourse
                      : l10n.resumeLearning,
                  onPressed: () => _openLesson(
                    context,
                    course,
                    _resolveResumeLessonId(
                      course,
                      restartFromStart: isCompleted,
                    ),
                  ),
                ),
              ),
            ],
          );
        } else if (enrollmentAsync.isLoading) {
          return AppSkeleton(
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: ds.surface2,
                borderRadius: AppRadius.smBorder,
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  /// Audit P0 (H1): the enrolled footer CTA was a dead button
  /// (`onPressed: () {}`). Resume opens the lesson recorded in
  /// [StorageKeys.lastWatchedLesson], falling back to the first lesson of
  /// the first section; a completed course ("Review") restarts from the
  /// first lesson. Navigation uses the default `/lesson/` player route —
  /// the same entry point ResumeCard uses on Home; the in-player switch
  /// sheet still allows changing the playback backend.
  String? _resolveResumeLessonId(
    Course course, {
    required bool restartFromStart,
  }) {
    if (!restartFromStart) {
      final lastWatched = AppInitializer.prefs.getString(
        StorageKeys.lastWatchedLesson(int.tryParse(course.id) ?? 0),
      );
      if (lastWatched != null && lastWatched.isNotEmpty) {
        return lastWatched;
      }
    }
    final sections = course.sections ?? const <Section>[];
    for (final section in sections) {
      final lessons = section.lessons;
      if (lessons != null && lessons.isNotEmpty) {
        return lessons.first.id;
      }
    }
    return null;
  }

  void _openLesson(BuildContext context, Course course, String? lessonId) {
    if (lessonId == null || lessonId.isEmpty) return;
    context.push('${AppRoutes.courses}/${course.id}/lesson/$lessonId');
  }

  Widget _buildNotEnrolledFooter(
    Course course,
    AppLocalizations l10n,
    DesignSystemColors ds,
  ) {
    return CourseEnrollPriceRow(course: course, l10n: l10n, ds: ds);
  }
}
