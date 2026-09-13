import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/l10n/arb/app_localizations.dart';

/// Production-grade date formatter for Todo items.
/// Decoupled from the UI layer and extensions to ensure pure functional formatting.
class TodoDateFormatter {
  static String format({
    required DateTime date,
    required bool isOverdue,
    required AppLocalizations l10n,
    required String locale,
    DateTime? now,
  }) {
    final dueDate = DateUtils.dateOnly(date.toLocal());
    final today = DateUtils.dateOnly((now ?? DateTime.now()).toLocal());
    // Compare UTC date-only values so a daylight-saving transition cannot
    // turn an adjacent calendar day into a zero-day duration.
    final dayDifference = DateTime.utc(
      dueDate.year,
      dueDate.month,
      dueDate.day,
    ).difference(
      DateTime.utc(today.year, today.month, today.day),
    ).inDays;

    final formattedDate = switch (dayDifference) {
      0 => l10n.dueToday,
      -1 => l10n.dueYesterday,
      1 => l10n.dueTomorrow,
      _ => DateFormat('MMM d, yyyy', locale).format(date),
    };

    if (isOverdue) {
      return l10n.overdueLabel(
        dayDifference == -1
            ? formattedDate
            : timeago.format(date, locale: locale),
      );
    }

    return l10n.dueLabel(formattedDate);
  }
}
