import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freerasp/freerasp.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:package_info_plus/package_info_plus.dart' as pip;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';
import '../utils/device_info_helper.dart';
import 'data/security_incident_remote_ds.dart';
import 'guards/lifecycle_guard.dart';
import 'guards/screenshot_guard.dart';
import 'threat_policy.dart';

part 'freerasp_config.dart';
part 'guards/screen_share_guard.dart';

class SecurityService with WidgetsBindingObserver {
  /// Audit P0 (M7): threat termination is a release-only action.
  ///
  /// freeRASP may still run in debug/profile builds when it is configured so
  /// threats can be observed during testing, but a simulator/debugger must
  /// not navigate a pre-login user to the account-lock screen. The previous
  /// implementation allowed `SECURITY_ENFORCE_THREAT_TERMINATION=true` in a
  /// local debug run to do exactly that (the emulator threat was presented as
  /// "Account Locked"). Release builds remain enabled by default, while the
  /// define can explicitly disable enforcement for a telemetry-only rollout.
  static const bool _enforceThreatTermination = kReleaseMode &&
      bool.fromEnvironment(
        'SECURITY_ENFORCE_THREAT_TERMINATION',
        // The analyzer evaluates kReleaseMode as false during static
        // analysis and therefore flags the argument as redundant; in real
        // release builds this default is the whole point (audit P0/M7).
        // ignore: avoid_redundant_argument_values
        defaultValue: true,
      );

  /// Direct-APK distribution switch (owner decision, 2026-09-20: distribution
  /// is a direct APK, intentionally and temporarily — there is no store yet).
  ///
  /// freeRASP reports "Installed from Unofficial Store" for every install that
  /// did not come from a supported store, which is EVERY sideloaded APK. With
  /// `SECURITY_ALLOW_SIDELOAD=true` that one threat becomes telemetry-only.
  /// Any other value — including the blank line in `.env.example` and an
  /// omitted define — keeps it strict (terminating), which is what a store
  /// build must ship. Compared as a string (not `bool.fromEnvironment`) so a
  /// blank value can never be misread as "allow".
  ///
  /// This relaxes ONLY the store check. Repackaging/tampering is still caught
  /// by `onAppIntegrity` (signing-certificate hash) and still terminates.
  static const bool _allowSideload =
      String.fromEnvironment('SECURITY_ALLOW_SIDELOAD') == 'true';

  /// Test-only overrides for the two compile-time flags above, so the
  /// dispatch in [_onThreatDetected] can be exercised in both modes from a
  /// unit test. Production code never sets these.
  @visibleForTesting
  static bool? enforceOverrideForTest;
  @visibleForTesting
  static bool? allowSideloadOverrideForTest;

  /// Optional app-layer hook, called instead of the raw platform kill when
  /// a threat requires terminating access (e.g. navigate to a dedicated
  /// "device not secure" lock screen via the app's router).
  ///
  /// Wired by the router (`app_router.dart`'s wireSecurityKillHandler): it
  /// latches [killSwitchEngaged] first — the redirect honours that latch
  /// ahead of its appState switch, so the /locked destination sticks —
  /// then navigates to /locked via the root navigator key.
  static void Function(String reason)? killAppHandler;

  /// Latched "a security threat fired and the app-layer kill handler ran"
  /// flag. The router redirect checks this BEFORE its appState switch:
  /// without it, a `go(AppRoutes.locked)` issued while [AppAuthState] is
  /// `authenticated` is bounced straight back to `/home` by the redirect's
  /// restricted-routes guard, silently neutralising the kill switch (the
  /// user keeps browsing on the compromised device). The flag is
  /// intentionally in-memory only: it resets on process restart, where the
  /// RASP guards re-evaluate and re-engage on their own.
  static bool _killSwitchEngaged = false;
  static bool get killSwitchEngaged => _killSwitchEngaged;

  /// Latches the kill switch. Idempotent — multiple threat callbacks may
  /// fire for the same event (freeRASP detector fan-out).
  static void engageKillSwitch() {
    _killSwitchEngaged = true;
  }

  /// Test-only reset. The flag is deliberately NOT auto-reset by the
  /// router: once a threat is confirmed, navigation alone must not be able
  /// to undo the lock for the lifetime of the process.
  @visibleForTesting
  static void resetKillSwitchForTest() {
    _killSwitchEngaged = false;
  }

