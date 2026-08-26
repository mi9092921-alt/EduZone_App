import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/components/course_card.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../application/providers/courses_provider.dart';
import '../../domain/entities/course.dart';
import '../widgets/bookmark_button.dart';

class SavedCoursesScreen extends ConsumerWidget {
  const SavedCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final savedCoursesAsync = ref.watch(savedCoursesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return AppPageScaffold(
      title: l10n.savedCoursesTitle,
      centerTitle: true,
      backgroundColor: colorScheme.surfaceContainerLowest,
      // SavedCoursesScreen is pushed onto _rootNavigatorKey (above the shell),
      // so there is always a route to pop — but AppPageScaffold sets
      // automaticallyImplyLeading: false, so we must provide the button
      // explicitly to guarantee it appears regardless of the entry point.
      leading: BackButton(onPressed: () => context.pop()),
      onRefresh: () async {
        ref.invalidate(bookmarkedCoursesProvider);
      },
      onRetry: () {
        ref.invalidate(bookmarkedCoursesProvider);
      },
      error: savedCoursesAsync.hasError
          ? ErrorHandler.getMessage(context, savedCoursesAsync.error!)
          : null,
      slivers: [
        savedCoursesAsync.when(
          data: (courses) {
            if (courses.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: AppEmptyState(
                    icon: Icons.bookmark_border_rounded,
                    title: l10n.savedCoursesEmptyMessage,
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: AppSpacing.md);
                  }
                  final itemIndex = index ~/ 2;
                  final course = courses[itemIndex];
                  final vm = DiscoverCourseVM(
                    id: course.id,
                    title: course.title,
                    thumbnailUrl: course.thumbnailUrl ?? '',
                    level: course.level,
                    instructorName: course.instructorName,
                    totalLessons:
                        course.totalLessons ?? course.computedTotalLessons,
                    category: course.category,
                    durationMinutes: course.totalDurationMinutes > 0
                        ? course.totalDurationMinutes
                        : null,
                    rating: course.rating,
                    studentsCount: course.studentsCount,
                    isFree: course.isFree,
                    price: course.price,
                    isNew: course.isNew,
                  );
                  return DiscoverCourseCard(
                    data: vm,
                    isHorizontal: true,
                    showLevelBadge: false,
                    actionButton: BookmarkButton(
                      courseId: course.id,
                      size: AppSizes.avatarSm,
                      iconSize: AppSizes.iconSm,
                    ),
                    onTap: () =>
                        context.push('/discover/course-preview/${course.id}'),
                  );
                }, childCount: courses.isEmpty ? 0 : courses.length * 2 - 1),
              ),
            );
          },
          loading: () => SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return const SizedBox(height: AppSpacing.md);
                  }
                  return const DiscoverCourseCardShimmer(isHorizontal: true);
                },
                childCount: 7, // 4 skeleton items + 3 separators
              ),
            ),
          ),
          error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );
  }
}
