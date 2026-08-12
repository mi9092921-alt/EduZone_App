import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/courses/domain/entities/lesson.dart';
import 'package:app/features/video_player/presentation/screens/video_player/video_lesson_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lesson = Lesson(
    id: 'l1',
    sectionId: 's1',
    title: 'Intro to Widgets',
  );

  Widget buildTestable(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('shows the lesson title in the app bar', (tester) async {
    await tester.pumpWidget(
      buildTestable(const VideoLessonPaywall(lesson: lesson)),
    );

    expect(find.text('Intro to Widgets'), findsOneWidget);
  });

  testWidgets('shows a lock icon and an enrollment CTA button', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestable(const VideoLessonPaywall(lesson: lesson)),
    );

    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('renders without throwing across a rebuild with a different lesson', (
    tester,
  ) async {
    const otherLesson = Lesson(id: 'l2', sectionId: 's1', title: 'Layouts');

    await tester.pumpWidget(
      buildTestable(const VideoLessonPaywall(lesson: lesson)),
    );
    expect(find.text('Intro to Widgets'), findsOneWidget);

    await tester.pumpWidget(
      buildTestable(const VideoLessonPaywall(lesson: otherLesson)),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Layouts'), findsOneWidget);
    expect(find.text('Intro to Widgets'), findsNothing);
  });
}
