import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../core/logging/domain/app_event.dart';
import '../../../../core/logging/logging_providers.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/cross_feature/auth_shared.dart';
import '../../../../shared/widgets/app_course_thumbnail.dart';
import '../../../../shared/widgets/collapsing_tab_bar_delegate.dart';
import '../../../auth/domain/entities/auth_state.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import '../../application/providers/courses_provider.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/course_about_tab_content.dart';
import '../widgets/course_curriculum_preview.dart';
import '../widgets/course_enroll_price_row.dart';


class CoursePreviewScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CoursePreviewScreen({super.key, required this.courseId});

  @override
  ConsumerState<CoursePreviewScreen> createState() =>
      _CoursePreviewScreenState();
}

class _CoursePreviewScreenState extends ConsumerState<CoursePreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late final ProviderSubscription _enrollmentSub;

  // Prevent duplicate events and navigations
  bool _eventsSent = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Listen to tab changes for conditional sliver rebuilding
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward();

    // Listen for enrollment changes to auto-redirect
    _enrollmentSub = ref.listenManual<AsyncValue<List<CourseEnrollment>>>(
      myCoursesProvider,
      (previous, next) {
        next.whenData((enrollments) {
          if (!_navigated &&
              enrollments.any((e) => e.courseId == widget.courseId)) {
          _navigated = true;
          if (mounted) {
            context.pushReplacement('/courses/${widget.courseId}');
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _enrollmentSub.close();
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _emitEvents(Course course) {
    if (_eventsSent) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      String? userId;
      String? tenantId;
      if (authState is AuthAuthenticated) {
        userId = authState.user.id;
        tenantId = authState.user.tenantId;
      }
      ref
          .read(eventBusProvider)
          .emit(
            ScreenViewedEvent(
              timestamp: DateTime.now(),
              userId: userId,
              tenantId: tenantId,
              screenName: 'CoursePreviewScreen',
            ),
          );
      ref
          .read(eventBusProvider)
          .emit(
            CourseOpenedEvent(
              timestamp: DateTime.now(),
              userId: userId,
              tenantId: tenantId,
              courseId: course.id,
              courseTitle: course.title,
            ),
          );
      _eventsSent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailsProvider(widget.courseId));

    // Reactive analytics events
    ref.listen(courseDetailsProvider(widget.courseId), (prev, next) {
      next.whenData((course) {
        if (!_eventsSent) {
          _emitEvents(course);
        }
      });
    });

    final isEnrolled = ref
        .watch(isEnrolledProvider(widget.courseId))
        .when(data: (v) => v, loading: () => false, error: (_, _) => false);
    final l10n = AppLocalizations.of(context)!;
    final ds = AppColors.of(context);

    return Scaffold(
      backgroundColor: ds.background,
      body: courseAsync.when(
        data: (course) => _buildContent(context, course, l10n, ds),
        loading: () => AppSkeleton(
          child: _buildContent(context, Course.skeleton(), l10n, ds),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, color: ds.error, size: 48),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.errorLoading(err.toString()),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: ds.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: courseAsync.maybeWhen(
        data: (course) => isEnrolled
            ? const SizedBox.shrink()
            : _BottomEnrollBar(course: course, l10n: l10n, ds: ds),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Course course,
    AppLocalizations l10n,
    DesignSystemColors ds,
  ) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: CustomScrollView(
          slivers: [
            // 1. Media Header (SliverAppBar)
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
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
              ),
              actions: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: BookmarkButton(courseId: course.id),
                  ),
                ),
              ],
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
                background: _PreviewMedia(
                  course: course,
                  ds: ds,
                ),
              ),
            ),

            // 2. Info Section (Title + Meta + Instructor)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: AppTextStyles.h2.copyWith(
                        color: ds.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),

            // 3. Tab Bar
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
                  onTap: (_) => setState(() {}),
                  tabs: [
                    Tab(text: l10n.courseDescriptionLabel),
                    Tab(text: l10n.courseCurriculumLabel),
                  ],
                ),
                backgroundColor: ds.background,
              ),
            ),

            // 4. Tab Content
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: _tabController.index == 0
                    ? CourseAboutTabContent(course: course, l10n: l10n, ds: ds)
                    : CourseCurriculumPreview(
                        course: course,
                        ds: ds,
                        l10n: l10n,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _BottomEnrollBar extends StatefulWidget {
  final Course course;
  final AppLocalizations l10n;
  final DesignSystemColors ds;

  const _BottomEnrollBar({
    required this.course,
    required this.l10n,
    required this.ds,
  });

  @override
  State<_BottomEnrollBar> createState() => _BottomEnrollBarState();
}

class _BottomEnrollBarState extends State<_BottomEnrollBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        MediaQuery.paddingOf(context).bottom > 0
            ? MediaQuery.paddingOf(context).bottom
            : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: widget.ds.surface,
        boxShadow: AppElevation.shadowLg,
        border: Border(top: BorderSide(color: widget.ds.border, width: 0.5)),
      ),
      child: CourseEnrollPriceRow(
        course: widget.course,
        l10n: widget.l10n,
        ds: widget.ds,
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────

// _CoursePreviewBody was replaced by _buildContent within _CoursePreviewScreenState for a tabbed layout.

// ── Preview Media ─────────────────────────────────────────────────────────────


class _PreviewMedia extends StatelessWidget {
  final Course course;
  final DesignSystemColors ds;

  const _PreviewMedia({
    required this.course,
    required this.ds,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: AppCourseThumbnail(thumbnailUrl: course.thumbnailUrl, ds: ds),
    );
  }
}

// _ThumbnailFallback was extracted to lib/shared/widgets/app_thumbnail_fallback.dart
