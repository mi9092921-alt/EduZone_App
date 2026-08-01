import 'package:flutter/material.dart';

/// A universal status dot with an optional pulsing shadow effect.
class AppStatusDot extends StatelessWidget {
  final Color color;
  final double size;
  final bool hasPulse;

  const AppStatusDot({
    super.key,
    required this.color,
    this.size = 12.0,
    this.hasPulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2), 
          width: 2
        ),
        boxShadow: hasPulse
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
    );
  }
}
