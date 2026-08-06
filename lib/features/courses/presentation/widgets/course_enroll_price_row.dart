import 'package:flutter/material.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/components/course/course_price_block.dart';
import '../../../../shared/components/course/enroll_action_button.dart';
import '../../domain/entities/course.dart';

/// The price + "Enroll" row shown to non-enrolled users at the bottom of a
/// course screen.
///
/// Shared by [CourseDetailsScreen]'s sticky footer and
/// [CoursePreviewScreen]'s `bottomNavigationBar`. Deliberately has no
/// container/decoration of its own — each screen keeps its own outer
/// container, since the details screen's container is shared with an
/// entirely different "enrolled, show progress" state, while the preview
/// screen's container is dedicated to this row alone.
class CourseEnrollPriceRow extends StatelessWidget {
  final Course course;
  final AppLocalizations l10n;
  final DesignSystemColors ds;

  const CourseEnrollPriceRow({
    super.key,
    required this.course,
    required this.l10n,
    required this.ds,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CoursePriceBlock(course: course, l10n: l10n, ds: ds),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(flex: 2, child: EnrollActionButton(l10n: l10n)),
      ],
    );
  }
}
