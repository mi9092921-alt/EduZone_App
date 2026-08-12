import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/home/domain/entities/resume_lesson.dart';
import 'package:app/features/home/presentation/widgets/resume_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  final tLesson = ResumeLesson(
    progressPct: 42,
    lastWatched: DateTime(2024),
    lessonId: 'l1',
    lessonTitle: 'Widgets 101',
    sectionTitle: 'Section 1',
    courseId: 'c1',
    courseTitle: 'Flutter Basics',
  );

  group('ResumeCard', () {
    testWidgets('renders nothing when there is no resume lesson and not loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ResumeCard()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResumeCard), findsOneWidget);
      // The widget renders an empty SizedBox — none of the lesson content exists.
      expect(find.text('Continue Learning'), findsNothing);
    });

    testWidgets('renders skeleton placeholder content while loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const ResumeCard(isLoading: true)),
      );
      // NOT pumpAndSettle(): AppSkeleton's shimmer animation (via the
      // skeletonizer package) repeats indefinitely while isLoading is
      // true, so there are always pending frames and pumpAndSettle would
      // time out waiting for animations that are never meant to stop.
      // A single pump() is enough to complete the initial build/layout.
      await tester.pump();

      // Loading state renders ResumeLesson.skeleton()'s placeholder copy.
      expect(find.text('Continue Learning'), findsOneWidget);
      expect(find.textContaining('Loading Lesson Title'), findsOneWidget);
      expect(find.textContaining('Loading Course Title'), findsOneWidget);
    });

    testWidgets('renders lesson title, course title, section label and progress',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestableWidget(ResumeCard(resumeLesson: tLesson)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue Learning'), findsOneWidget);
      expect(find.text('Widgets 101'), findsOneWidget);
      expect(find.text('Flutter Basics'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, closeTo(0.42, 0.0001));
    });

    testWidgets('clamps progress display to 100% when progressPct exceeds 100',
        (WidgetTester tester) async {
      final overshotLesson = tLesson.copyWith(progressPct: 137);

      await tester.pumpWidget(
        buildTestableWidget(ResumeCard(resumeLesson: overshotLesson)),
      );
      await tester.pumpAndSettle();

      final progressBar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressBar.value, 1.0);
      // Note: the displayed percentage label is not clamped in the widget
      // (only the progress bar value is), so it will still read "137%".
      expect(find.text('137%'), findsOneWidget);
    });
  });
}