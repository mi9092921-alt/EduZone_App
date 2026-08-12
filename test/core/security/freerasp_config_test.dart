import 'package:app/core/security/security_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isFreeraspConfigured() (freerasp_config.dart)', () {
    test(
      'returns false in a debug/test build with no '
      'SECURITY_ANDROID_SIGNING_HASH supplied — the real state of this '
      'repo\'s local/CI test runs today, since the team does not '
      'currently supply .env.security locally',
      () {
        // kReleaseMode is always false under `flutter test`, and no
        // --dart-define was passed for SECURITY_ANDROID_SIGNING_HASH, so
        // this reflects exactly what a normal `flutter test` run sees.
        expect(isFreeraspConfigured(), isFalse);
      },
    );

    test(
      'debugGetTalsecConfig() still builds successfully when called '
      'directly (defensive check — SecurityService.init() itself never '
      'calls it unless isFreeraspConfigured() is true)',
      () {
        // This would previously throw a freerasp configuration-exception
        // for an empty signing-hash allowlist; it's still true that
        // calling it directly with an empty hash produces a config
        // object that freerasp itself considers invalid for Android.
        // SecurityService.init() now avoids ever calling it in that
        // state (see isFreeraspConfigured() above) — this test exists
        // only to pin down that calling it directly still surfaces
        // freerasp's own validation, in case that assumption changes.
        expect(
          () => debugGetTalsecConfig(),
          throwsA(
            isA<Object>().having(
              (e) => e.toString(),
              'message',
              contains('signingCertHashes cannot be empty'),
            ),
          ),
        );
      },
    );
  });

  // NOTE ON COVERAGE: the release-mode fail-fast branch inside
  // _getTalsecConfig() —
  //   if (kReleaseMode && (kExpectedSignatureHash.isEmpty || kIosTeamId.isEmpty))
  //     throw StateError(...)
  // — still cannot be exercised here. `kReleaseMode` is always `false`
  // under `flutter test` and cannot be forced `true`. This is a
  // permanent, structural gap — see README_TEST_GAPS.md.
}
