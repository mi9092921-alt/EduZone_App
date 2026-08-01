import 'package:flutter/material.dart';

import '../../../../core/l10n/arb/app_localizations.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/expandable_description.dart';

class CourseDescriptionSection extends StatelessWidget {
  final String description;
  final DesignSystemColors ds;
  final AppLocalizations l10n;

  const CourseDescriptionSection({
    super.key,
    required this.description,
    required this.ds,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (description.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.courseDescriptionLabel,
          style: AppTextStyles.h3,
        ),
        const SizedBox(height: AppSpacing.sm),
        ExpandableDescription(
          text: description,
          ds: ds,
          l10n: l10n,
        ),
      ],
    );
  }
}
