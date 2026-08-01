import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

/// A unified smart card that handles modern depth, padding, borders,
/// and interactive press states (scaling & shadow adjustment).
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool elevated;
  final bool animateScale;
  final double? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.onTap,
    this.elevated = true,
    this.animateScale = true,
    this.borderRadius,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (widget.onTap != null) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final ds = AppColors.of(context);

    final cardColor = widget.backgroundColor ?? ds.surface;
    final borderColor = widget.borderColor ?? ds.border.withValues(alpha: 0.1);
    final radius = widget.borderRadius ?? 16.0;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        margin: widget.margin ?? EdgeInsets.zero,
        transform: widget.animateScale && _isPressed
            ? Matrix4.diagonal3Values(0.985, 0.985, 1.0)
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.gradient == null ? cardColor : null,
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: widget.elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: _isPressed ? 8 : 15, // dynamic depth
                    offset: _isPressed
                        ? const Offset(0, 2)
                        : const Offset(0, 4),
                  ),
                ]
              : null,
          border: Border.all(color: borderColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: widget.padding ?? const EdgeInsets.all(AppSpacing.xl),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
