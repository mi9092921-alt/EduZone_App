import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Harness-verification smoke test.
///
/// This is deliberately NOT a real end-to-end app-boot test. A real one
/// would need to exercise `main.dart`'s actual startup path — Sentry init,
/// `AppInitializer.init()` (Supabase, secure storage, device fingerprint,
/// etc.) — which requires either a configured `.env`/`.env.staging` with
/// real backend credentials, or a substantial mocking setup for platform
/// channels that don't exist in a plain `flutter test` environment. That
/// work needs a maintainer with the Flutter SDK, an emulator/simulator or
/// real device, and the project's actual secrets available to write and
/// verify — none of which were available in the environment this scaffold
/// was created in, so it is intentionally not attempted here (shipping an
/// integration test nobody has run and that touches real backend
/// bootstrap would be worse than not having one).
///
/// What this file DOES verify, and does so honestly:
/// - `integration_test` is wired up correctly in `pubspec.yaml` and CI can
///   discover and execute tests under this directory end-to-end.
/// - `IntegrationTestWidgetsFlutterBinding` initializes without error,
///   which is the actual prerequisite every real integration test in this
///   directory will build on top of.
///


// TODO (tracked, not yet done — see §16 in the project instructions for
/// the full required list): once a maintainer can run this against a real
/// or mocked backend, add real integration tests here for at minimum:
///   - application startup → first frame
///   - login → home
///   - session restoration on a warm relaunch
///   - logout clears protected routes / navigation guard redirect
///   - course list load → course detail
///   - download flow (start → progress → complete)
///   - offline playback of a completed download
///   - RTL/LTR + accessibility smoke pass on at least one critical screen
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Integration test harness', () {
    testWidgets('binding initializes and can pump a widget', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('harness-ok'))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('harness-ok'), findsOneWidget);
    });
  });
}
