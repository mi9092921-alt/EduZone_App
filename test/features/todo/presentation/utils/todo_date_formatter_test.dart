import 'package:app/core/l10n/arb/app_localizations_en.dart';
import 'package:app/features/todo/presentation/utils/todo_date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
