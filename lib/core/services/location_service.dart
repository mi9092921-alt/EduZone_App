import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/device_info_helper.dart';

part 'location_service.g.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

/// SharedPreferences key for the last successful location-send timestamp.
const _kLastSentKey = 'location_last_sent_at';

/// Client-side minimum interval between logs (must be ≤ server default of 3 min).
const _kMinIntervalSec = 180;

/// Extra random jitter added to [_kMinIntervalSec] to flatten burst patterns.
/// Actual client interval = 180..210 seconds.
const _kJitterMaxSec = 30;

/// Maximum acceptable accuracy radius in metres.
/// Readings worse than this are considered garbage and discarded.
const _kMaxAccuracyMetres = 150.0;

/// Position fetch timeout. Generous enough for a cold GPS fix on high accuracy.
const _kPositionTimeout = Duration(seconds: 12);

// ─── Permission Result ────────────────────────────────────────────────────────

/// Typed result from [LocationService._resolvePermission].
enum LocationPermissionStatus {
  /// GPS service disabled on device.
  serviceDisabled,

  /// User denied once — can ask again later.
  denied,

  /// User denied permanently — must redirect to settings.
  deniedForever,

  /// Granted while app is in use (foreground). Sufficient for our use-case.
  whileInUse,

  /// Granted at all times (background). Also sufficient.
  always,
}

// ─── Service ─────────────────────────────────────────────────────────────────

/// Handles "on app open" location logging.
///
/// Accuracy strategy:
///   Android → [AndroidSettings] with [LocationAccuracy.high] +
///             [LocationAccuracyRequest.preciseAccuracy] (API 31+)
///   iOS     → [AppleSettings] with [LocationAccuracy.best] +
///             [ActivityType.other] (no nav activity filter)
///
/// Permission flow:
///   serviceDisabled  → silent no-op (no pop-up)
///   denied           → silent no-op (OS already showed its dialog once)
///   deniedForever    → silent no-op (caller can use [openAppSettings] if needed)
///   whileInUse/always → proceed with location fetch
class LocationService {
  const LocationService._();

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Fire-and-forget location log on every confirmed app open.
  ///
  /// Never throws — all errors are swallowed so app flow is never interrupted.
  /// Returns a diagnostic string for debug logging only.
  static Future<String?> logOnAppOpen({String? sessionId}) async {
    try {
      // ── 1. Client-side throttle (fast, no network hit) ─────────────────────
      final prefs = await SharedPreferences.getInstance();
      // reload() ensures we see writes from any concurrent app instance
      // (e.g. user opens two activities simultaneously on Android).
      await prefs.reload();
      final lastSentMs = prefs.getInt(_kLastSentKey);
      if (lastSentMs != null) {
        final jitterSec  = Random().nextInt(_kJitterMaxSec + 1);
        final minMs      = (_kMinIntervalSec + jitterSec) * 1000;
        final elapsedMs  = DateTime.now().millisecondsSinceEpoch - lastSentMs;
        if (elapsedMs < minMs) {
          if (kDebugMode) {
            debugPrint('[Location] Throttled (client): ${elapsedMs ~/ 1000}s '
                '(min ${minMs ~/ 1000}s with jitter)');
          }
          return 'throttled_client';
        }
      }

      // ── 2. Permission resolution ───────────────────────────────────────────
      final permStatus = await _resolvePermission();
      if (kDebugMode) debugPrint('[Location] Permission: ${permStatus.name}');

      switch (permStatus) {
        case LocationPermissionStatus.serviceDisabled:
          // Don't ask user to enable GPS silently — only do it if they
          // explicitly request it via a UI action.
          return 'service_disabled';

        case LocationPermissionStatus.denied:
          // OS already showed denial dialog; we don't re-ask here.
          return 'permission_denied';

        case LocationPermissionStatus.deniedForever:
          // Can't ask again — the only way is Geolocator.openAppSettings().
          // We surface this so the caller can decide whether to show a banner.
          return 'permission_denied_forever';

        case LocationPermissionStatus.whileInUse:
        case LocationPermissionStatus.always:
          break; // proceed
      }

      // ── 3. Fetch position — platform-specific high-accuracy settings ────────
      final position = await _fetchPosition();
      if (position == null) return 'position_unavailable';

      if (kDebugMode) {
        debugPrint(
          '[Location] Position: ${position.latitude}, ${position.longitude} '
          '(±${position.accuracy.toStringAsFixed(0)}m)',
        );
      }

      // ── 4. Accuracy gate — reject low-quality fixes before hitting the server
      if (position.accuracy > _kMaxAccuracyMetres) {
        if (kDebugMode) {
          debugPrint('[Location] Accuracy too low: '
              '${position.accuracy.toStringAsFixed(0)}m '
              '(max $_kMaxAccuracyMetres m) — discarding');
        }
        return 'accuracy_too_low';
      }

      // ── 5. Call server-side RPC ────────────────────────────────────────────
      // NOTE: Do NOT send a client timestamp — the server uses NOW() so it
      // can't be manipulated by clock drift or timezone changes on the device.
      final source = _sourceFromPosition(position);
      final client = Supabase.instance.client;
      final result = await client.rpc(
        'log_app_open_location',
        params: {
          'p_latitude':    position.latitude,
          'p_longitude':   position.longitude,
          'p_accuracy':    position.accuracy,
          'p_source':      source,
          'p_device_info': DeviceInfoHelper.deviceInfoJson,
          // p_min_interval_min defaults to 3 on the server
          ...?sessionId != null ? {'p_session_id': sessionId} : null,
        },
      );

      final resultStr = result?.toString() ?? 'unknown';
      if (kDebugMode) debugPrint('[Location] RPC result: $resultStr');

      // ── 6. Persist timestamp only on a fresh successful insert ─────────────
      // We intentionally use client time here (not server time) because:
      // • We only need it for the LOCAL throttle check.
      // • The server already controls the authoritative timestamp via NOW().
      if (result != null) {
        await prefs.setInt(
          _kLastSentKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }

      return resultStr;
    } on TimeoutException {
      if (kDebugMode) debugPrint('[Location] Position timeout — skipping');
      return 'timeout';
    } catch (e) {
      // Non-critical telemetry — NEVER crash the app.
      if (kDebugMode) debugPrint('[Location] Non-critical error: $e');
      return null;
    }
  }

  // ─── Settings Helpers (call from UI on deniedForever) ─────────────────────

  /// Opens the system app-permissions settings page for this app.
  /// Use when [logOnAppOpen] returns `'permission_denied_forever'`.
  static Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Opens the system location-services settings page.
  /// Use when [logOnAppOpen] returns `'service_disabled'`.
  static Future<bool> openLocationSettings() =>
      Geolocator.openLocationSettings();

  // ─── Private Helpers ───────────────────────────────────────────────────────

  /// Checks + requests location permission, returning a typed status.
  static Future<LocationPermissionStatus> _resolvePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionStatus.serviceDisabled;

    var raw = await Geolocator.checkPermission();

    if (raw == LocationPermission.denied) {
      // Ask once — the OS controls the UI dialog.
      raw = await Geolocator.requestPermission();
    }

    return switch (raw) {
      LocationPermission.denied           => LocationPermissionStatus.denied,
      LocationPermission.deniedForever    => LocationPermissionStatus.deniedForever,
      LocationPermission.whileInUse       => LocationPermissionStatus.whileInUse,
      LocationPermission.always           => LocationPermissionStatus.always,
      _                                   => LocationPermissionStatus.denied,
    };
  }

