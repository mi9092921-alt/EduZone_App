import 'package:app/shared/components/course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'course_card_test_helpers.dart';

void main() {
  group('RecentCourseCard', () {
    testWidgets('renders title and progress in vertical mode (English)', (
      WidgetTester tester,
    ) async {
      const vm = RecentCourseVM(
        id: '4',
        title: 'Advanced Git',
        thumbnailUrl: '',
        totalLessons: 10,
        progress: 0.3,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const SizedBox(
            width: 240,
            height: 240,
            child: RecentCourseCard(data: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Advanced Git'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('3/10 lessons'), findsOneWidget);
    });

    testWidgets('renders title and progress in vertical mode (Arabic)', (
      WidgetTester tester,
    ) async {
      const vm = RecentCourseVM(
        id: '4',
        title: 'جيت المتقدم',
        thumbnailUrl: '',
        totalLessons: 20,
        progress: 0.5,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const SizedBox(
            width: 240,
            height: 240,
            child: RecentCourseCard(data: vm),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('جيت المتقدم'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });
  });
}
