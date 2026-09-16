import 'package:flutter/material.dart';

import '../../../core/l10n/arb/app_localizations.dart';
import '../../models/todo_item.dart';
import '../../utils/todo_date_formatter.dart';
import 'todo_ui_extension.dart';

class TodoUiMapper {
  static String getFormattedDate({
    required BuildContext context,
    required TodoItem todo,
  }) {
    if (todo.dueAt == null) return '';
    
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final isOverdue = todo.isOverdue(now);

    return TodoDateFormatter.format(
      date: todo.dueAt!,
      isOverdue: isOverdue,
      l10n: l10n,
      locale: locale,
      now: now,
    );
  }
}
