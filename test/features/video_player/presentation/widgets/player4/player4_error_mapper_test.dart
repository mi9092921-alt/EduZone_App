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
  });
}
