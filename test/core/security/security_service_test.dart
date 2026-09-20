import 'package:app/core/security/security_service.dart';
import 'package:app/core/security/threat_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─────────────────────────────────────────────────────────────────────────
// KNOWN COVERAGE GAP (documented, not silently skipped — see also
// test/core/security/README_TEST_GAPS.md):
//
// `SecurityService.init()` calls `Talsec.instance.start(...)` directly
// with no injectable abstraction around it, so the actual freeRASP
// threat-detection callbacks can never be invoked from a unit test.
// The freeRASP callbacks themselves are therefore still untested here.
// The dispatch behind them (`_onThreatDetected` → policy → telemetry / kill
// handler) IS covered below through `reportThreatForTest`, an injected
// incident sender and an injected kill handler.
//
// Additionally, after the three fixes below, none of init()'s three
// startup steps naturally fail in a clean local/CI test environment
// anymore (that was the point of fixing them) — which means
// `_logThreatToSupabase()`'s AssertionError-catch fix (see #1) has no
// natural trigger left in this test file to exercise directly. That is
// an acceptable, expected outcome for error-handling code: it should
// only run on genuine unexpected failures, and forcing one artificially
// here would test a scenario that no longer reflects reality.
// ─────────────────────────────────────────────────────────────────────────
//
// THREE BUGS FIXED (were discovered while first writing this test suite;
// fixed after explicit approval — team confirmed .env.security is not
// supplied locally, which is what made #3 a real, everyday issue rather
// than a theoretical one):
//
// 1. `_logThreatToSupabase()` now catches both `StateError` AND
//    `AssertionError` — `Supabase.instance` actually throws the latter
//    before initialization, so the specific `'supabase_not_ready'`
//    status is reachable now (previously dead code; fell through to the
//    generic `'unknown_error'` branch).
//
// 2. `LifecycleGuard.didChangeAppLifecycleState()` now `await`s its
//    ScreenProtector calls inside the try/catch, so native failures are
//    actually caught instead of leaking as unhandled async errors. See
//    guards/lifecycle_guard_test.dart.
//
// 3. `SecurityService.init()` now skips the freeRASP startup step
//    cleanly (one informational debugPrint, not a threat-buffer entry)
//    whenever SECURITY_ANDROID_SIGNING_HASH is empty in a non-release
//    build — via the new `isFreeraspConfigured()` check in
//    freerasp_config.dart — instead of running it and letting freerasp's
//    own AndroidConfig constructor throw a confusing
//    "configuration-exception: signingCertHashes cannot be empty".
//    Release-build behavior (fail fast if genuinely misconfigured) is
//    unchanged. See freerasp_config_test.dart.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecurityService.init()', () {
    // NOTE: `SecurityService` uses static singleton state (`_initialized`)
    // that persists for the lifetime of this test file's VM. Only the
    // FIRST test that calls init() observes the "fresh" startup path.

    test(
      'completes cleanly with an EMPTY threat buffer in a normal '
      'local/CI test environment — no false-positive startup failures '
      '(this is the corrected behavior; see the three fixes documented '
      'above)',
      () async {
        await expectLater(SecurityService.init(), completes);

        expect(
          SecurityService.unsyncedThreatBuffer,
          isEmpty,
          reason:
              'All three startup steps should now either succeed or skip '
              'cleanly with no signing hash configured: screenshot '
              'protection catches its own native-plugin failure '
              'internally, the screen-share scan no-ops on a non-Android '
              'host, and freeRASP is skipped outright via '
              'isFreeraspConfigured() rather than failing.',
        );
      },
    );

    test(
      'is idempotent — a second call short-circuits and does not change '
      'the (empty) threat buffer',
      () async {
        final before = SecurityService.unsyncedThreatBuffer.length;
        await expectLater(SecurityService.init(), completes);
        expect(SecurityService.unsyncedThreatBuffer.length, before);
      },
    );
  });

  group('SecurityService.unsyncedThreatBuffer', () {
    test('is exposed as an unmodifiable view', () {
      expect(
        () => SecurityService.unsyncedThreatBuffer.add(const {}),
        throwsUnsupportedError,
      );
    });
  });

  group('SecurityService.killAppHandler', () {
    test('can be set and invoked without throwing', () {
      String? handledReason;
      SecurityService.killAppHandler = (reason) {
        handledReason = reason;
      };

      expect(SecurityService.killAppHandler, isNotNull);
      SecurityService.killAppHandler!('Test threat');
      expect(handledReason, equals('Test threat'));

      // Clean up after test
      SecurityService.killAppHandler = null;
    });
  });
  group('SecurityService threat dispatch and telemetry', () {
    late List<Map<String, dynamic>> sent;
    late List<String> killed;

    setUp(() {
      SecurityService.resetTelemetryStateForTest();
      sent = [];
      killed = [];
      SecurityService.incidentSenderForTest = (payload) async {
        sent.add(payload);
      };
      SecurityService.killAppHandler = killed.add;
      PackageInfo.setMockInitialValues(
        appName: 'EduZone',
        packageName: 'com.eduzone.learn.app',
        version: '1.2.0',
        buildNumber: '42',
        buildSignature: '',
        installerStore: 'com.google.android.packageinstaller',
      );
    });

    tearDown(() {
      SecurityService.resetTelemetryStateForTest();
      SecurityService.killAppHandler = null;
    });

    test('the same threat reported repeatedly in one session is sent once',
        () async {
      await SecurityService.reportThreatForTest(SecurityThreat.debugger);
      await SecurityService.reportThreatForTest(SecurityThreat.debugger);
      await SecurityService.reportThreatForTest(SecurityThreat.debugger);

      expect(sent, hasLength(1));
      expect(sent.single['threat'], 'Debugger Detected');
    });

    test('concurrent duplicates are also collapsed to one insert', () async {
      await Future.wait([
        SecurityService.reportThreatForTest(SecurityThreat.obfuscation),
        SecurityService.reportThreatForTest(SecurityThreat.obfuscation),
        SecurityService.reportThreatForTest(SecurityThreat.obfuscation),
      ]);

      expect(sent, hasLength(1));
    });

    test('distinct threats and distinct packages are each sent once', () async {
      await SecurityService.reportThreatForTest(SecurityThreat.debugger);
      await SecurityService.reportThreatForTest(SecurityThreat.obfuscation);
      await SecurityService.reportThreatForTest(
        SecurityThreat.screenShareApp,
        subject: 'com.discord',
      );
      await SecurityService.reportThreatForTest(
        SecurityThreat.screenShareApp,
        subject: 'us.zoom.videomeetings',
      );

      expect(
        sent.map((p) => p['threat']),
        equals([
          'Debugger Detected',
          'Obfuscation Issues',
          'Screen Share App Installed: com.discord',
          'Screen Share App Installed: us.zoom.videomeetings',
        ]),
      );
    });

    test(
      'a failed delivery is buffered locally and a later occurrence in the '
      'same session retries',
      () async {
        SecurityService.incidentSenderForTest = (payload) async {
          throw Exception('offline');
        };
        await SecurityService.reportThreatForTest(SecurityThreat.debugger);

        expect(sent, isEmpty);
        expect(SecurityService.unsyncedThreatBuffer, hasLength(1));
        expect(
          SecurityService.unsyncedThreatBuffer.single['log_status'],
          'insert_failed',
        );

        SecurityService.incidentSenderForTest = (payload) async {
          sent.add(payload);
        };
        await SecurityService.reportThreatForTest(SecurityThreat.debugger);

        expect(sent, hasLength(1));
      },
    );

    test(
      'details carry policy, enforcement, action taken, detection source and '
      'installer — and nothing else (no PII)',
      () async {
        SecurityService.enforceOverrideForTest = true;

        await SecurityService.reportThreatForTest(
          SecurityThreat.hooks,
          source: 'freerasp',
        );

        final payload = sent.single;
        expect(payload['app_version'], '1.2.0');
        expect(payload['app_build_number'], '42');
        final details = payload['details'] as Map<String, dynamic>;
        expect(details['detection_source'], 'freerasp');
        expect(details['policy'], 'terminate');
        expect(details['enforced'], isTrue);
        expect(details['action_taken'], 'terminated');
        expect(details['installer'], 'com.google.android.packageinstaller');
        expect(
          details.keys.toSet(),
          equals({
            'detection_source',
            'policy',
            'enforced',
            'action_taken',
            'installer',
          }),
        );
      },
    );

    test('unofficial-store details record whether sideload was allowed',
        () async {
      SecurityService.allowSideloadOverrideForTest = true;
      await SecurityService.reportThreatForTest(SecurityThreat.unofficialStore);

      final details = sent.single['details'] as Map<String, dynamic>;
      expect(details['sideload_allowed'], isTrue);
      expect(details['policy'], 'telemetry_only');
    });

    group('termination (enforcement ON)', () {
      setUp(() {
        SecurityService.enforceOverrideForTest = true;
        // Pin strict mode so these tests do not depend on whether the
        // developer ran `flutter test` with a SECURITY_ALLOW_SIDELOAD define.
        SecurityService.allowSideloadOverrideForTest = false;
      });

      for (final threat in [
        SecurityThreat.appIntegrity,
        SecurityThreat.hooks,
        SecurityThreat.privilegedAccess,
      ]) {
        for (final allowSideload in [false, true]) {
          test(
            '${threat.name} terminates (allowSideload=$allowSideload)',
            () async {
              SecurityService.allowSideloadOverrideForTest = allowSideload;

              await SecurityService.reportThreatForTest(threat);

              expect(killed, equals([threat.label]));
            },
          );
        }
      }

      for (final threat in [
        SecurityThreat.debugger,
        SecurityThreat.simulator,
        SecurityThreat.passcode,
        SecurityThreat.secureHardware,
        SecurityThreat.deviceBinding,
        SecurityThreat.deviceId,
        SecurityThreat.obfuscation,
      ]) {
        test('${threat.name} is telemetry-only: reported, never terminates',
            () async {
          await SecurityService.reportThreatForTest(threat);

          expect(killed, isEmpty);
          expect(sent, hasLength(1));
          final details = sent.single['details'] as Map<String, dynamic>;
          expect(details['action_taken'], 'reported_only');
        });
      }

      test('a screen-share app never terminates', () async {
        await SecurityService.reportThreatForTest(
          SecurityThreat.screenShareApp,
          subject: 'com.discord',
        );

        expect(killed, isEmpty);
        expect(sent, hasLength(1));
      });

      test('unofficial store terminates when strict (the default)', () async {
        await SecurityService.reportThreatForTest(
          SecurityThreat.unofficialStore,
        );

        expect(killed, equals(['Installed from Unofficial Store']));
      });

      test(
        'unofficial store is telemetry-only with SECURITY_ALLOW_SIDELOAD=true '
        '(direct-APK distribution)',
        () async {
          SecurityService.allowSideloadOverrideForTest = true;

          await SecurityService.reportThreatForTest(
            SecurityThreat.unofficialStore,
          );

          expect(killed, isEmpty);
          expect(sent, hasLength(1));
        },
      );
    });

    test('enforcement OFF never terminates, even for a terminate-policy threat',
        () async {
      SecurityService.enforceOverrideForTest = false;

      await SecurityService.reportThreatForTest(SecurityThreat.hooks);

      expect(killed, isEmpty);
      final details = sent.single['details'] as Map<String, dynamic>;
      expect(details['policy'], 'terminate');
      expect(details['enforced'], isFalse);
      expect(details['action_taken'], 'reported_only');
    });
  });
}
