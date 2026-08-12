import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_motion.dart';
import '../../tokens/app_text_styles.dart';

/// A premium animated circular progress ring.
///
/// Supports 3 visual states:
///   - **Not Started**: faded ring, no fill
///   - **In Progress**: gradient stroke with animated sweep
///   - **Completed**: success color with optional pulse
///
/// Usage:
/// ```dart
/// AppProgressRing(progress: 0.75, size: 64)
/// ```
class AppProgressRing extends StatefulWidget {
  /// Progress value from 0.0 to 1.0.
  final double progress;

  /// Outer diameter of the ring.
  final double size;

  /// Stroke width of the ring track and fill.
  final double strokeWidth;

  /// Whether to show the percentage label in the center.
  final bool showLabel;

  /// Whether to show a skeleton shimmer instead of real data.
  final bool isLoading;

  const AppProgressRing({
    super.key,
    required this.progress,
    this.size = 56,
    this.strokeWidth = 5,
    this.showLabel = true,
    this.isLoading = false,
  });

  @override
  State<AppProgressRing> createState() => _AppProgressRingState();
}

class _AppProgressRingState extends State<AppProgressRing>
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
  void didUpdateWidget(covariant AppProgressRing oldWidget) {
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
    if (widget.isLoading) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: const CircularProgressIndicator(strokeWidth: 3),
      );
    }

    final ds = AppColors.of(context);
    final isCompleted = widget.progress >= 1.0;
    final isNotStarted = widget.progress <= 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: _animation.value,
              strokeWidth: widget.strokeWidth,
              trackColor: ds.border.withValues(alpha: 0.3),
              progressColor: isCompleted
                  ? AppColors.success
                  : isNotStarted
                      ? ds.textMuted
                      : ds.primary,
              gradientColors: isCompleted
                  ? [AppColors.success, AppColors.success]
                  : [AppColors.primary, AppColors.accent],
            ),
            child: widget.showLabel
                ? Center(
                    child: Text(
                      '${((_animation.value) * 100).round()}%',
                      style: AppTextStyles.label.copyWith(
                        color: isCompleted
                            ? AppColors.success
                            : isNotStarted
                                ? ds.textMuted
                                : ds.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: widget.size * 0.22,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;
  final List<Color> gradientColors;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
    required this.gradientColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track (background circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: gradientColors,
        ).createShader(rect);

      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor;
}
