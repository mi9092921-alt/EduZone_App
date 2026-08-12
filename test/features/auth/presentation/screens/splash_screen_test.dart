import 'package:app/features/auth/presentation/screens/splash/animated_brand_name.dart';
import 'package:app/features/auth/presentation/screens/splash/animated_logo.dart';
import 'package:app/features/auth/presentation/screens/splash/gradient_background.dart';
import 'package:app/features/auth/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Regression coverage for the file split of splash_screen.dart into
// screens/splash/{gradient_background, animated_logo, animated_brand_name,
// splash_brand_metrics, splash_constants}.dart — this test only asserts the
// wiring holds together after the split (each sub-widget still renders, no
// missing constants/measurements), not the pixel-level animation output.
void main() {
  Future<void> pumpSplash(WidgetTester tester, {Brightness? brightness}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? ThemeData.dark()
            : ThemeData.light(),
        home: const SplashScreen(),
      ),
    );
  }

  testWidgets('renders the gradient background, logo, and brand name', (
    tester,
  ) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SplashGradientBackground), findsOneWidget);
    expect(find.byType(SplashAnimatedLogo), findsOneWidget);
    expect(find.byType(SplashAnimatedBrandName), findsOneWidget);
  });

  testWidgets('exposes semantics labels for the logo and brand name', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.bySemanticsLabel('EduZone logo'), findsOneWidget);
    expect(find.bySemanticsLabel('EduZone'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('renders "Edu" and "Zone" literal text', (tester) async {
    await pumpSplash(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Edu'), findsOneWidget);
    expect(find.text('Zone'), findsOneWidget);
  });

  testWidgets('does not throw across the full animation lifecycle', (
    tester,
  ) async {
    await pumpSplash(tester);
    // Advance well past the 1200ms main animation duration; the repeating
    // pulse controller keeps going on purpose (see splash_screen.dart doc
    // comment) so we pump a bounded number of frames rather than
    // pumpAndSettle (which would never settle).
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders correctly in dark mode', (tester) async {
    await pumpSplash(tester, brightness: Brightness.dark);
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    expect(find.byType(SplashGradientBackground), findsOneWidget);
  });
}
