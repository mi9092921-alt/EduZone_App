import 'package:app/core/security/security_service.dart';
import 'package:app/core/security/threat_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─────────────────────────────────────────────────────────────────────────
// ScreenShareGuard reports which blacklisted screen-share / remote-control
// packages are INSTALLED. It is telemetry-only: it must never terminate the
// app, whatever the enforcement setting.
//
// `check()` takes an injectable package query and platform flag, so the
// matching and reporting logic is reachable from `flutter test` (the former
// "blacklist branch unreachable off-Android" gap is closed). What is still NOT
// covered here, and needs a real Android device: the real `InstalledApps`
// query itself, and Android 11+ package-visibility behaviour.
// ─────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenShareGuard.check() on a non-Android host', () {
    test(
      'returns immediately without throwing (default platform check)',
      () async {
        await expectLater(ScreenShareGuard.check(), completes);
      },
    );

    test('can be called multiple times without throwing', () async {
      await expectLater(ScreenShareGuard.check(), completes);
      await expectLater(ScreenShareGuard.check(), completes);
    });
  });

  group('ScreenShareGuard.matchBlacklisted()', () {
    test('exact package names match, in blacklist order', () {
      expect(
        ScreenShareGuard.matchBlacklisted([
          'com.discord',
          'com.example.other',
          'us.zoom.videomeetings',
        ]),
        equals(['us.zoom.videomeetings', 'com.discord']),
      );
    });

    test('lookalike and substring package names do NOT match', () {
      expect(
        ScreenShareGuard.matchBlacklisted([
          'com.discord.fake',
          'xcom.discord',
          'com.discord2',
          'discord',
        ]),
        isEmpty,
      );
    });

    test('duplicates in the input yield a single match', () {
      expect(
        ScreenShareGuard.matchBlacklisted(['com.discord', 'com.discord']),
        equals(['com.discord']),
      );
    });

    test('nothing installed matches nothing', () {
      expect(ScreenShareGuard.matchBlacklisted(const []), isEmpty);
    });
  });

  group('ScreenShareGuard.check() with an injected package query', () {
    late List<Map<String, dynamic>> sent;
    late List<String> killed;

    void arm() {
      SecurityService.resetTelemetryStateForTest();
      sent = [];
      killed = [];
      SecurityService.incidentSenderForTest = (payload) async {
        sent.add(payload);
      };
      SecurityService.killAppHandler = killed.add;
    }

    setUp(() {
      PackageInfo.setMockInitialValues(
        appName: 'EduZone',
        packageName: 'com.eduzone.learn.app',
        version: '1.2.0',
        buildNumber: '7',
        buildSignature: '',
      );
      arm();
    });

    tearDown(() {
      SecurityService.resetTelemetryStateForTest();
      SecurityService.killAppHandler = null;
    });

    test(
      'installed blacklisted apps are reported as telemetry-only and NEVER '
      'terminate — even with enforcement on',
      () async {
        SecurityService.enforceOverrideForTest = true;

        await ScreenShareGuard.check(
          isAndroid: true,
          query: () async => ['com.discord', 'us.zoom.videomeetings'],
        );

        expect(
          sent.map((p) => p['threat']),
          equals([
            'Screen Share App Installed: us.zoom.videomeetings',
            'Screen Share App Installed: com.discord',
          ]),
        );
        expect(killed, isEmpty, reason: 'a blacklist hit must never kill');
        for (final payload in sent) {
          final details = payload['details'] as Map<String, dynamic>;
          expect(details['detection_source'], 'installed_package_query');
          expect(details['policy'], 'telemetry_only');
          expect(details['action_taken'], 'reported_only');
          expect(details['enforced'], isTrue);
        }
      },
    );

    test(
      'an app that is NOT installed is not reported — the guard keeps no '
      'cache and re-queries the device on every check',
      () async {
        var installed = <String>['com.discord'];

        await ScreenShareGuard.check(
          isAndroid: true,
          query: () async => installed,
        );
        expect(sent, hasLength(1));

        // The user uninstalls Discord; the next launch (new session).
        installed = <String>[];
        arm();

        await ScreenShareGuard.check(
          isAndroid: true,
          query: () async => installed,
        );
        expect(sent, isEmpty);
      },
    );

    test('Teams is reported only when it is actually in the query result', () async {
      await ScreenShareGuard.check(
        isAndroid: true,
        query: () async => ['com.discord'],
      );
      expect(
        sent.map((p) => p['threat']),
        isNot(contains('Screen Share App Installed: com.microsoft.teams')),
      );
    });

    test('a second scan in the same session adds no duplicate rows', () async {
      Future<Iterable<String>> query() async =>
          ['com.discord', 'us.zoom.videomeetings'];

      await ScreenShareGuard.check(isAndroid: true, query: query);
      await ScreenShareGuard.check(isAndroid: true, query: query);

      expect(sent, hasLength(2));
    });

    test('a throwing query neither throws nor reports', () async {
      await expectLater(
        ScreenShareGuard.check(
          isAndroid: true,
          query: () async => throw StateError('package manager unavailable'),
        ),
        completes,
      );
      expect(sent, isEmpty);
      expect(killed, isEmpty);
    });

    test('on a non-Android host the query is never invoked', () async {
      var called = false;
      await ScreenShareGuard.check(
        isAndroid: false,
        query: () async {
          called = true;
          return ['com.discord'];
        },
      );
      expect(called, isFalse);
      expect(sent, isEmpty);
    });

    test(
      'the policy behind it: a screen-share hit can never terminate '
      '(policy-level guarantee, both sideload modes, enforcement on)',
      () {
        for (final allowSideload in [false, true]) {
          expect(
            ThreatPolicy.shouldTerminate(
              SecurityThreat.screenShareApp,
              allowSideload: allowSideload,
              enforce: true,
            ),
            isFalse,
          );
        }
      },
    );
  });
}