  // Singleton pattern
  static final SecurityService _instance = SecurityService._internal();
  SecurityService._internal();
  static SecurityService get instance => _instance;

  static bool _initialized = false;

  /// Runs the fast, must-happen-before-first-frame guard, then kicks off
  /// the slow/native-bound guards WITHOUT awaiting them so [init] itself
  /// stays cheap and never delays `runApp()`.
  ///
  /// Cold-start fix rationale: [ScreenShareGuard.check] and
  /// `Talsec.instance.start` are MethodChannel calls — the real work
  /// happens on the native side (PackageManager enumeration / freeRASP
  /// native SDK checks), not on the Dart isolate. Awaiting them here
  /// doesn't reduce their native cost, it just forces every caller of
  /// [init] (`AppInitializer` → `main()`) to sit idle until they're done
  /// before `runApp()` can paint the first frame. Firing them with
  /// [unawaited] removes them from the startup critical path entirely;
  /// they still report threats via [_onThreatDetected] whenever they
  /// resolve, just later (not on the first frame anymore).
  static Future<void> init() async {
    if (_initialized) return;

    // Fast native call with an immediate UX requirement (screenshots must
    // be blocked from the very first frame) → stays on the critical path.
    await _runStartupStep(
      name: 'Screenshot & recording protection',
      action: ScreenshotGuard.protect,
    );

    // Slow, native-bound, no first-frame dependency → fire-and-forget.
    unawaited(_runStartupStep(
      name: 'Screen share scan',
      action: ScreenShareGuard.check,
    ));

    if (isFreeraspConfigured()) {
      unawaited(_runStartupStep(
        name: 'freeRASP',
        action: () async {
          await _setupFreeraspListener();
          await Talsec.instance.start(_getTalsecConfig());
        },
      ));
    } else {
      debugPrint(
        '[SECURITY] freeRASP skipped: SECURITY_ANDROID_SIGNING_HASH not '
        'supplied for this build (expected for local development without '
        '--dart-define-from-file=.env.security). Not logged as a startup '
        'failure.',
      );
    }

    WidgetsBinding.instance.addObserver(_instance);
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    LifecycleGuard.instance.didChangeAppLifecycleState(state);
  }

  /// Single entry point for every threat (freeRASP callbacks and guards).
  ///
  /// Always reports to `security_incidents`; terminates ONLY when
  /// [ThreatPolicy] says the threat terminates for this build AND
  /// enforcement is on. [subject] is the specific package for package-scoped
  /// threats. [source] records what produced the signal.
  ///
  /// Returns the telemetry future so tests (and guards) can await delivery;
  /// production callers deliberately do not await it.
  static Future<void> _onThreatDetected(
    SecurityThreat threat, {
    String? subject,
    String source = 'freerasp',
  }) {
    final allowSideload = allowSideloadOverrideForTest ?? _allowSideload;
    final enforce = enforceOverrideForTest ?? _enforceThreatTermination;
    final policy = ThreatPolicy.resolve(threat, allowSideload: allowSideload);
    final terminate = ThreatPolicy.shouldTerminate(
      threat,
      allowSideload: allowSideload,
      enforce: enforce,
    );
    final name = threat.reportName(subject);

    final logged = _logThreatToSupabase(
      name,
      details: <String, dynamic>{
        'detection_source': source,
        'policy': policy == ThreatAction.terminate
            ? 'terminate'
            : 'telemetry_only',
        'enforced': enforce,
        'action_taken': terminate ? 'terminated' : 'reported_only',
        if (threat == SecurityThreat.unofficialStore)
          'sideload_allowed': allowSideload,
      },
    );

    if (!terminate) {
      debugPrint(
        '[SECURITY] threat detected; not terminating '
        '(policy=${policy.name}, enforce=$enforce).',
      );
      return logged;
    }

    _killApp(name);
    return logged;
  }

  /// Test-only entry point for [_onThreatDetected].
  @visibleForTesting
  static Future<void> reportThreatForTest(
    SecurityThreat threat, {
    String? subject,
    String source = 'test',
  }) =>
      _onThreatDetected(threat, subject: subject, source: source);

  /// Test-only reset of the telemetry state (per-session dedupe set, local
  /// buffer, sender override, flag overrides).
  @visibleForTesting
  static void resetTelemetryStateForTest() {
    _reportedThisSession.clear();
    _localThreatBuffer.clear();
    incidentSenderForTest = null;
    enforceOverrideForTest = null;
    allowSideloadOverrideForTest = null;
  }

