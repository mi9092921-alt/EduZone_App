import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/utils/error_handler.dart';
import '../../application/providers/courses_provider.dart';
import '../widgets/my_courses_preview.dart';

class MyCoursesScreen extends ConsumerWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final myCoursesAsync = ref.watch(myCoursesProvider);

    return AppPageScaffold(
      title: l10n.coursesTab,
      onRefresh: () async => ref.invalidate(myCoursesProvider),
      onRetry: () => ref.invalidate(myCoursesProvider),
      error: myCoursesAsync.hasError
          ? ErrorHandler.getMessage(context, myCoursesAsync.error!)
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.download_rounded),
          onPressed: () => context.push('/courses/downloads'),
          tooltip: l10n.downloads,
        ),
      ],
      slivers: [
        myCoursesAsync.when(
          data: (enrollments) {
            if (enrollments.isEmpty) {
              return SliverFillRemaining(
                child: AppEmptyState(
                  icon: Icons.school_rounded,
                  title: l10n.no_courses_available,
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: AppSpacing.md);
                    }
                    final itemIndex = index ~/ 2;
                    return MyCoursesPreview(enrollment: enrollments[itemIndex]);
                  },
                  childCount: enrollments.isEmpty ? 0 : enrollments.length * 2 - 1,
                ),
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
                  return const MyCoursesPreview(isLoading: true);
                },
                childCount: 7, // 4 items + 3 separators
              ),
            ),
          ),
          error: (err, stack) =>
              const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );
  }
}
