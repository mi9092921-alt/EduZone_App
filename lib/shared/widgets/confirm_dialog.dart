import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
// AppButton is available via design_system.dart import above

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDangerous;
  final bool isLoading;
  final VoidCallback? onConfirm;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.description,
    // Deliberately required (no hardcoded defaults): the previous Arabic
    // 'تأكيد'/'إلغاء' fallbacks silently rendered Arabic action labels in
    // the English UI for any future caller that forgot to pass l10n labels.
    required this.confirmLabel,
    required this.cancelLabel,
    this.isDangerous = false,
    this.isLoading = false,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgBorder),
      title: Text(title, style: AppTextStyles.h2),
      content: Text(description, style: AppTextStyles.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(cancelLabel),
        ),
        AppButton(
          label: confirmLabel,
          variant: isDangerous
              ? AppButtonVariant.danger
              : AppButtonVariant.primary,
          isLoading: isLoading,
          onPressed: onConfirm,
        ),
      ],
    );
  }
}
