part of 'security_service.dart';

/// Testing-only accessor for [_getTalsecConfig].
///
/// [_getTalsecConfig] is library-private (leading underscore) inside this
/// `part of` file, so it is normally invisible to external test files even
/// though they can import `security_service.dart` (which shares this
/// library via the `part`/`part of` directive — [ScreenShareGuard] is
/// reachable the same way). This function adds no new behavior: it is a
/// pure pass-through, marked `@visibleForTesting` so it isn't mistaken for
/// production API surface.
@visibleForTesting
TalsecConfig debugGetTalsecConfig() => _getTalsecConfig();

/// True when freeRASP has enough configuration to make sense of starting
/// in the current build mode.
///
/// False specifically for the common local/CI debug case where
/// SECURITY_ANDROID_SIGNING_HASH was never supplied via
/// --dart-define-from-file=.env.security (confirmed: the team does not
/// currently supply this file for local development). In that case
/// freeRASP is skipped cleanly by [SecurityService.init] instead of being
/// started with an empty (useless) signing-hash allowlist — which
/// previously threw a `configuration-exception` from inside the freerasp
/// plugin's own [AndroidConfig] constructor and got logged as a generic,
/// confusing "Security Startup Step Failed: freeRASP" entry.
///
/// Release builds are unaffected: this returns `true` for any release
/// build regardless of the hash, so the existing fail-fast check inside
/// [_getTalsecConfig] still runs and still throws if a release build is
/// genuinely misconfigured (empty hash/team id) — that safety net is
/// unchanged.
bool isFreeraspConfigured() {
  const hash = String.fromEnvironment('SECURITY_ANDROID_SIGNING_HASH');
  return kReleaseMode || hash.isNotEmpty;
}

/// Configures and returns the [TalsecConfig] for the freeRASP SDK.
///
/// All secrets are injected at build time via
/// `--dart-define-from-file=.env.security` (see `.env.security.example` and
/// `lib/core/security/README.md`). Nothing sensitive is hardcoded in source.
/// In release builds, missing values fail fast instead of silently shipping
/// a non-functional (empty signing hash / team id) RASP configuration.
TalsecConfig _getTalsecConfig() {
  const String kWatcherMail = String.fromEnvironment(
    'SECURITY_WATCHER_MAIL',
    defaultValue: 'mi9092921@gmail.com',
  );

  // Android signing certificate SHA-256 hash (Base64), e.g. output of:
  //   keytool -list -v -keystore <release>.keystore -alias <alias>
  const String kExpectedSignatureHash = String.fromEnvironment(
    'SECURITY_ANDROID_SIGNING_HASH',
  );

  const String kIosBundleId = String.fromEnvironment(
    'SECURITY_IOS_BUNDLE_ID',
    defaultValue: 'com.eduzone.learn.app',
  );

  const String kIosTeamId = String.fromEnvironment(
    'SECURITY_IOS_TEAM_ID',
  );

  // Fail fast in release if the real production values were never supplied.
  // Without this, the app would silently ship with an empty signing-hash
  // allowlist, which makes freeRASP's tamper/repackaging detection useless.
  //
  // NOTE: this is a plain `if`/`throw`, not `assert()` — assert bodies are
  // stripped out of release builds by default, so an assert() here would
  // never actually run in production and would defeat the whole point.
  if (kReleaseMode &&
      (kExpectedSignatureHash.isEmpty || kIosTeamId.isEmpty)) {
    throw StateError(
      'freeRASP misconfigured: SECURITY_ANDROID_SIGNING_HASH and '
      'SECURITY_IOS_TEAM_ID must be supplied via '
      '--dart-define-from-file=.env.security for release builds.',
    );
  }

  return TalsecConfig(
    androidConfig: AndroidConfig(
      packageName: 'com.eduzone.learn.app',
      signingCertHashes:
          kExpectedSignatureHash.isEmpty ? const [] : [kExpectedSignatureHash],
      supportedStores: ['com.android.vending'], // Google Play Store
    ),
    iosConfig: IOSConfig(
      bundleIds: [kIosBundleId],
      teamId: kIosTeamId,
    ),
    watcherMail: kWatcherMail,
    isProd: kReleaseMode, // Automatically true in release, false in debug
  );
}

/// Setup threat callback listener and route all detected threats to [SecurityService]
Future<void> _setupFreeraspListener() async {
  final callback = ThreatCallback(
    onAppIntegrity: () {
      SecurityService._onThreatDetected('App Integrity Compromised');
    },
    onObfuscationIssues: () {
      SecurityService._onThreatDetected('Obfuscation Issues');
    },
    onDebug: () => SecurityService._onThreatDetected('Debugger Detected'),
    onDeviceBinding: () {
      SecurityService._onThreatDetected('Device Binding Compromised');
    },
    onDeviceID: () => SecurityService._onThreatDetected('Device ID Compromised'),
    onHooks: () => SecurityService._onThreatDetected('Hooks Detected'),
    onPasscode: () => SecurityService._onThreatDetected('No Secure Passcode'),
    onPrivilegedAccess: () {
      SecurityService._onThreatDetected('Privileged Access (Root/Jailbreak)');
    },
    onSecureHardwareNotAvailable: () {
      SecurityService._onThreatDetected('Secure Hardware Not Available');
    },
    onSimulator: () {
      SecurityService._onThreatDetected('Running on Simulator/Emulator');
    },
    onUnofficialStore: () {
      SecurityService._onThreatDetected('Installed from Unofficial Store');
    },
  );

  await Talsec.instance.attachListener(callback);
}
