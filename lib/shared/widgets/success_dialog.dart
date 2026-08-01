import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
// AppButton is available via design_system.dart import above

class SuccessDialog extends StatelessWidget {
  final String title;
  final String? description;

  const SuccessDialog({super.key, required this.title, this.description});

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 64,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: AppTextStyles.h2, textAlign: TextAlign.center),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            description!,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      AppButton(label: 'حسناً', onPressed: () => Navigator.pop(context)),
    ],
  );
}
