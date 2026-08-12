import 'package:app/shared/components/course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'course_card_test_helpers.dart';

void main() {
  group('MyCourseCard', () {
    testWidgets('renders title and progress in horizontal mode (English)', (
      WidgetTester tester,
    ) async {
      const vm = MyCourseVM(
        id: '3',
        title: 'UI Design 101',
        thumbnailUrl: '',
        totalLessons: 12,
        progress: 0.5,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const SizedBox(
            width: 380,
            child: MyCourseCard(data: vm, isHorizontal: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UI Design 101'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('6/12 lessons'), findsOneWidget);
    });

    testWidgets('renders title and progress bar in horizontal mode (Arabic)', (
      WidgetTester tester,
    ) async {
      const vm = MyCourseVM(
        id: '3',
        title: 'تصميم واجهات المستخدم',
        thumbnailUrl: '',
        totalLessons: 5,
        progress: 0.6,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const SizedBox(
            width: 380,
            child: MyCourseCard(data: vm, isHorizontal: true),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تصميم واجهات المستخدم'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });
  });
}
