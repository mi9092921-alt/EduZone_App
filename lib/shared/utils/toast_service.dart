import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

enum ToastType { success, error, warning, info, securityAlert }

class _ToastContent extends StatelessWidget {
  final String message;
  final ToastType type;

  const _ToastContent({required this.message, required this.type});

  IconData _getIcon() {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
      case ToastType.securityAlert:
        return Icons.error_rounded;
      case ToastType.warning:
        return Icons.warning_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
      case ToastType.securityAlert:
        return AppColors.error;
      case ToastType.warning:
        return AppColors.warning;
      case ToastType.info:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    return Row(
      children: [
        Icon(_getIcon(), color: _getIconColor()),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTextStyles.bodyMedium.copyWith(color: ds.textPrimary),
          ),
        ),
      ],
    );
  }
}

class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    required ToastType type,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _ToastContent(message: message, type: type),
        backgroundColor: _bgColor(type),
        duration: _duration(type),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdBorder),
      ),
    );
  }

  static Color _bgColor(ToastType type) => switch (type) {
    ToastType.success => AppColors.successSoft,
    ToastType.error => AppColors.errorSoft,
    ToastType.warning => AppColors.warningSoft,
    ToastType.info => AppColors.info,
    ToastType.securityAlert => const Color(0xFFFEE2E2),
  };

  static Duration _duration(ToastType type) => switch (type) {
    ToastType.success => const Duration(seconds: 3),
    ToastType.warning => const Duration(seconds: 5),
    ToastType.info => const Duration(seconds: 4),
    ToastType.error || ToastType.securityAlert => const Duration(days: 1),
  };
}
