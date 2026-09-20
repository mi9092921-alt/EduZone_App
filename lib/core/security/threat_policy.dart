/// What the app does when a security threat fires.
enum ThreatAction {
  /// Latch the security kill switch (navigate to `/locked`, or exit on
  /// Android when no handler is wired) — subject to the build-time
  /// `SECURITY_ENFORCE_THREAT_TERMINATION` enforcement flag.
  terminate,

  /// Report to `security_incidents` only. Never terminates, never blocks
  /// login, never hides content.
  telemetryOnly,
}

/// Every threat [SecurityService] can report, with its default action.
///
/// The [label] values are the exact strings stored in
/// `security_incidents.threat` — the dashboard groups by them, so the
/// freeRASP labels are deliberately unchanged from the previous string
/// literals. Only [screenShareApp] is new: it replaces
/// `Blacklisted Screen Share App Active: <pkg>`, which claimed the app was
/// *active* when the guard only ever checked that a package is *installed*.
///
/// Policy (owner decision, 2026-09-20): only threats that indicate the app
/// itself is compromised terminate — [appIntegrity], [hooks],
/// [privilegedAccess]. [unofficialStore] terminates by default (strict,
/// correct for a store build) and is relaxed to telemetry-only by the
/// explicit build-time flag `SECURITY_ALLOW_SIDELOAD=true`. Everything else
/// is telemetry-only.
enum SecurityThreat {
  appIntegrity('App Integrity Compromised', ThreatAction.terminate),
  hooks('Hooks Detected', ThreatAction.terminate),
  privilegedAccess(
    'Privileged Access (Root/Jailbreak)',
    ThreatAction.terminate,
  ),

  /// Terminates when strict; telemetry-only under `SECURITY_ALLOW_SIDELOAD`.
  /// See [ThreatPolicy.resolve].
  unofficialStore('Installed from Unofficial Store', ThreatAction.terminate),

  debugger('Debugger Detected', ThreatAction.telemetryOnly),
  simulator('Running on Simulator/Emulator', ThreatAction.telemetryOnly),
  passcode('No Secure Passcode', ThreatAction.telemetryOnly),
  secureHardware('Secure Hardware Not Available', ThreatAction.telemetryOnly),
  deviceBinding('Device Binding Compromised', ThreatAction.telemetryOnly),
  deviceId('Device ID Compromised', ThreatAction.telemetryOnly),
  obfuscation('Obfuscation Issues', ThreatAction.telemetryOnly),

  /// A blacklisted screen-share / remote-control package is INSTALLED. That
  /// says nothing about whether the screen is being shared, so it is
  /// telemetry-only by design. Real capture protection is FLAG_SECURE
  /// (see `MainActivity.kt` and `ScreenshotGuard`).
  screenShareApp('Screen Share App Installed', ThreatAction.telemetryOnly);

  const SecurityThreat(this.label, this.defaultAction);

  /// Value stored in `security_incidents.threat` (before any [subject]).
  final String label;

  /// Action before the sideload relaxation is applied.
  final ThreatAction defaultAction;

  /// `label`, or `label: subject` when the threat is about a specific
  /// package (e.g. `Screen Share App Installed: com.discord`).
  String reportName([String? subject]) =>
      (subject == null || subject.isEmpty) ? label : '$label: $subject';
}

/// Pure decision logic — no platform or Supabase access, so it is fully
/// unit-testable (`test/core/security/threat_policy_test.dart`).
abstract final class ThreatPolicy {
  /// The action for [threat] given the build's sideload setting.
  static ThreatAction resolve(
    SecurityThreat threat, {
    required bool allowSideload,
  }) {
    if (threat == SecurityThreat.unofficialStore && allowSideload) {
      return ThreatAction.telemetryOnly;
    }
    return threat.defaultAction;
  }

  /// Whether the app should actually terminate: the policy says so AND this
  /// build has enforcement enabled.
  static bool shouldTerminate(
    SecurityThreat threat, {
    required bool allowSideload,
    required bool enforce,
  }) =>
      enforce &&
      resolve(threat, allowSideload: allowSideload) == ThreatAction.terminate;
}
