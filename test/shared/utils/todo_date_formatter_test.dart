import 'package:app/core/l10n/arb/app_localizations_en.dart';
import 'package:app/shared/utils/todo_date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  // The formatter builds `DateFormat('MMM d, yyyy', locale)` for the generic
  // branch. In the real app MaterialApp + flutter_localizations initialize
  // intl's date symbols; a pure unit test must do it explicitly or the first
  // DateFormat construction throws LocaleDataException
  // (UninitializedLocaleData) nondeterministically depending on what else
  // ran in the same test isolate.
  setUpAll(() async {
    await initializeDateFormatting('en');
    Intl.defaultLocale = 'en';
  });

  final l10n = AppLocalizationsEn();
  final now = DateTime(2026, 8, 25, 20);

  String format(DateTime date, {bool isOverdue = false}) {
    return TodoDateFormatter.format(
      date: date,
      isOverdue: isOverdue,
      l10n: l10n,
      locale: 'en',
      now: now,
    );
  }

  group('TodoDateFormatter', () {
    test('uses Today for a due date on the current calendar day', () {
      expect(format(DateTime(2026, 8, 25, 1)), 'Due: Today');
    });

    test('uses Yesterday for a due date on the previous calendar day', () {
      expect(format(DateTime(2026, 8, 24, 23, 59), isOverdue: true),
          'Overdue: Yesterday');
    });

    test('uses Tomorrow for a due date on the next calendar day', () {
      expect(format(DateTime(2026, 8, 26)), 'Due: Tomorrow');
    });

    test('keeps the regular date format for other days', () {
      expect(format(DateTime(2026, 8, 27)), 'Due: Aug 27, 2026');
    });
  });
}
