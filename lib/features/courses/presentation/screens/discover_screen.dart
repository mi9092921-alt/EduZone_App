import 'dart:async';

import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/components/course_card.dart';
import '../../application/providers/courses_provider.dart';
import '../../domain/entities/course.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class CategoryGroup {
  final String normalizedKey;
  final String displayName;
  final List<Course> courses;

  CategoryGroup({
    required this.normalizedKey,
    required this.displayName,
    required this.courses,
  });
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(publicCoursesProvider.notifier).fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _handleCourseTap(
    BuildContext context,
    WidgetRef ref,
    Course course,
    Set<String> enrolledIds,
  ) {
    if (enrolledIds.contains(course.id)) {
      context.go('/courses/${course.id}');
    } else {
      context.go('/discover/course-preview/${course.id}');
    }
  }

  List<CategoryGroup> _groupCourses(List<Course> courses, AppLocalizations l10n) {
    final groupsMap = <String, CategoryGroup>{};

    for (final course in courses) {
      final rawCat = course.category;
      final isGeneral = rawCat == null || rawCat.trim().isEmpty;
      final normalizedKey = isGeneral ? 'general' : rawCat.trim().toLowerCase();

      if (!groupsMap.containsKey(normalizedKey)) {
        groupsMap[normalizedKey] = CategoryGroup(
          normalizedKey: normalizedKey,
          displayName: isGeneral ? l10n.generalCategory : rawCat.trim(),
          courses: [],
        );
      }
      groupsMap[normalizedKey]!.courses.add(course);
    }

    // Separate general category
    final generalGroup = groupsMap.remove('general');

    // Sort other categories descending by count
    final sortedGroups = groupsMap.values.toList()
      ..sort((a, b) => b.courses.length.compareTo(a.courses.length));

    // If general group exists and is not empty, add it to the end
    if (generalGroup != null && generalGroup.courses.isNotEmpty) {
      sortedGroups.add(generalGroup);
    }

    return sortedGroups;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PaginatedCoursesState> state = ref.watch(publicCoursesProvider);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final ds = AppColors.of(context);

    final enrolledIds = ref
        .watch(myCoursesProvider)
        .when(
          data: (enrollments) => enrollments.map((e) => e.courseId).toSet(),
          loading: () => <String>{},
          error: (_, _) => <String>{},
        );

    return AppPageScaffold(
      title: l10n.discoverTab,
      centerTitle: true,
      backgroundColor: colorScheme.surfaceContainerLowest,
      controller: _scrollController,
      onRefresh: () async {
        ref.invalidate(publicCoursesProvider);
        ref.invalidate(myCoursesProvider);
      },
      actions: [
        IconButton(
          icon: const Icon(Icons.bookmark_border_rounded),
          tooltip: l10n.savedCoursesTitle,
          onPressed: () => context.push('/discover/saved'),
        ),
      ],
      slivers: [
        // Search Bar Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.md,
            ),
            child: AppTextField(
              label: l10n.searchCourses,
              controller: _searchController,
              prefixIcon: Icons.search_rounded,
            ),
          ),
        ),
        ..._buildStateSlivers(context, state, enrolledIds, l10n, ds),
      ],
    );
  }

  List<Widget> _buildStateSlivers(
    BuildContext context,
    AsyncValue<PaginatedCoursesState> state,
    Set<String> enrolledIds,
    AppLocalizations l10n,
    DesignSystemColors ds,
  ) {
    return state.when(
      data: (data) {
        final query = _query;
        final filteredCourses = query.isEmpty
            ? data.items
            : data.items
                .where((c) => c.title.toLowerCase().contains(query))
                .toList();

        if (filteredCourses.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(l10n.noContentAvailable)),
            ),
          ];
        }

        if (query.isNotEmpty) {
          // If searching, render all matching courses in a vertical list using horizontal cards
          return [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg)
                  .copyWith(top: AppSpacing.md),
              sliver: SliverList.separated(
                itemCount: filteredCourses.length,
                separatorBuilder: (_, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final course = filteredCourses[index];
                  final vm = DiscoverCourseVM(
                    id: course.id,
                    title: course.title,
                    thumbnailUrl: course.thumbnailUrl ?? '',
                    level: course.level,
                    instructorName: course.instructorName,
                    totalLessons: course.totalLessons ?? course.computedTotalLessons,
                    category: course.category,
                    durationMinutes: course.totalDurationMinutes > 0
                        ? course.totalDurationMinutes
                        : null,
                    studentsCount: course.studentsCount,
                    rating: course.rating,
                    isFree: course.isFree,
                    price: course.price,
                    isNew: course.isNew,
                  );
                  return DiscoverCourseCard(
                    key: ValueKey(course.id),
                    data: vm,
                    isHorizontal: true,
                    showLevelBadge: false,
                    onTap: () =>
                        _handleCourseTap(context, ref, course, enrolledIds),
                  );
                },
              ),
            ),
          ];
        }

        // If not searching, group by category client-side
        final categoryGroups = _groupCourses(data.items, l10n);

        return [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final group = categoryGroups[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        top: index == 0 ? AppSpacing.sm : AppSpacing.md,
                        bottom: AppSpacing.sm,
                      ),
                      child: Text(
                        group.displayName,
                        style: AppTextStyles.h3.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ds.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 240,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg),
                        scrollDirection: Axis.horizontal,
                        itemCount: group.courses.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(width: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final course = group.courses[index];
                          final vm = DiscoverCourseVM(
                            id: course.id,
                            title: course.title,
                            thumbnailUrl: course.thumbnailUrl ?? '',
                            level: course.level,
                            instructorName: course.instructorName,
                            totalLessons: course.totalLessons ?? course.computedTotalLessons,
                            category: course.category,
                            durationMinutes: course.totalDurationMinutes > 0
                                ? course.totalDurationMinutes
                                : null,
                            studentsCount: course.studentsCount,
                            rating: course.rating,
                            isFree: course.isFree,
                            price: course.price,
                            isNew: course.isNew,
                          );
                          return SizedBox(
                            width: 200,
                            child: DiscoverCourseCard(
                              key: ValueKey(course.id),
                              data: vm,
                              onTap: () => _handleCourseTap(
                                context,
                                ref,
                                course,
                                enrolledIds,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              childCount: categoryGroups.length,
            ),
          ),
          if (data.hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ];
      },
      // Fix: mimic the actual "category rows" layout (title + horizontal
      // carousel of 200x240 vertical cards) that appears once data has
      // loaded, instead of a flat isHorizontal list shimmer. Prevents the
      // visual layout jump between the loading state and the real content.
      // Uses DiscoverCourseCardShimmer's isHorizontal:false variant, which
      // previously existed in the codebase but was never actually used.
      loading: () => List.generate(2, (groupIndex) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: groupIndex == 0 ? AppSpacing.sm : AppSpacing.md,
              bottom: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(
                  child: AppSkeletonTile(height: 20, width: 140),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 240,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, index) =>
                        const SizedBox(width: AppSpacing.md),
                    itemBuilder: (_, index) => const SizedBox(
                      width: 200,
                      child: DiscoverCourseCardShimmer(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      error: (error, stack) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Text(
                l10n.errorLoading(error.toString()),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}