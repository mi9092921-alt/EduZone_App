import 'package:flutter/material.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_motion.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_text_styles.dart';

/// A premium animated linear progress bar with gradient fill.
///
/// Features:
///   - Rounded capsule shape
///   - Gradient fill (primary → accent)
///   - Smooth animated width transitions
///   - Optional inline percentage label
///   - 3 visual states: not started, in progress, completed
///
/// Usage:
/// ```dart
/// AppProgressBar(progress: 0.65, height: 6)
/// ```
class AppProgressBar extends StatefulWidget {
  /// Progress value from 0.0 to 1.0.
  final double progress;

  /// Height of the bar.
  final double height;

  /// Whether to show a percentage label above the bar.
  final bool showLabel;

  /// Optional label text override (e.g. "3/10 lessons").
  final String? labelText;

  /// Whether to show a skeleton shimmer.
  final bool isLoading;

  const AppProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.showLabel = false,
    this.labelText,
    this.isLoading = false,
  });

  @override
  State<AppProgressBar> createState() => _AppProgressBarState();
}

class _AppProgressBarState extends State<AppProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.decelerate),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AppProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.progress,
      ).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.decelerate),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);
    final isCompleted = widget.progress >= 1.0;
    final isNotStarted = widget.progress <= 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.labelText != null)
                Text(
                  widget.labelText!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: ds.textSecondary,
                  ),
                ),
              Text(
                '${(widget.progress * 100).round()}%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isCompleted
                      ? AppColors.success
                      : isNotStarted
                          ? ds.textMuted
                          : ds.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(widget.height / 2),
              child: SizedBox(
                height: widget.height,
                child: Stack(
                  children: [
                    // Track
                    Container(
                      decoration: BoxDecoration(
                        color: ds.border.withValues(alpha: 0.3),
                        borderRadius:
                            BorderRadius.circular(widget.height / 2),
                      ),
                    ),
                    // Fill
                    FractionallySizedBox(
                      widthFactor: _animation.value.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isCompleted
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.success,
                                    Color(0xFF34D399),
                                  ],
                                )
                              : AppColors.primaryGradient,
                          borderRadius:
                              BorderRadius.circular(widget.height / 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
