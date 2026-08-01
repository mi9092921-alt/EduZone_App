import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Arabic and English lessonsCount ICU pluralizations', (WidgetTester tester) async {
    // English locale tests
    final enL10n = lookupAppLocalizations(const Locale('en'));
    expect(enL10n.lessonsCount(0), equals('No lessons'));
    expect(enL10n.lessonsCount(1), equals('1 lesson'));
    expect(enL10n.lessonsCount(2), equals('2 lessons'));
    expect(enL10n.lessonsCount(3), equals('3 lessons'));
    expect(enL10n.lessonsCount(10), equals('10 lessons'));
    expect(enL10n.lessonsCount(11), equals('11 lessons'));
    expect(enL10n.lessonsCount(25), equals('25 lessons'));
    expect(enL10n.lessonsCount(100), equals('100 lessons'));

    // Arabic locale tests covering all 6 ICU plural forms:
    // 0 = zero (لا توجد دروس)
    // 1 = one (درس واحد)
    // 2 = two (درسان)
    // 3-10 = few ({count} دروس)
    // 11-99 = many ({count} درسًا)
    // 100+ = other ({count} درس)
    final arL10n = lookupAppLocalizations(const Locale('ar'));
    expect(arL10n.lessonsCount(0), equals('لا توجد دروس'));
    expect(arL10n.lessonsCount(1), equals('درس واحد'));
    expect(arL10n.lessonsCount(2), equals('درسان'));
    expect(arL10n.lessonsCount(3), equals('3 دروس'));
    expect(arL10n.lessonsCount(10), equals('10 دروس'));
    expect(arL10n.lessonsCount(11), equals('11 درسًا'));
    expect(arL10n.lessonsCount(25), equals('25 درسًا'));
    expect(arL10n.lessonsCount(100), equals('100 درس'));
  });
}
