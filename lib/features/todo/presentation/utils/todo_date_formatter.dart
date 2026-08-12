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
  }) {
    if (isOverdue) {
      return l10n.overdueLabel(
        timeago.format(date, locale: locale),
      );
    }

    return l10n.dueLabel(
      DateFormat('MMM d, yyyy', locale).format(date),
    );
  }
}
