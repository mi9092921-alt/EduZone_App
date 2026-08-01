import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../../core/l10n/arb/app_localizations.dart';

enum TodoPriorityStyle { dot, strip, pill }

class TodoPriorityIndicator extends StatelessWidget {
  final int priority;
  final TodoPriorityStyle style;

  const TodoPriorityIndicator({
    super.key,
    required this.priority,
    this.style = TodoPriorityStyle.dot,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor();

    switch (style) {
      case TodoPriorityStyle.strip:
        return Container(
          width: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      case TodoPriorityStyle.pill:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_getPriorityEmoji(), style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 4),
              Text(
                _getPriorityText(context),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      case TodoPriorityStyle.dot:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
    }
  }

  Color _getPriorityColor() {
    switch (priority) {
      case 2:
        return AppColors.error;
      case 1:
        return AppColors.warning;
      case 0:
      default:
        return AppColors.success;
    }
  }

  String _getPriorityText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (priority) {
      case 2:
        return l10n.priorityHigh;
      case 1:
        return l10n.priorityMedium;
      case 0:
      default:
        return l10n.priorityNormal;
    }
  }

  String _getPriorityEmoji() {
    switch (priority) {
      case 2:
        return '🔥';
      case 1:
        return '⚠️';
      case 0:
      default:
        return '✅';
    }
  }
}
