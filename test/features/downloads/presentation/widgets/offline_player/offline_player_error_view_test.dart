import 'package:app/core/l10n/arb/app_localizations.dart';
import 'package:app/features/downloads/application/services/offline_policy_engine.dart';
import 'package:app/features/downloads/presentation/widgets/offline_player/offline_player_error_view.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'offline_player_test_helpers.dart';

void main() {
  group('OfflinePlayerErrorView', () {
    testWidgets('shows an error icon and a retry button that fires onRetry', (
      WidgetTester tester,
    ) async {
      var retried = false;

      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerErrorView(
            aspectRatio: 16 / 9,
            errorMessage: 'Some failure',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);

      await tester.tap(find.byType(TextButton));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('shows the raw error message only in debug builds', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerErrorView(
            aspectRatio: 16 / 9,
            errorMessage: 'Decryption failed: bad tag',
            onRetry: () {},
          ),
        ),
      );

      // `flutter test` always runs in debug mode, so kDebugMode is true
      // here — this assertion documents that assumption rather than
      // hardcoding it, so the test fails loudly instead of silently if
      // that ever stops being true.
      expect(kDebugMode, isTrue);
      expect(find.text('Decryption failed: bad tag'), findsOneWidget);
    });

    testWidgets('does not throw when errorMessage is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          OfflinePlayerErrorView(
            aspectRatio: 16 / 9,
            errorMessage: null,
            onRetry: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets(
      'renders localized English denial copy for a denial reason',
      (WidgetTester tester) async {
        // Regression: denial wording used to be hardcoded English on the
        // exception (OfflinePlaybackDeniedException.userMessage), which
        // surfaced English copy to ar-EG users. The reason enum is now
        // resolved to ARB-sourced copy at render time.
        await tester.pumpWidget(
          buildTestableWidget(
            OfflinePlayerErrorView(
              aspectRatio: 16 / 9,
              denialReason: OfflinePlaybackDenialReason.expired,
              errorMessage: null,
              onRetry: () {},
            ),
          ),
        );

        expect(
          find.text(
            'This offline download has expired. Reconnect and download '
            'it again.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders Arabic denial copy under the ar-EG locale',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestableWidget(
            OfflinePlayerErrorView(
              aspectRatio: 16 / 9,
              denialReason: OfflinePlaybackDenialReason.tampered,
              errorMessage: null,
              onRetry: () {},
            ),
            locale: const Locale('ar', 'EG'),
          ),
        );

        expect(
          find.text('تعذّر التحقق من هذا التنزيل، ويجب تنزيله مرة أخرى.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'every denial reason maps to a localized message',
      (WidgetTester tester) async {
        // Guards against a reason being added to the enum without an ARB
        // entry: offlineDenialMessage throws on a missing switch case only
        // if the analyzer misses it — exhaustiveness is compile-time, but
        // an ARB key can still be forgotten, so render each reason.
        for (final reason in OfflinePlaybackDenialReason.values) {
          await tester.pumpWidget(
            buildTestableWidget(
              OfflinePlayerErrorView(
                aspectRatio: 16 / 9,
                denialReason: reason,
                errorMessage: null,
                onRetry: () {},
              ),
            ),
          );
          await tester.pump();

          final l10n = AppLocalizations.of(
            tester.element(find.byType(OfflinePlayerErrorView)),
          )!;
          expect(
            find.text(offlineDenialMessage(l10n, reason)),
            findsOneWidget,
            reason: 'missing localized copy for ${reason.name}',
          );
        }
      },
    );
  });
}
