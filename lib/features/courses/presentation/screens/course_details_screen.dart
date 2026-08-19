import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../../../shared/widgets/app_course_thumbnail.dart';
import '../../../../shared/widgets/app_refresh_indicator.dart';
import '../../../../shared/widgets/collapsing_tab_bar_delegate.dart';
import '../../application/providers/courses_provider.dart';
import '../../domain/entities/course.dart';
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
            title: l10n.failedToLoadCourses,
            description: ErrorHandler.getMessage(context, err),
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
                      onPressed: () => Navigator.of(context).pop(),
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
    final myCoursesAsync = ref.watch(myCoursesProvider);

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
            final enrollments = myCoursesAsync.value ?? [];
            final enrollment = enrollments
                .where((e) => e.courseId == course.id)
                .firstOrNull;
            final isEnrolled = enrollment != null;

            if (isEnrolled) {
              return _buildEnrolledFooterWithProgress(course, ref, l10n, ds);
            } else if (myCoursesAsync.isLoading && enrollments.isEmpty) {
              return const Center(child: CircularProgressIndicator());
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
                          timeago.format(enrollment.lastWatchedAt!),
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
                      : isNotStarted
                          ? l10n.resumeLearning
                          : l10n.resumeLearning,
                  onPressed: () {},
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

  Widget _buildNotEnrolledFooter(
    Course course,
    AppLocalizations l10n,
    DesignSystemColors ds,
  ) {
    return CourseEnrollPriceRow(course: course, l10n: l10n, ds: ds);
  }
}
