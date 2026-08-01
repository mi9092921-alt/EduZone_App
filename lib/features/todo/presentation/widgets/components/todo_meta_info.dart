import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

class TodoMetaInfo extends StatelessWidget {
  final String dateText;
  final bool isOverdue;

  const TodoMetaInfo({
    super.key,
    required this.dateText,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    return Row(
      children: [
        Icon(
          AppIcons.event,
          size: 14,
          color: isOverdue ? AppColors.error : ds.textMuted,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          dateText,
          style: AppTextStyles.bodySmall.copyWith(
            color: isOverdue ? AppColors.error : ds.textMuted,
            fontWeight: isOverdue ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}
