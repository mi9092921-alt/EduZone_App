import 'package:flutter/material.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/components/course/course_meta_row.dart';
import '../../../../shared/components/course/instructor_card.dart';
import '../../domain/entities/course.dart';
import '../utils/course_format_utils.dart';
import 'course_bullet_point.dart';
import 'course_description_section.dart';

/// The "About" tab body shared by [CourseDetailsScreen] and
/// [CoursePreviewScreen]: meta row, description, learning objectives,
/// prerequisites and the instructor card.
///
/// Previously this exact sequence of widgets (and the `_buildBulletPoint`
/// helper) was copy-pasted in both screens. It now lives in one place so a
/// future change (e.g. adding a "skills" section) only needs to happen once.
///
/// Returns a flat list of widgets so callers can plug it into whichever
/// layout they need — a [Column] (preview) or a [SliverChildListDelegate]
/// (details).
List<Widget> buildCourseAboutTabContent({
  required Course course,
  required AppLocalizations l10n,
  required DesignSystemColors ds,
}) {
  return [
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

    if (course.learningObjectives != null &&
        course.learningObjectives!.isNotEmpty) ...[
      Text(l10n.whatYouWillLearn, style: AppTextStyles.h3),
      const SizedBox(height: AppSpacing.md),
      ...course.learningObjectives!.map(
        (obj) => CourseBulletPoint(ds: ds, text: obj),
      ),
      const SizedBox(height: AppSpacing.xl),
    ],

    if (course.prerequisites != null && course.prerequisites!.isNotEmpty) ...[
      Text(l10n.coursePrerequisites, style: AppTextStyles.h3),
      const SizedBox(height: AppSpacing.md),
      ...course.prerequisites!.map(
        (req) => CourseBulletPoint(ds: ds, text: req),
      ),
      const SizedBox(height: AppSpacing.xl),
    ],

    Text(l10n.instructorLabel, style: AppTextStyles.h3),
    const SizedBox(height: AppSpacing.md),
    InstructorCard(course: course, ds: ds, l10n: l10n),
  ];
}

/// Convenience [Column] wrapper around [buildCourseAboutTabContent] for
/// screens (like the preview) that render the tab as a single box, not a
/// sliver list.
class CourseAboutTabContent extends StatelessWidget {
  final Course course;
  final AppLocalizations l10n;
  final DesignSystemColors ds;

  const CourseAboutTabContent({
    super.key,
    required this.course,
    required this.l10n,
    required this.ds,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buildCourseAboutTabContent(course: course, l10n: l10n, ds: ds),
    );
  }
}
