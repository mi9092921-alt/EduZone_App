import 'dart:async';

import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FeedbackType { success, error, info, warning }

class FeedbackStyle {
  final Color bg;
  final Color text;
  final IconData icon;

  const FeedbackStyle({
    required this.bg,
    required this.text,
    required this.icon,
  });
}

class FeedbackService {
  FeedbackService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static FeedbackStyle _getStyle(FeedbackType type) {
    switch (type) {
      case FeedbackType.success:
        return const FeedbackStyle(
          bg: AppColors.successSoft,
          text: AppColors.success,
          icon: AppIcons.success,
        );
      case FeedbackType.error:
        return const FeedbackStyle(
          bg: AppColors.errorSoft,
          text: AppColors.error,
          icon: AppIcons.error,
        );
      case FeedbackType.warning:
        return const FeedbackStyle(
          bg: AppColors.warningSoft,
          text: AppColors.warning,
          icon: AppIcons.warning,
        );
      case FeedbackType.info:
        return const FeedbackStyle(
          bg: AppColors.primarySoft,
          text: AppColors.primary,
          icon: AppIcons.info,
        );
    }
  }

  /// Shows a feedback message.
  /// If [important] or [type] is error, it shows a Snackbar at the bottom.
  /// Otherwise, it shows a Toast-like overlay at the top (if context provided)
  /// or a Snackbar as fallback.
  static void show(
    BuildContext? context, {
    required String message,
    FeedbackType type = FeedbackType.info,
    bool important = false,
    SnackBarAction? action,
  }) {
    final style = _getStyle(type);

    // Trigger haptics
    if (type == FeedbackType.error) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    if (important ||
        type == FeedbackType.error ||
        context == null ||
        action != null) {
      _showSnackbar(message, style, action);
    } else {
      _showToast(context, message, type);
    }
  }

  static void _showSnackbar(
    String message,
    FeedbackStyle style, [
    SnackBarAction? action,
  ]) {
    final snackBar = SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(AppSpacing.lg),
      content: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.snackbarPaddingV,
        ),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: AppRadius.mdBorder,
          border: Border.all(color: style.text.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(style.icon, color: style.text),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: style.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  messengerKey.currentState?.hideCurrentSnackBar();
                  action.onPressed();
                },
                child: Text(
                  action.label,
                  style: AppTextStyles.label.copyWith(
                    color: style.text,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(snackBar);
  }

  static OverlayEntry? _activeToast;
  static Timer? _toastTimer;

  static void _showToast(
    BuildContext context,
    String message,
    FeedbackType type,
  ) {
    final style = _getStyle(type);

    _toastTimer?.cancel();
    _activeToast?.remove();

    final overlay = Overlay.of(context);

    _activeToast = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        style: style,
        onDismiss: () {
          _activeToast?.remove();
          _activeToast = null;
        },
      ),
    );

    overlay.insert(_activeToast!);

    _toastTimer = Timer(const Duration(seconds: 3), () {
      _activeToast?.remove();
      _activeToast = null;
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final FeedbackStyle style;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.style,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: widget.style.bg,
                borderRadius: AppRadius.mdBorder,
                border: Border.all(
                  color: widget.style.text.withValues(alpha: 0.1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.style.icon, color: widget.style.text, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: AppTextStyles.label.copyWith(
                        color: widget.style.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility alias to avoid breaking existing imports during migration
class AppSnackbar {
  static void showError({
    required BuildContext context,
    required String message,
  }) {
    FeedbackService.show(context, message: message, type: FeedbackType.error);
  }

  static void showSuccess({
    required BuildContext context,
    required String message,
  }) {
    FeedbackService.show(context, message: message, type: FeedbackType.success);
  }
}