  static Future<void> _runStartupStep({
    required String name,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (e, stack) {
      debugPrint('[SECURITY] $name failed during startup: ${e.runtimeType}');
      debugPrintStack(stackTrace: stack);
      unawaited(_logThreatToSupabase(
        'Security Startup Step Failed: $name',
        details: const <String, dynamic>{
          'detection_source': 'startup',
          'policy': 'telemetry_only',
          'action_taken': 'reported_only',
        },
      ));
      // Deliberate misconfiguration must fail fast in a release build, not
      // degrade to "RASP silently disabled": freeRASP's config throws
      // StateError when the release signing hash / team id / watcher mail
      // were never supplied — exactly the "production build without its
      // security guards" case its fail-fast exists to catch. Mirrors
      // SupabaseService.initialize's cert-pinning fail-fast (SEC-001):
      // startup refuses to continue rather than running unpinned/unguarded.
      // Debug/profile builds keep the swallow-and-log behavior so local
      // development without security env values keeps working.
      if (kReleaseMode && e is StateError) rethrow;
    }
  }

  /// In-memory fallback so a threat event is never silently dropped just
  /// because the Supabase insert failed (offline, RLS misconfig, etc).
  /// Capped to avoid unbounded growth; not persisted across app restarts —
  /// this is a best-effort debugging aid, not a durability guarantee.
  static final List<Map<String, dynamic>> _localThreatBuffer = [];
  static const int _localThreatBufferMax = 50;

  /// Threat labels already reported (or in flight) in this process.
  ///
  /// "At most one insert per (device, threat, session)": the device
  /// fingerprint is constant for the life of the process and a session is a
  /// process, so the report name is the whole key. freeRASP re-fires its
  /// callbacks and the screen-share scan re-runs on every launch; without this
  /// one bad device produced dozens of identical rows. An entry is REMOVED
  /// again if delivery fails, so a later occurrence in the same session can
  /// still land (the failure is also kept in [_localThreatBuffer]).
  static final Set<String> _reportedThisSession = <String>{};

  /// Test-only replacement for the Supabase write. When set, no Supabase
  /// readiness probe or RPC happens.
  @visibleForTesting
  static Future<void> Function(Map<String, dynamic> payload)?
      incidentSenderForTest;

  static Future<void> _logThreatToSupabase(
    String threat, {
    Map<String, dynamic>? details,
  }) async {
    if (!_reportedThisSession.add(threat)) {
      debugPrint('[SECURITY] duplicate threat report suppressed this session.');
      return;
    }

    final payload = <String, dynamic>{
      'threat': threat,
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'detected_at': DateTime.now().toUtc().toIso8601String(),
      'is_release_build': kReleaseMode,
      // Reuses the existing stable SHA256 fingerprint from
      // DeviceInfoHelper (core/utils/device_info_helper.dart) — never a
      // raw hardware identifier. Falls back to null if device info
      // hasn't been initialized yet (e.g. an early startup-step failure
      // before step 4 in AppInitializer runs).
      'device_fingerprint': _safeDeviceFingerprint(),
      // Structured, PII-free context (policy, enforced, action taken,
      // detection source, installer package). Validated server-side as a
      // JSON object under 4 KB by report_security_incident().
      'details': <String, dynamic>{...?details},
    };

    final sender = incidentSenderForTest;
    try {
      // No session gate: report_security_incident() accepts pre-auth callers
      // by design (anon → user_id NULL server-side) — capturing pre-login
      // RASP events is exactly its purpose (2026-09-19 product/security
      // decision). The RPC validates shape and absorbs volume abuse
      // server-side; local buffering below handles transport failures only.
      // The client read is the Supabase readiness probe (it throws before
      // Supabase.initialize() has run) and is skipped under a test sender.
      final client = sender == null ? SupabaseService.client : null;

      String? installer;
      try {
        final packageInfo = await pip.PackageInfo.fromPlatform();
        payload['app_version'] = packageInfo.version;
        payload['app_build_number'] = packageInfo.buildNumber;
        installer = packageInfo.installerStore;
      } catch (_) {
        payload['app_version'] = 'unknown';
        payload['app_build_number'] = 'unknown';
      }
      // Package name of the installer (e.g. com.android.vending, or the
      // system package installer for a sideloaded APK). Not PII.
      if (installer != null && installer.isNotEmpty) {
        (payload['details'] as Map<String, dynamic>)['installer'] = installer;
      }

      await _insertIncident(client, payload, sender);
    } on StateError catch (_) {
      // Kept alongside AssertionError below in case a future
      // supabase_flutter version changes which type it throws here — see
      // the discovered-bug note in
      // test/core/security/security_service_test.dart for why both are
      // caught: as of the currently pinned version, Supabase.instance
      // actually throws AssertionError, not StateError, before
      // Supabase.initialize() has run.
      debugPrint('[SECURITY] Supabase not ready for logging.');
      _reportedThisSession.remove(threat);
      _bufferThreatLocally(payload, status: 'supabase_not_ready');
    } on AssertionError catch (_) {
      // Supabase not initialized yet; keep locally instead of dropping it.
      debugPrint('[SECURITY] Supabase not ready for logging.');
      _reportedThisSession.remove(threat);
      _bufferThreatLocally(payload, status: 'supabase_not_ready');
    } catch (_) {
      _reportedThisSession.remove(threat);
      _bufferThreatLocally(payload, status: 'unknown_error');
    }
  }

  static Future<void> _insertIncident(
    SupabaseClient? client,
    Map<String, dynamic> payload,
    Future<void> Function(Map<String, dynamic> payload)? sender,
  ) async {
    // The Supabase write itself lives in the security data layer
    // (core/security/data) per the core data pattern; the `client`
    // parameter is kept for the pre-insert Supabase.instance readiness
    // probe in the caller (see the StateError/AssertionError note in
    // _logThreatToSupabase).
    try {
      if (sender != null) {
        await sender(payload);
        return;
      }
      await const SecurityIncidentRemoteDs().reportIncident(
        threat: payload['threat'] as String? ?? 'unknown',
        platform: payload['platform'] as String? ?? 'unknown',
        platformVersion: payload['platform_version'] as String?,
        isReleaseBuild: payload['is_release_build'] as bool? ?? false,
        deviceFingerprint: payload['device_fingerprint'] as String?,
        appVersion: payload['app_version'] as String?,
        appBuildNumber: payload['app_build_number'] as String?,
        details: payload['details'] as Map<String, dynamic>?,
      );
    } catch (_) {
      // Allow a later occurrence in this session to retry delivery.
      _reportedThisSession.remove(payload['threat']);
      _bufferThreatLocally(payload, status: 'insert_failed');
    }
  }

  static String? _safeDeviceFingerprint() {
    try {
      return DeviceInfoHelper.fingerprint;
    } catch (_) {
      // DeviceInfoHelper.init() hasn't run yet.
      return null;
    }
  }

  static void _bufferThreatLocally(
    Map<String, dynamic> payload, {
    required String status,
  }) {
    final entry = {...payload, 'log_status': status};
    _localThreatBuffer.add(entry);
    if (_localThreatBuffer.length > _localThreatBufferMax) {
      _localThreatBuffer.removeAt(0);
    }
    debugPrint('[SECURITY] threat event buffered locally: $status');
  }

  /// Unsynced threat events kept in memory for this app session — useful
  /// for a debug-only diagnostics screen. Not a substitute for fixing the
  /// underlying Supabase insert failures.
  static List<Map<String, dynamic>> get unsyncedThreatBuffer =>
      List.unmodifiable(_localThreatBuffer);

  static void _killApp(String reason) {
    debugPrint('[SECURITY] App killed: $reason');

    final handler = killAppHandler;
    if (handler != null) {
      handler(reason);
      return;
    }

    // No app-layer handler registered. exit(0) is a well-established
    // pattern on Android for RASP-triggered termination, but Apple's
    // guidelines discourage apps deliberately calling exit()/terminating
    // themselves on iOS, and it is also a jarring UX (app just vanishes
    // instead of showing why). Until a graceful handler is wired up via
    // [killAppHandler], iOS falls back to a loud warning instead of a
    // silent/risky exit() call.
    if (Platform.isIOS) {
      debugPrint(
        '[SECURITY] WARNING: no killAppHandler registered — threat '
        'detected on iOS but the app was NOT terminated. Wire up '
        'SecurityService.killAppHandler to a lock/blocked screen.',
      );
      return;
    }

    exit(0);
  }
}
