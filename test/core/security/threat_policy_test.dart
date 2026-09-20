import 'package:app/core/security/threat_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Set<SecurityThreat> _terminating({required bool allowSideload}) => {
      for (final threat in SecurityThreat.values)
        if (ThreatPolicy.resolve(threat, allowSideload: allowSideload) ==
            ThreatAction.terminate)
          threat,
    };

void main() {
  group('ThreatPolicy.resolve()', () {
    test(
      'strict (default, store-build) mode: exactly App Integrity, Hooks, '
      'Privileged Access and Unofficial Store terminate',
      () {
        expect(
          _terminating(allowSideload: false),
          equals({
            SecurityThreat.appIntegrity,
            SecurityThreat.hooks,
            SecurityThreat.privilegedAccess,
            SecurityThreat.unofficialStore,
          }),
        );
      },
    );

    test(
      'SECURITY_ALLOW_SIDELOAD=true relaxes ONLY the unofficial-store '
      'check — integrity, hooks and root still terminate',
      () {
        expect(
          _terminating(allowSideload: true),
          equals({
            SecurityThreat.appIntegrity,
            SecurityThreat.hooks,
            SecurityThreat.privilegedAccess,
          }),
        );
        expect(
          ThreatPolicy.resolve(
            SecurityThreat.unofficialStore,
            allowSideload: true,
          ),
          ThreatAction.telemetryOnly,
        );
      },
    );

    for (final allowSideload in [false, true]) {
      test(
        'debugger, simulator, passcode, secure hardware, device binding, '
        'device id, obfuscation and screen-share app are telemetry-only '
        '(allowSideload=$allowSideload)',
        () {
          for (final threat in [
            SecurityThreat.debugger,
            SecurityThreat.simulator,
            SecurityThreat.passcode,
            SecurityThreat.secureHardware,
            SecurityThreat.deviceBinding,
            SecurityThreat.deviceId,
            SecurityThreat.obfuscation,
            SecurityThreat.screenShareApp,
          ]) {
            expect(
              ThreatPolicy.resolve(threat, allowSideload: allowSideload),
              ThreatAction.telemetryOnly,
              reason: '${threat.name} must never terminate',
            );
          }
        },
      );
    }
  });

  group('ThreatPolicy.shouldTerminate()', () {
    test('never terminates when enforcement is off, whatever the policy', () {
      for (final allowSideload in [false, true]) {
        for (final threat in SecurityThreat.values) {
          expect(
            ThreatPolicy.shouldTerminate(
              threat,
              allowSideload: allowSideload,
              enforce: false,
            ),
            isFalse,
            reason: '${threat.name} allowSideload=$allowSideload',
          );
        }
      }
    });

    test('with enforcement on, terminates exactly what resolve() says', () {
      for (final allowSideload in [false, true]) {
        final expected = _terminating(allowSideload: allowSideload);
        for (final threat in SecurityThreat.values) {
          expect(
            ThreatPolicy.shouldTerminate(
              threat,
              allowSideload: allowSideload,
              enforce: true,
            ),
            expected.contains(threat),
            reason: '${threat.name} allowSideload=$allowSideload',
          );
        }
      }
    });
  });

  group('SecurityThreat labels (security_incidents.threat)', () {
    test(
      'freeRASP labels are unchanged from the previous string literals, so '
      'existing dashboard grouping keeps working',
      () {
        expect(SecurityThreat.appIntegrity.label, 'App Integrity Compromised');
        expect(SecurityThreat.hooks.label, 'Hooks Detected');
        expect(
          SecurityThreat.privilegedAccess.label,
          'Privileged Access (Root/Jailbreak)',
        );
        expect(
          SecurityThreat.unofficialStore.label,
          'Installed from Unofficial Store',
        );
        expect(SecurityThreat.debugger.label, 'Debugger Detected');
        expect(
          SecurityThreat.simulator.label,
          'Running on Simulator/Emulator',
        );
        expect(SecurityThreat.passcode.label, 'No Secure Passcode');
        expect(
          SecurityThreat.secureHardware.label,
          'Secure Hardware Not Available',
        );
        expect(
          SecurityThreat.deviceBinding.label,
          'Device Binding Compromised',
        );
        expect(SecurityThreat.deviceId.label, 'Device ID Compromised');
        expect(SecurityThreat.obfuscation.label, 'Obfuscation Issues');
      },
    );

    test('the screen-share label says INSTALLED, never "Active"', () {
      expect(SecurityThreat.screenShareApp.label, 'Screen Share App Installed');
      expect(SecurityThreat.screenShareApp.label, isNot(contains('Active')));
    });

    test('labels are unique', () {
      final labels = SecurityThreat.values.map((t) => t.label).toList();
      expect(labels.toSet().length, labels.length);
    });

    test('every label fits the RPC 128-character threat cap with a package', () {
      for (final threat in SecurityThreat.values) {
        expect(
          threat.reportName('com.teamviewer.teamviewer.market.mobile').length,
          lessThanOrEqualTo(128),
        );
      }
    });

    test('reportName() appends the subject, and ignores null/empty', () {
      expect(
        SecurityThreat.screenShareApp.reportName('com.discord'),
        'Screen Share App Installed: com.discord',
      );
      expect(
        SecurityThreat.hooks.reportName(),
        'Hooks Detected',
      );
      expect(SecurityThreat.hooks.reportName(''), 'Hooks Detected');
    });
  });
}
