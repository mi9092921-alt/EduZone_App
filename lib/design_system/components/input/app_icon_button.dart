import 'package:flutter/material.dart';

/// A standardized IconButton component that enforces accessibility (Semantics & Tooltip).
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool? toggledState;
  final Color? color;
  final double? iconSize;
  final ButtonStyle? style;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final Color? backgroundColor;

  const AppIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.toggledState,
    this.color,
    this.iconSize,
    this.style,
    this.tooltip,
    this.padding,
    this.constraints,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(icon, color: color, size: iconSize);

    final String tooltipMessage = tooltip ?? semanticLabel;

    // Merge backgroundColor into style if provided
    final ButtonStyle? resolvedStyle = backgroundColor != null
        ? (style ?? const ButtonStyle()).copyWith(
            backgroundColor: WidgetStatePropertyAll(backgroundColor),
          )
        : style;

    return Semantics(
  button: true,
  label: semanticLabel,
  toggled: toggledState,
  enabled: onPressed != null,
  excludeSemantics: true,   
  child: IconButton(
    icon: iconWidget,
    onPressed: onPressed,
    color: color,
    iconSize: iconSize,
    style: resolvedStyle,
    tooltip: tooltipMessage,
    padding: padding,
    constraints: constraints,
  ),
);
  }
}
