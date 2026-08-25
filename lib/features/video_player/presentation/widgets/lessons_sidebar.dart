import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../shared/components/lesson_tile.dart';
import '../../../../shared/cross_feature/courses_shared.dart';
import '../../../courses/domain/entities/course.dart';

class LessonsSidebar extends ConsumerWidget {
  final Course course;
  final String currentLessonId;
  final void Function(String lessonId) onLessonTap;

  const LessonsSidebar({
    super.key,
    required this.course,
    required this.currentLessonId,
    required this.onLessonTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allSections = course.sections ?? [];

    // تصفية الأقسام لعرض القسم الذي يحتوي على الدرس الحالي فقط
    final sections = allSections.where((section) {
      final lessons = section.lessons ?? [];
      return lessons.any((l) => l.id == currentLessonId);
    }).toList();

    final ds = AppColors.of(context);

    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            AppLocalizations.of(context)!.noContentAvailable,
            style: AppTextStyles.bodyMedium.copyWith(color: ds.textSecondary),
          ),
        ),
      );
    }

    // NOTE: Do NOT derive enrollment from `Lesson.hasAccess` here — that field
    // is only ever populated by the `get_course_lessons_with_access` RPC,
    // which nothing in this app currently calls. `getCourseOutline()` (the
    // query that actually feeds this screen's `course`) never returns
    // `has_access`, so `Lesson.hasAccess` silently defaults to `false` for
    // every lesson, which made every non-preview lesson show as locked
    // regardless of real enrollment. Use the same backend-verified
    // `isEnrolledProvider` that `SectionsAccordion`/`course_details_screen`
    // already rely on instead.
    final isEnrolled = ref
        .watch(isEnrolledProvider(course.id))
        .when(data: (v) => v, loading: () => false, error: (_, _) => false);

    return ListView.builder(
      key: const PageStorageKey('lessons_sidebar_list'),
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xl),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        final lessons = section.lessons ?? [];

        // Determine if this section contains the currently active lesson
        final hasCurrentLesson = lessons.any((l) => l.id == currentLessonId);

        return Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: hasCurrentLesson,
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            collapsedBackgroundColor: Colors.transparent,
            backgroundColor: ds.surface2.withValues(alpha: 0.3),
            title: Text(
              section.title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: ds.textPrimary,
              ),
            ),
            children: lessons.map((lesson) {
              final isCurrent = lesson.id == currentLessonId;
              final userProgress = lesson.userProgress?.isNotEmpty == true
                  ? lesson.userProgress!.first
                  : null;
              final isCompleted = userProgress?.completed ?? false;
              final isLocked = !isEnrolled && !lesson.isPreview;

              return Material(
                color: isCurrent ? ds.primarySoft : Colors.transparent,
                child: LessonTile(
                  title: lesson.title,
                  duration: lesson.durationSec != null
                      ? AppLocalizations.of(
                          context,
                        )!.minCount((lesson.durationSec! / 60).floor())
                      : null,
                  completed: isCompleted,
                  isLastWatched: isCurrent,
                  isLocked: isLocked,
                  isFree: lesson.isPreview,
                  isEnrolled: isEnrolled,
                  onTap: () {
                    onLessonTap(lesson.id);
                  },
                  onToggleCompleted: (_) {},
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