  /// Fetches the current position using the highest accuracy settings
  /// available per platform.
  ///
  /// Android: uses [AndroidSettings] with [LocationAccuracy.high] and
  ///          [LocationAccuracyRequest.preciseAccuracy] (Precise location for API 31+).
  ///
  /// iOS:     uses [AppleSettings] with [LocationAccuracy.best] and
  ///          [ActivityType.other] (no navigation filtering).
  static Future<Position?> _fetchPosition() async {
    try {
      if (Platform.isAndroid) {
        return await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: _kPositionTimeout,
          ),
        );
      } else if (Platform.isIOS) {
        return await Geolocator.getCurrentPosition(
          locationSettings: AppleSettings(
            timeLimit: _kPositionTimeout,
          ),
        );
      } else {
        // Web / desktop fallback
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: _kPositionTimeout,
          ),
        );
      }
    } on TimeoutException {
      rethrow; // handled by caller
    } catch (e) {
      debugPrint('[Location] _fetchPosition error: $e');
      return null;
    }
  }

  /// Maps a [Position] to the DB `source` enum.
  ///   accuracy ≤ 50 m  → 'gps'     (fine / GPS satellite fix)
  ///   accuracy > 50 m  → 'wifi'    (coarse network/Wi-Fi fix)
  static String _sourceFromPosition(Position position) =>
      position.accuracy <= 50 ? 'gps' : 'wifi';
}

// ─── Riverpod Provider ────────────────────────────────────────────────────────

@riverpod
LocationService locationService(Ref ref) => const LocationService._();
