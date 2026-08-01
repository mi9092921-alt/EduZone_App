import 'package:app/design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/todo_item.dart';

extension TodoUIX on TodoItem {
  bool isOverdue(DateTime now) {
    if (isCompleted || dueAt == null) return false;
    return dueAt!.isBefore(now);
  }

  /// Returns the corresponding [Color] based on the task priority.
  Color priorityColor(DesignSystemColors _) {
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
}
