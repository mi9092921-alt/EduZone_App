import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:freerasp/freerasp.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:package_info_plus/package_info_plus.dart' as pip;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/device_info_helper.dart';
import 'guards/lifecycle_guard.dart';
import 'guards/screenshot_guard.dart';

part 'freerasp_config.dart';
part 'guards/screen_share_guard.dart';

class SecurityService with WidgetsBindingObserver {
  static const bool _enforceThreatTermination = bool.fromEnvironment(
    'SECURITY_ENFORCE_THREAT_TERMINATION',
  );

  /// Optional app-layer hook, called instead of the raw platform kill when
  /// a threat requires terminating access (e.g. navigate to a dedicated
  /// "device not secure" lock screen via the app's router).
  ///
  /// Not wired up yet — this is intentionally left as an injection point
  /// rather than guessing at navigation/router integration. Recommended:
  /// set this once in `main.dart`/`app_initializer.dart` after the router
  /// is available, e.g.:
  ///   SecurityService.killAppHandler = (reason) =>
  ///       rootNavigatorKey.currentContext?.go('/security-blocked?reason=$reason');
  static void Function(String reason)? killAppHandler;

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
      name: 'Screenshot protection',
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

  static void _onThreatDetected(String threatName) {
    _logThreatToSupabase(threatName);

    if (!_enforceThreatTermination) {
      debugPrint('[SECURITY][THREAT DETECTED]: $threatName');
      return;
    }

    _killApp(threatName);
  }

  static Future<void> _runStartupStep({
    required String name,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
    } catch (e, stack) {
      debugPrint('[SECURITY] $name failed during startup: $e');
      debugPrintStack(stackTrace: stack);
      _logThreatToSupabase('Security Startup Step Failed: $name');
    }
  }

  /// In-memory fallback so a threat event is never silently dropped just
  /// because the Supabase insert failed (offline, RLS misconfig, etc).
  /// Capped to avoid unbounded growth; not persisted across app restarts —
  /// this is a best-effort debugging aid, not a durability guarantee.
  static final List<Map<String, dynamic>> _localThreatBuffer = [];
  static const int _localThreatBufferMax = 50;

  static void _logThreatToSupabase(String threat) {
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
    };

    // Fire-and-forget: we do not await or block execution.
    try {
      final client = Supabase.instance.client;
      pip.PackageInfo.fromPlatform().then((packageInfo) {
        payload['app_version'] = packageInfo.version;
        payload['app_build_number'] = packageInfo.buildNumber;
        _insertIncident(client, payload);
      }).catchError((_) {
        payload['app_version'] = 'unknown';
        payload['app_build_number'] = 'unknown';
        _insertIncident(client, payload);
      });
    } on StateError catch (_) {
      // Kept alongside AssertionError below in case a future
      // supabase_flutter version changes which type it throws here — see
      // the discovered-bug note in
      // test/core/security/security_service_test.dart for why both are
      // caught: as of the currently pinned version, Supabase.instance
      // actually throws AssertionError, not StateError, before
      // Supabase.initialize() has run.
      debugPrint('[SECURITY] Supabase not ready for logging.');
      _bufferThreatLocally(payload, status: 'supabase_not_ready');
    } on AssertionError catch (_) {
      // Supabase not initialized yet; keep locally instead of dropping it.
      debugPrint('[SECURITY] Supabase not ready for logging.');
      _bufferThreatLocally(payload, status: 'supabase_not_ready');
    } catch (e) {
      _bufferThreatLocally(payload, status: 'unknown_error', error: e.toString());
    }
  }

  static void _insertIncident(
    SupabaseClient client,
    Map<String, dynamic> payload,
  ) {
    client
        .from('security_incidents')
        .insert(payload)
        .then((_) {})
        .catchError((e) {
          _bufferThreatLocally(payload, status: 'insert_failed', error: e.toString());
        });
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
    String? error,
  }) {
    final entry = {...payload, 'log_status': status, 'log_error': ?error};
    _localThreatBuffer.add(entry);
    if (_localThreatBuffer.length > _localThreatBufferMax) {
      _localThreatBuffer.removeAt(0);
    }
    debugPrint('[SECURITY][UNSYNCED THREAT] $entry');
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
