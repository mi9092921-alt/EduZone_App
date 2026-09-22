import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/request_cancellation_manager.dart';
import '../../../../core/services/push_token_registration_service.dart';
import '../../../../core/utils/global_error_handler.dart';
import '../../data/datasources/auth_remote_ds.dart';
import '../models/logout_result.dart';

/// Keys that must be preserved across logout.
/// Onboarding, theme preferences, and language settings survive.
///
/// Phase 9: `theme_mode` is the key actually written by AppThemeMode
/// (app_providers.dart); the historical `app_theme` entry matched nothing
/// and every logout silently reset the theme to system. `app_theme` and
/// `onboarding_completed` are kept for documentation of intent — no code
/// currently writes them.
///
/// Phase 10: `download_wifi_only` (StorageKeys.downloadWifiOnly) is a
/// DEVICE-scoped preference, not account state — the settings UI documents
/// it as untouched by logout, so it belongs in this set next to theme and
/// locale. Per-user keys (feature-flag cache, watched-lesson hints, progress
/// outbox) are deliberately NOT preserved: they are account-scoped and must
/// be wiped with the session.
const _preservedPrefKeys = {
  'onboarding_completed',
  'app_theme',
  'theme_mode',
  'app_locale',
  'download_wifi_only',
};

/// Keys that are always wiped on logout.
///
/// Deliberately does NOT include the per-download AES keys
/// (`enc_key_<downloadId>`, owned by EncryptionService) or the offline
/// metadata HMAC key (`offline_metadata_hmac_key`, StorageService): wiping
/// them at logout would make every redownload-free offline lesson
/// permanently unplayable for the SAME user when they sign back in on this
/// device. The residual exposure (a rooted device extracting those keys
/// between logout and the next login) is covered by two compensating
/// controls instead: OfflineAccountGuard purges another account's
/// files+keys+rows at the next AuthLoginEvent (P6.20), and
/// OfflinePolicyEngine revalidates the server entitlement at every
/// playback, so a stale key alone grants nothing without the server's
/// blessing. Documented accepted boundary — see SECURITY.md.
const _sensitiveSecureKeys = {
  'supabase_access_token',
};

/// All Supabase interactions (server revocation RPC, realtime teardown,
/// local sign-out) go through [AuthRemoteDataSource] — this orchestrator
/// only sequences them alongside FCM and local-storage cleanup.
class LogoutOrchestrator {
  final AuthRemoteDataSource _authRemoteDataSource;
  final FlutterSecureStorage _secureStorage;
  final bool _fcmConfigured;
  final RequestCancellationManager _cancellationManager;

  static const _remoteTimeout = Duration(seconds: 3);

  const LogoutOrchestrator({
    required AuthRemoteDataSource authRemoteDataSource,
    required FlutterSecureStorage secureStorage,
    required RequestCancellationManager cancellationManager,
    bool fcmConfigured = false,
  })  : _authRemoteDataSource = authRemoteDataSource,
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
      await _authRemoteDataSource.revokeCurrentSession().timeout(_remoteTimeout);
    } catch (e, st) {
      // Best-effort by design (local cleanup below still runs either
      // way), but if the server never hears about this logout, the old
      // session/token_version isn't revoked server-side either — worth
      // knowing the frequency of, not just swallowing.
      GlobalErrorHandler.logError(e, st);
      debugPrint(
        '[LogoutOrchestrator] server_revocation failed: ${e.runtimeType}',
      );
      failedSteps.add('server_revocation');
    }

    // ── Step 2: FCM remote token deactivation (best effort) ─────────────────
    if (_fcmConfigured && AppConfig.fcmEnabled && userId != null) {
      try {
        await PushTokenRegistrationService.deactivateCurrentUserToken();
      } catch (e) {
        failedSteps.add('fcm_deactivation_remote');
      }
    }

    // ── Step 3: Kill all Realtime channels (synchronous) ────────────────────
    try {
      await _authRemoteDataSource.disconnectRealtime();
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
    // logged in". The SDK's internal storage is our own `SecureLocalStorage`
    // (see core/network/supabase_client.dart, wired via
    // FlutterAuthClientOptions.localStorage) — a flutter_secure_storage-backed
    // implementation, not SharedPreferences — so this call clears the
    // Keystore/Keychain-held 'supabase_access_token' entry; we must let the
    // SDK handle that key itself rather than deleting it out from under it.
    try {
      await _authRemoteDataSource.signOutLocally().timeout(const Duration(seconds: 2));
      debugPrint('[LogoutOrchestrator] Supabase local signOut ✓');
    } catch (e, st) {
      // This is the step that actually clears the local Supabase session
      // (the Keystore/Keychain-held 'supabase_access_token' entry via our
      // SecureLocalStorage — see Step 1 of this method's doc comment above;
      // it is NOT a SharedPreferences key) — if it fails, the device can
      // come back up still "logged in" after a restart despite the user
      // having explicitly logged out. High value to know about.
      GlobalErrorHandler.logError(e, st);
      debugPrint(
        '[LogoutOrchestrator] Supabase local signOut failed: '
        '${e.runtimeType}',
      );
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
    } catch (e, st) {
      // Tokens/session material living in flutter_secure_storage failing
      // to wipe on logout is a real security-relevant event, not just an
      // engineering curiosity — worth surfacing, not only printing.
      GlobalErrorHandler.logError(e, st);
      debugPrint(
        '[LogoutOrchestrator] Secure storage wipe failed: ${e.runtimeType}',
      );
    }

    // ── Step 4: Wipe SharedPreferences (preserve user prefs) ────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (!_preservedPrefKeys.contains(key)) {
          await prefs.remove(key);
        }
      }
    } catch (e, st) {
      GlobalErrorHandler.logError(e, st);
      debugPrint(
        '[LogoutOrchestrator] SharedPreferences wipe failed: ${e.runtimeType}',
      );
    }
  }
}
