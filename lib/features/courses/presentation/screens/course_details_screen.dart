import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/components/course/course_meta_row.dart';
import '../../../../shared/components/course/course_price_block.dart';
import '../../../../shared/components/course/enroll_action_button.dart';
import '../../../../shared/components/course/instructor_card.dart';
import '../../../../shared/widgets/app_course_thumbnail.dart';
import '../../../../shared/widgets/app_refresh_indicator.dart';
import '../../domain/entities/course.dart';
import '../providers/courses_provider.dart';
import '../utils/course_format_utils.dart';
import '../widgets/course_description_section.dart';
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
            description: l10n.errorLoading(err.toString()),
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
                      duration: const Duration(milliseconds: 200),
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
              delegate: _SliverAppBarDelegate(
                TabBar(
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
                ds.background,
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
                  delegate: SliverChildListDelegate([
                    CourseMetaRow(
                      course: course,
                      l10n: l10n,
                      ds: ds,
                      duration: formatCourseDuration(course.totalDurationMinutes, l10n),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CourseDescriptionSection(
                      description: course.description ?? '',
                      ds: ds,
                      l10n: l10n,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (course.learningObjectives != null && course.learningObjectives!.isNotEmpty) ...[
                      Text(l10n.whatYouWillLearn, style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.md),
                      ...course.learningObjectives!.map((obj) => _buildBulletPoint(ds, obj)),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    if (course.prerequisites != null && course.prerequisites!.isNotEmpty) ...[
                      Text(l10n.coursePrerequisites, style: AppTextStyles.h3),
                      const SizedBox(height: AppSpacing.md),
                      ...course.prerequisites!.map((req) => _buildBulletPoint(ds, req)),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    Text(l10n.instructorLabel, style: AppTextStyles.h3),
                    const SizedBox(height: AppSpacing.md),
                    _buildInstructorSection(course, ds, l10n),
                  ]),
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

  Widget _buildBulletPoint(DesignSystemColors ds, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(color: ds.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorSection(
    Course course,
    DesignSystemColors ds,
    AppLocalizations l10n,
  ) {
    return InstructorCard(course: course, ds: ds, l10n: l10n);
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
                        color: isCompleted ? AppColors.success : ds.textPrimary,
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
    return Row(
      children: [
        Expanded(
          child: CoursePriceBlock(course: course, l10n: l10n, ds: ds),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: EnrollActionButton(l10n: l10n),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this.backgroundColor);

  final TabBar _tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: backgroundColor,
      child: Column(
        children: [
          _tabBar,
          Divider(height: 1, color: AppColors.of(context).border),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
