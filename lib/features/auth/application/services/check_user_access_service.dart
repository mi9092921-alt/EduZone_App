import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/utils/global_error_handler.dart';
import '../../domain/entities/user_access.dart';
import '../../domain/enums/account_status.dart';

typedef AccessDeniedCallback = void Function({required String reason});
typedef AccessRestrictedCallback = void Function({required UserAccess access});

class CheckUserAccessService {
  final SupabaseClient _supabase;
  final AccessDeniedCallback _onAccessDenied;
  final AccessRestrictedCallback? _onAccessRestricted;

  Timer? _pollingTimer;
  RealtimeChannel? _realtimeChannel;
  bool _active = false;
  int _missingJwtVersionStrikeCount = 0;

  // Fixed strike threshold — do NOT make configurable. A configurable
  // threshold would let the forced-logout policy be silently weakened
  // (e.g. by a careless default change) without a code review catching it.
  static const int _maxMissingJwtVersionStrikes = 3;

  final Duration pollingInterval;

  CheckUserAccessService({
    required SupabaseClient supabase,
    required AccessDeniedCallback onAccessDenied,
    AccessRestrictedCallback? onAccessRestricted,
    this.pollingInterval = const Duration(minutes: 5),
  }) : _supabase = supabase,
       _onAccessDenied = onAccessDenied,
       _onAccessRestricted = onAccessRestricted;

  /// Start polling + Realtime listener.
  void start({required String userId, required String tenantId}) {
    if (_active) return;
    _active = true;
    _missingJwtVersionStrikeCount = 0;

    _check(); // immediate check on start
    _startPolling();
    _subscribeRealtime(userId: userId, tenantId: tenantId);
  }

  /// Stop all listeners.
  void stop() {
    _active = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(pollingInterval, (_) => _check());
  }

  /// Test-only entry point that runs a single check cycle without going
  /// through [start] (which also subscribes to Realtime — undesirable in
  /// unit tests). Marks the service active so `_check()`'s guard doesn't
  /// short-circuit, matching real usage where `start()` always runs first.
  @visibleForTesting
  Future<void> checkNow() async {
    _active = true;
    await _check();
  }

