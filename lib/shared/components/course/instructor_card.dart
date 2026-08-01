import 'package:flutter/material.dart';
import '../../../core/l10n/arb/app_localizations.dart';
import '../../../design_system/design_system.dart';
import '../../../features/courses/domain/entities/course.dart';
import '../../widgets/app_network_image.dart';

class InstructorCard extends StatelessWidget {
  final Course course;
  final AppLocalizations l10n;
  final DesignSystemColors ds;

  const InstructorCard({
    super.key,
    required this.course,
    required this.l10n,
    required this.ds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ds.surface2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: ds.border),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: course.instructorAvatar != null
                  ? AppNetworkImage(
                      url: course.instructorAvatar!,
                      width: 48,
                      height: 48,
                    )
                  : ColoredBox(
                      color: ds.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.person, color: ds.primary),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.instructorName ?? l10n.instructorLabel,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.instructorLabel} • ${course.studentsLabel} ${l10n.studentsLabel}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: ds.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: ds.textMuted,
          ),
        ],
      ),
    );
  }
}
