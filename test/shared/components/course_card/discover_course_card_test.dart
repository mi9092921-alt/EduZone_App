import 'package:app/shared/components/course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'course_card_test_helpers.dart';

void main() {
  group('DiscoverCourseCard', () {
    testWidgets('renders marketing details, lesson count and price in vertical mode', (
      WidgetTester tester,
    ) async {
      const vm = DiscoverCourseVM(
        id: '1',
        title: 'Flutter Advanced',
        thumbnailUrl: '',
        level: 'ADVANCED',
        instructorName: 'John Doe',
        category: 'Development',
        totalLessons: 12,
        durationMinutes: 90,
        studentsCount: 1500,
        rating: 4.8,
        ratingCount: 42,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const SizedBox(
            width: 240,
            height: 280,
            child: DiscoverCourseCard(data: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flutter Advanced'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('ADVANCED'), findsOneWidget);
      expect(find.text('12 lessons'), findsOneWidget);
      expect(find.text('1h 30m'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('4.8'), findsOneWidget);
    });

    testWidgets('hides rating and duration when not available', (WidgetTester tester) async {
      const vm = DiscoverCourseVM(
        id: '2',
        title: 'Flutter Basics',
        thumbnailUrl: '',
        level: 'BEGINNER',
        instructorName: 'John Doe',
        category: 'Development',
        totalLessons: 6,
        durationMinutes: 0,
        studentsCount: 0,
        rating: 0.0,
        isFree: false,
        price: 49.99,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const SizedBox(
            width: 240,
            height: 280,
            child: DiscoverCourseCard(data: vm),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('BEGINNER'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('6 lessons'), findsOneWidget);
      expect(find.text('\$49.99'), findsOneWidget);

      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });
  });
}
