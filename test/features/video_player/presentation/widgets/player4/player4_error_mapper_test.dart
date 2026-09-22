import 'package:app/core/error/exceptions.dart';
import 'package:app/features/video_player/presentation/widgets/player4/player4_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'player4_test_helpers.dart';

void main() {
  group('mapPlayer4ErrorToMessage', () {
    testWidgets('maps network-related exceptions to the internet-connection message', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        expect(
          mapPlayer4ErrorToMessage(l10n, Exception('SocketException: failed')),
          l10n.checkInternetConnection,
        );
        expect(
          mapPlayer4ErrorToMessage(l10n, Exception('Failed host lookup')),
          l10n.checkInternetConnection,
        );
      });
    });

    testWidgets('maps parse-related exceptions to the parse-error message', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        expect(
          mapPlayer4ErrorToMessage(l10n, const FormatException('bad json')),
          l10n.videoParseError,
        );
        expect(
          mapPlayer4ErrorToMessage(
            l10n,
            Exception('Invalid video-info response format'),
          ),
          l10n.videoParseError,
        );
      });
    });

    testWidgets('falls back to the generic server-error message', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        expect(
          mapPlayer4ErrorToMessage(l10n, Exception('something unexpected')),
          l10n.serverError,
        );
      });
    });

    testWidgets(
      'maps authorization denials to the access-denied message, not the '
      'generic server error',
      (WidgetTester tester) async {
        await withLocalizations(tester, (l10n) {
          expect(
            mapPlayer4ErrorToMessage(
              l10n,
              Exception('Edge Function error 403: Access denied'),
            ),
            l10n.videoAccessDenied,
          );
          expect(
            mapPlayer4ErrorToMessage(l10n, Exception('Unauthorized')),
            l10n.videoAccessDenied,
          );
          expect(
            mapPlayer4ErrorToMessage(
              l10n,
              Exception('Edge Function error 404: Lesson not found'),
            ),
            l10n.videoAccessDenied,
          );
          expect(
            mapPlayer4ErrorToMessage(
              l10n,
              const ServerException('ACCESS_DENIED', 'P0001'),
            ),
            l10n.videoAccessDenied,
          );
        });
      },
    );

    testWidgets('never mistakes a network fault for an auth denial', (
      WidgetTester tester,
    ) async {
      await withLocalizations(tester, (l10n) {
        // A transient playback/network error must stay a connectivity
        // message even when the backend words it with a status code.
        expect(
          mapPlayer4ErrorToMessage(
            l10n,
            Exception('SocketException: failed host lookup'),
          ),
          l10n.checkInternetConnection,
        );
      });
    });
  });
}
