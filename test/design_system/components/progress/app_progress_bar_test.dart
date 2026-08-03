import 'package:app/design_system/components/progress/app_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders without a label by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppProgressBar(progress: 0.5)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('shows the rounded percentage label when showLabel is true',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppProgressBar(progress: 0.42, showLabel: true),
        ),
      ),
    );
    // Let the fill animation (AppMotion.slow) finish so the label reflects
    // the final target value rather than an in-flight tween frame.
    await tester.pumpAndSettle();

    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('shows the optional custom label text alongside the percentage',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppProgressBar(
            progress: 0.3,
            showLabel: true,
            labelText: '3/10 lessons',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3/10 lessons'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
  });

  testWidgets(
    'the % label reflects the new progress immediately on update, while '
    'the visual fill only catches up once the tween finishes (the label '
    'is bound directly to widget.progress, not the animated value)',
    (tester) async {
      Widget build(double progress) => MaterialApp(
            home: Scaffold(
              body: AppProgressBar(
                progress: progress,
                showLabel: true,
              ),
            ),
          );

      double fractionOf(WidgetTester t) => t
          .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
          .widthFactor!;

      await tester.pumpWidget(build(0.2));
      await tester.pumpAndSettle();
      expect(find.text('20%'), findsOneWidget);
      expect(fractionOf(tester), closeTo(0.2, 0.001));

      await tester.pumpWidget(build(0.8));
      await tester.pump(); // one frame in -- tween has barely started
      // Label already reflects the target value...
      expect(find.text('80%'), findsOneWidget);
      // ...but the fill bar is still animating up from 0.2, not yet at 0.8.
      expect(fractionOf(tester), lessThan(0.8));

      await tester.pumpAndSettle();
      expect(find.text('80%'), findsOneWidget);
      expect(fractionOf(tester), closeTo(0.8, 0.001));
    },
  );

  testWidgets('clamps a completed (>=1.0) progress to a 100% label',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppProgressBar(progress: 1.0, showLabel: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('does not throw for out-of-range progress values',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppProgressBar(progress: 1.5)),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
