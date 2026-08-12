import 'package:app/design_system/components/status/app_skeleton.dart';
import 'package:app/design_system/tokens/app_colors.dart';
import 'package:app/design_system/tokens/app_radius.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSkeleton', () {
    test('the default (box) constructor sets isSliver to false', () {
      const skeleton = AppSkeleton(child: SizedBox.shrink());
      expect(skeleton.isSliver, isFalse);
    });

    test('the .sliver named constructor sets isSliver to true', () {
      const skeleton = AppSkeleton.sliver(child: SizedBox.shrink());
      expect(skeleton.isSliver, isTrue);
    });

    testWidgets('shows the real child content once disabled (enabled: false)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSkeleton(enabled: false, child: Text('Real content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Real content'), findsOneWidget);
    });

    testWidgets('does not throw while actively skeletonizing (enabled: true)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            // `enabled` defaults to true -- left implicit here.
            body: AppSkeleton(child: Text('Loading course title...')),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('isolates non-sliver shimmer repaint work', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSkeleton(child: Text('Loading course title...')),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(AppSkeleton),
          matching: find.byType(RepaintBoundary),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('the .sliver variant works inside a CustomScrollView', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                // `enabled` defaults to true -- left implicit here.
                AppSkeleton.sliver(
                  child: SliverToBoxAdapter(
                    child: Text('Sliver skeleton content'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('AppSkeletonTile', () {
    testWidgets('defaults to a 16px-tall, auto-width bone', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: AppSkeletonTile())),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(AppSkeletonTile));
      expect(size.height, 16);
    });

    testWidgets('honors an explicit width and height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: AppSkeletonTile(height: 24, width: 120)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(AppSkeletonTile));
      expect(size.height, 24);
      expect(size.width, 120);
    });

    testWidgets('uses AppRadius.sm as its default corner radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: AppSkeletonTile())),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppSkeletonTile),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(AppRadius.sm));
    });

    testWidgets('fills with the surface2 token color from AppColors', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: AppSkeletonTile())),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(AppSkeletonTile),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      // No ThemeExtension registered -> AppColors.of falls back to dark().
      expect(decoration.color, DesignSystemColors.dark().surface2);
    });
  });

  group('AppSkeletonData', () {
    test('exposes non-empty placeholder strings', () {
      expect(AppSkeletonData.dummyTitle, isNotEmpty);
      expect(AppSkeletonData.dummyShortText, isNotEmpty);
      expect(AppSkeletonData.dummyLongText, isNotEmpty);
      expect(AppSkeletonData.dummyCategory, isNotEmpty);
    });

    test('dummyLongText is meaningfully longer than dummyShortText', () {
      expect(
        AppSkeletonData.dummyLongText.length,
        greaterThan(AppSkeletonData.dummyShortText.length),
      );
    });
  });
}
