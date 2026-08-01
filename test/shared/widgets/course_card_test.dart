import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/shared/components/course_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget(Widget child, {Locale locale = const Locale('en')}) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
  }

  group('DiscoverCourseCard', () {
    testWidgets('renders marketing details, lesson count and price in vertical mode', (WidgetTester tester) async {
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

      await tester.pumpWidget(buildTestableWidget(
        const SizedBox(
          width: 240,
          height: 280,
          child: DiscoverCourseCard(data: vm),
        ),
      ));
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

      await tester.pumpWidget(buildTestableWidget(
        const SizedBox(
          width: 240,
          height: 280,
          child: DiscoverCourseCard(data: vm),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('BEGINNER'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('6 lessons'), findsOneWidget);
      expect(find.text('\$49.99'), findsOneWidget);

      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
    });
  });

  group('MyCourseCard', () {
    testWidgets('renders title and progress in horizontal mode (English)', (WidgetTester tester) async {
      const vm = MyCourseVM(
        id: '3',
        title: 'UI Design 101',
        thumbnailUrl: '',
        totalLessons: 12,
        progress: 0.5,
      );

      await tester.pumpWidget(buildTestableWidget(
        const SizedBox(
          width: 380,
          child: MyCourseCard(data: vm, isHorizontal: true),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('UI Design 101'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('6/12 lessons'), findsOneWidget);
    });

    testWidgets('renders title and progress bar in horizontal mode (Arabic)', (WidgetTester tester) async {
      const vm = MyCourseVM(
        id: '3',
        title: 'تصميم واجهات المستخدم',
        thumbnailUrl: '',
        totalLessons: 5,
        progress: 0.6,
      );

      await tester.pumpWidget(buildTestableWidget(
        const SizedBox(
          width: 380,
          child: MyCourseCard(data: vm, isHorizontal: true),
        ),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تصميم واجهات المستخدم'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
    });
  });

  group('RecentCourseCard', () {
    testWidgets('renders title and progress in vertical mode (English)', (WidgetTester tester) async {
      const vm = RecentCourseVM(
        id: '4',
        title: 'Advanced Git',
        thumbnailUrl: '',
        totalLessons: 10,
        progress: 0.3,
      );

      await tester.pumpWidget(buildTestableWidget(
        const SizedBox(
          width: 240,
          height: 240,
          child: RecentCourseCard(data: vm),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Advanced Git'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('3/10 lessons'), findsOneWidget);
    });

    testWidgets('renders title and progress in vertical mode (Arabic)', (WidgetTester tester) async {
      const vm = RecentCourseVM(
        id: '4',
        title: 'جيت المتقدم',
        thumbnailUrl: '',
        totalLessons: 20,
        progress: 0.5,
      );

      await tester.pumpWidget(buildTestableWidget(
        const SizedBox(
          width: 240,
          height: 240,
          child: RecentCourseCard(data: vm),
        ),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('جيت المتقدم'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });
  });
}
