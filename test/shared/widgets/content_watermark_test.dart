import 'package:app/shared/widgets/content_watermark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('watermarkFragmentForUserId', () {
    test('returns the last 4 characters uppercased', () {
      expect(
        watermarkFragmentForUserId('8a4b7e86-ca9f-4001-8f90-817723328b0c'),
        '8B0C',
      );
    });

    test('returns empty for null (caller renders nothing)', () {
      expect(watermarkFragmentForUserId(null), '');
    });

    test('returns empty for ids shorter than 4 chars (hide, never guess)', () {
      expect(watermarkFragmentForUserId(''), '');
      expect(watermarkFragmentForUserId('abc'), '');
    });

    test('never returns more than 4 characters', () {
      final fragment = watermarkFragmentForUserId('user-with-long-id-12345');
      expect(fragment.length, lessThanOrEqualTo(4));
    });
  });

  group('ContentWatermark', () {
    testWidgets('renders the fragment text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ContentWatermark(watermarkText: '8B0C')),
        ),
      );

      expect(find.text('8B0C'), findsOneWidget);
    });

    testWidgets('renders nothing when the fragment is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ContentWatermark(watermarkText: '')),
        ),
      );

      expect(find.byType(Text), findsNothing);
      // No IgnorePointer may come from the watermark itself (Scaffold and
      // friends inject their own elsewhere in the tree, so scope the
      // search to the watermark subtree).
      expect(
        find.descendant(
          of: find.byType(ContentWatermark),
          matching: find.byType(IgnorePointer),
        ),
        findsNothing,
      );
    });

    testWidgets('is rooted in IgnorePointer so it can never eat taps', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ContentWatermark(watermarkText: '8B0C')),
        ),
      );

      final ignorePointer = tester.widget<IgnorePointer>(
        find.descendant(
          of: find.byType(ContentWatermark),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointer.ignoring, isTrue);
    });

    testWidgets('taps pass through the watermark to controls below', (
      tester,
    ) async {
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.expand(
              child: Stack(
                children: [
                  // Stand-in for a player control filling the video area:
                  // any tap landing on it must still arrive even with the
                  // watermark painted on top.
                  Positioned.fill(
                    child: TextButton(
                      onPressed: () => pressed = true,
                      child: const Text('control'),
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    right: 12,
                    child: ContentWatermark(watermarkText: '8B0C'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(
        tester.getCenter(find.byType(ContentWatermark)),
      );
      await tester.pump();

      expect(pressed, isTrue);
    });
  });
}
