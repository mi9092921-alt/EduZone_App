import 'package:flutter/material.dart';
import '../../../core/l10n/arb/app_localizations.dart';
import '../../../design_system/design_system.dart';
import '../../../features/courses/domain/entities/course.dart';

class CoursePriceBlock extends StatelessWidget {
  final Course course;
  final AppLocalizations l10n;
  final DesignSystemColors ds;

  const CoursePriceBlock({
    super.key,
    required this.course,
    required this.l10n,
    required this.ds,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          course.isFree
              ? l10n.freeLabel
              : '\$${course.price.toStringAsFixed(2)}',
          style: AppTextStyles.h2.copyWith(
            fontWeight: FontWeight.w800,
            color: course.isFree ? AppColors.success : ds.textPrimary,
          ),
        ),
        Text(
          l10n.fullAccessLabel,
          style: AppTextStyles.labelSmall.copyWith(color: ds.textMuted),
        ),
      ],
    );
  }
}