  /// Realtime subscription on the users table for security changes.
  /// Also detects token_version bumps (forced logout by admin).
  void _subscribeRealtime({required String userId, required String tenantId}) {
    _realtimeChannel = _supabase
        .channel('user_security_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            if (!_active) return;

            final newStatusStr = payload.newRecord['account_status'] as String?;
            final status = AccountStatus.fromString(newStatusStr ?? 'active');
            final oldVersion = payload.oldRecord['token_version'] as int?;
            final newVersion = payload.newRecord['token_version'] as int?;
            final jwtVersion = _currentJwtTokenVersion;

            debugPrint('[Security] Realtime change detected. DB Version: $newVersion, JWT Version: $jwtVersion');

            // token_version bump = forced logout
            if (_isForcedLogoutVersionChange(
              oldVersion: oldVersion,
              newVersion: newVersion,
              jwtVersion: jwtVersion,
            )) {
              _onAccessDenied(reason: 'token_version_mismatch');
              return;
            }

            if (status == AccountStatus.banned ||
                status == AccountStatus.locked) {
              _onAccessDenied(reason: 'account_${status.toDbString}');
              return;
            }

            if (status == AccountStatus.appLocked) {
              _onAccessRestricted?.call(access: UserAccess(status: status));
            }
          },
        )
        .subscribe();
  }

  Future<void> _check() async {
    if (!_active) return;
    try {
      final response = await _supabase.rpc('check_user_access');
      if (!_active) return;

      final data = response as Map<String, dynamic>;

      final dbTokenVersion = data['token_version'] as int?;
      final jwtVersion = _currentJwtTokenVersion;

      if (dbTokenVersion != null && jwtVersion != null) {
        if (dbTokenVersion > jwtVersion) {
          debugPrint('[Security] Version mismatch: DB($dbTokenVersion) > JWT($jwtVersion)');
          _resetMissingJwtVersionStrikes();
          _onAccessDenied(reason: 'token_version_mismatch');
          return;
        }

        _resetMissingJwtVersionStrikes();
      } else if (dbTokenVersion != null && jwtVersion == null) {
        // JWT is missing or lacks the token_version claim while DB has one.
        // This is either a transient race (right after login/refresh, before
        // the Auth Hook has run) or a genuinely misconfigured/broken Hook.
        // We don't force logout on the first occurrence to avoid false
        // positives, but 3 consecutive occurrences (~15 min of polling) means
        // it's not transient — force logout to keep the forced-logout
        // guarantee intact.
        _missingJwtVersionStrikeCount += 1;
        debugPrint(
          '[Security] jwtVersion is NULL. Strike $_missingJwtVersionStrikeCount/'
          '$_maxMissingJwtVersionStrikes. Check Supabase Auth Hooks.',
        );

        if (_missingJwtVersionStrikeCount >= _maxMissingJwtVersionStrikes) {
          debugPrint('[Security] Forced logout after consecutive missing jwtVersion checks.');
          _onAccessDenied(reason: 'token_version_mismatch');
          return;
        }
      } else {
        _resetMissingJwtVersionStrikes();
      }

      if (data['allowed'] == false) {
        final reason = data['reason'] as String? ?? 'unknown';
        final status = AccountStatus.fromString(reason);
        final access = UserAccess(
          status: status,
          message: data['message'] as String?,
          until: data['until'] != null ? DateTime.tryParse(data['until']) : null,
          endsAt: data['ends_at'] != null
              ? DateTime.tryParse(data['ends_at'])
              : null,
        );

        if (!_active) return;

        // maintenance_mode/app_locked: show UI but DO NOT logout
        if (status == AccountStatus.maintenance ||
            status == AccountStatus.appLocked) {
          _onAccessRestricted?.call(access: access);
          return;
        }

        _onAccessDenied(reason: reason);
      }
    } catch (e, st) {
      // This is the background polling/Realtime security-monitoring loop
      // (token_version checks), not a user-triggered call — an unexpected
      // failure here directly affects whether revocation/version-mismatch
      // detection is actually running.
      GlobalErrorHandler.logError(e, st);
      debugPrint('[Security] Check error: $e');
    }
  }

  void _resetMissingJwtVersionStrikes() {
    _missingJwtVersionStrikeCount = 0;
  }

  bool _isForcedLogoutVersionChange({
    required int? oldVersion,
    required int? newVersion,
    required int? jwtVersion,
  }) {
    if (newVersion == null) {
      return false;
    }

    // If we have old/new from Realtime, use them (Requires REPLICA IDENTITY FULL)
    if (oldVersion != null && newVersion > oldVersion) {
      return true;
    }

    // Fallback: Compare with what's inside our current JWT
    if (jwtVersion != null && newVersion > jwtVersion) {
      return true;
    }

    return false;
  }

  int? get _currentJwtTokenVersion {
    final session = _supabase.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || token.isEmpty) {
      return null;
    }

    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    final payload = parts[1];
    final normalizedPayload = payload.replaceAll('-', '+').replaceAll('_', '/');
    final padding = '=' * ((4 - (normalizedPayload.length % 4)) % 4).toInt();

    try {
      final decoded = utf8.decode(
        base64Url.decode(normalizedPayload + padding),
      );
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      // 1. Check root level (standard for our Hook)
      final directVersion = json['token_version'];
      if (directVersion is int) return directVersion;
      if (directVersion is String) return int.tryParse(directVersion);

      // 2. Check app_metadata (common fallback)
      final appMetadata = json['app_metadata'];
      if (appMetadata is Map) {
        final metadataVersion = appMetadata['token_version'];
        if (metadataVersion is int) return metadataVersion;
        if (metadataVersion is String) return int.tryParse(metadataVersion);
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
