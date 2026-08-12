import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/request_cancellation_manager.dart';
import '../models/logout_result.dart';

/// Keys that must be preserved across logout.
/// Onboarding, theme preferences, and language settings survive.
const _preservedPrefKeys = {
  'onboarding_completed',
  'app_theme',
  'app_locale',
};

/// Keys that are always wiped on logout.
const _sensitiveSecureKeys = {
  'access_token',
  'refresh_token',
  'user_id_cache',
};

class LogoutOrchestrator {
  final SupabaseClient _supabase;
  final FlutterSecureStorage _secureStorage;
  final bool _fcmConfigured;
  final RequestCancellationManager _cancellationManager;

  static const _remoteTimeout = Duration(seconds: 3);

  const LogoutOrchestrator({
    required SupabaseClient supabase,
    required FlutterSecureStorage secureStorage,
    required RequestCancellationManager cancellationManager,
    bool fcmConfigured = false,
  })  : _supabase = supabase,
        _secureStorage = secureStorage,
        _cancellationManager = cancellationManager,
        _fcmConfigured = fcmConfigured;

  Future<LogoutResult> execute({
    String? userId,
    required String logoutFlow,
  }) async {
    final startTime = DateTime.now();
    final failedSteps = <String>[];

    // ── Step 0: Cancel in-flight requests (synchronous, always succeeds) ────
    _cancellationManager.cancelAll();

    // ── Step 1: Server-side session revocation (best effort) ────────────────
    try {
      await _supabase
          .rpc('logout_current_user')
          .timeout(_remoteTimeout);
    } catch (e) {
      debugPrint('[LogoutOrchestrator] server_revocation failed: $e');
      failedSteps.add('server_revocation');
    }

    // ── Step 2: FCM remote token deactivation (best effort) ─────────────────
    if (_fcmConfigured && AppConfig.fcmEnabled && userId != null) {
      try {
        final fcmToken = await FirebaseMessaging.instance
            .getToken()
            .timeout(_remoteTimeout);

        if (fcmToken != null) {
          await _supabase
              .from('push_tokens')
              .update({'is_active': false})
              .eq('token', fcmToken)
              .eq('user_id', userId)
              .timeout(_remoteTimeout);
        }
      } catch (e) {
        failedSteps.add('fcm_deactivation_remote');
      }
    }

    // ── Step 3: Kill all Realtime channels (synchronous) ────────────────────
    try {
      await _supabase.removeAllChannels();
    } catch (e) {
      failedSteps.add('realtime_disconnect');
    }

    final durationMs = DateTime.now().difference(startTime).inMilliseconds;

    return LogoutResult(
      success: failedSteps.isEmpty,
      logoutFlow: logoutFlow,
      failedSteps: failedSteps,
      durationMs: durationMs,
    );
  }

  /// Nuclear local wipe. Guaranteed to clear the session from disk.
  ///
  /// MUST be called after [execute()], or immediately on passive revocation.
  /// Uses [SignOutScope.local] to avoid making any network call — the server
  /// side was already handled in [execute()]. This prevents the signOut from
  /// hanging on a dead/revoked token.
  Future<void> forceLocalCleanup() async {
    // ── Step 1: Supabase local signOut (clears GoTrue persisted session) ─────
    //
    // This is the CRITICAL step. `SignOutScope.local` tells the SDK to:
    //   1. Clear the access_token and refresh_token from its internal storage
    //   2. Fire onAuthStateChange(signedOut)
    //   3. NOT make any network call (no risk of hanging)
    //
    // We do this FIRST because it's the one that fixes "app restart = still
    // logged in". The SDK uses its own SharedPreferences key internally;
    // we must let it handle that key itself.
    try {
      const localScope = SignOutScope.local;
      await _supabase.auth
          // Explicit because local-only cleanup must never depend on network.
          // ignore: avoid_redundant_argument_values
          .signOut(scope: localScope)
          .timeout(const Duration(seconds: 2));
      debugPrint('[LogoutOrchestrator] Supabase local signOut ✓');
    } catch (e) {
      debugPrint('[LogoutOrchestrator] Supabase local signOut failed: $e');
      // Even if this fails, continue wiping everything else.
    }

    // ── Step 2: FCM Hard Kill (removes device binding) ──────────────────────
    if (_fcmConfigured && AppConfig.fcmEnabled) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (e) {
        // Swallow — device might be offline or no token exists
      }
    }

    // ── Step 3: Wipe our own secure storage keys ────────────────────────────
    try {
      for (final key in _sensitiveSecureKeys) {
        await _secureStorage.delete(key: key);
      }
    } catch (e) {
      debugPrint('[LogoutOrchestrator] Secure storage wipe failed: $e');
    }

    // ── Step 4: Wipe SharedPreferences (preserve user prefs) ────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (!_preservedPrefKeys.contains(key)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('[LogoutOrchestrator] SharedPreferences wipe failed: $e');
    }
  }
}
