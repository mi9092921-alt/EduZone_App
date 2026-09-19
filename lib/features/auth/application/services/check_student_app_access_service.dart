import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_exception_mapper.dart';
import '../../../../core/utils/global_error_handler.dart';
import '../../../../shared/models/account_status.dart';
import '../../../../shared/models/user_access.dart';
import '../../data/datasources/auth_remote_ds.dart';

typedef AccessDeniedCallback = void Function({required String reason});
typedef AccessRestrictedCallback = void Function({required UserAccess access});

/// Reviewed seam: this service keeps a raw [SupabaseClient] for REALTIME
/// channel lifecycle only ([_subscribeRealtime]/[stop]) — channels are
/// persistent subscriptions with callbacks, not data queries; extracting
/// them into a datasource would rewrite the security-critical test suite
/// for zero behavioral gain. The data access itself (the check RPC and the
/// session JWT's token_version claim) lives in [AuthRemoteDataSource].
class CheckStudentAppAccessService {
  final SupabaseClient _supabase;
  final AuthRemoteDataSource _authRemoteDataSource;
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

  CheckStudentAppAccessService({
    required SupabaseClient supabase,
    required AuthRemoteDataSource authRemoteDataSource,
    required AccessDeniedCallback onAccessDenied,
    AccessRestrictedCallback? onAccessRestricted,
    this.pollingInterval = const Duration(minutes: 5),
  }) : _supabase = supabase,
       _authRemoteDataSource = authRemoteDataSource,
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
            try {
              _handleRealtimeSecurityChange(payload);
            } catch (e, st) {
              // A malformed/unexpected realtime payload must never kill the
              // channel subscription: an exception escaping this callback can
              // break event delivery for the channel's lifetime, silently
              // disabling realtime revocation detection until the next app
              // start (the 5-minute poll is the only remaining path).
              // Realtime is an optimization over the poll; degrade to it
              // rather than losing the channel.
              GlobalErrorHandler.logError(e, st);
              debugPrint(
                '[Security] Realtime callback error: ${e.runtimeType}',
              );
            }
          },
        )
        .subscribe();
  }

  /// Realtime payload handler, extracted from the subscription callback so
  /// the body above can stay exception-contained.
  ///
  /// Hardened in the same pass as the poll path (EDUZONE-K follow-up):
  /// `token_version` is accepted as int OR String on BOTH paths — the
  /// realtime branch previously used a bare `as int?` cast, which threw a
  /// TypeError whenever the RPC's transient text-typing behavior showed up
  /// in the realtime payload, silently skipping the forced-logout check.
  /// Also handles `maintenance_mode` (previously only the poll did), so an
  /// admin-initiated maintenance transition shows immediately instead of
  /// waiting up to [pollingInterval].
  void _handleRealtimeSecurityChange(PostgresChangePayload payload) {
    final newStatusStr = payload.newRecord['account_status'] as String?;
    final status = AccountStatus.fromString(newStatusStr ?? 'active');
    final oldVersion = resolveTokenVersion(payload.oldRecord['token_version']);
    final newVersion = resolveTokenVersion(payload.newRecord['token_version']);
    final jwtVersion = _currentJwtTokenVersion;

    // kDebugMode-gated: token_version values are security-relevant
    // state; debugPrint survives release builds and would surface
    // them in device logcat.
    if (kDebugMode) {
      debugPrint(
        '[Security] Realtime change detected. '
        'DB Version: $newVersion, JWT Version: $jwtVersion',
      );
    }

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
        status == AccountStatus.locked ||
        status == AccountStatus.suspended) {
      _onAccessDenied(reason: 'account_${status.toDbString}');
      return;
    }

    if (status == AccountStatus.appLocked || status == AccountStatus.maintenance) {
      _onAccessRestricted?.call(access: UserAccess(status: status));
    }
  }

  /// Accepts `token_version` as int OR numeric String and returns it as
  /// int (null otherwise). Shared by the realtime payload handler and the
  /// poll path below so the two detection paths can never drift apart —
  /// see the "string token_version" regression note in
  /// check_student_app_access_service_test.dart.
  @visibleForTesting
  static int? resolveTokenVersion(Object? raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  Future<void> _check() async {
    if (!_active) return;
    try {
      final response = await _authRemoteDataSource.checkStudentAppAccessRaw();
      if (!_active) return;
      if (response == null) {
        // The datasource fails closed on a missing payload; a null here can
        // only mean the RPC itself returned null — treat it like any other
        // unexpected payload: log and skip this tick (next poll retries).
        debugPrint('[Security] check_student_app_access returned null');
        return;
      }

      final data = response;

      // token_version must be accepted as int OR String: the RPC briefly
      // emitted it as a JSON string when the schema declared the variable
      // text (fixed in the canonical schema), and a cast failure here would
      // abort the whole check — killing maintenance/app_locked handling and
      // mismatch detection — before the allowed/denied decision below.
      final dbTokenVersion = resolveTokenVersion(data['token_version']);
      final jwtVersion = _currentJwtTokenVersion;

      if (dbTokenVersion != null && jwtVersion != null) {
        if (dbTokenVersion > jwtVersion) {
          if (kDebugMode) {
            debugPrint(
              '[Security] Version mismatch: DB($dbTokenVersion) > JWT($jwtVersion)',
            );
          }
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
        if (kDebugMode) {
          debugPrint(
            '[Security] jwtVersion is NULL. Strike '
            '$_missingJwtVersionStrikeCount/$_maxMissingJwtVersionStrikes. '
            'Check Supabase Auth Hooks.',
          );
        }

        if (_missingJwtVersionStrikeCount >= _maxMissingJwtVersionStrikes) {
          if (kDebugMode) {
          debugPrint(
            '[Security] Forced logout after consecutive missing '
            'jwtVersion checks.',
          );
        }
          _onAccessDenied(reason: 'token_version_mismatch');
          return;
        }
      } else {
        _resetMissingJwtVersionStrikes();
      }

      // Fail-visible on a malformed decision: `allowed` must be a bool.
      // A missing/non-bool key means the server contract broke — silently
      // skipping the tick (the old `== false` check) left a revoked user
      // polling forever with no signal anywhere. It is deliberately NOT
      // treated as a denial either (a malformed payload is not the server
      // saying "no", and a forced logout on one bad tick would be harsh);
      // the failure is reported to Sentry and the next tick retries.
      final allowedFlag = data['allowed'];
      if (allowedFlag is! bool) {
        GlobalErrorHandler.logError(
          StateError(
            'check_student_app_access returned a malformed `allowed` key: '
            '${allowedFlag.runtimeType}',
          ),
          StackTrace.current,
        );
        debugPrint('[Security] Malformed `allowed` payload — skipping tick');
        return;
      }

      if (!allowedFlag) {
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
      // A revoked session can surface here as a RAISED error rather than a
      // returned `allowed: false` payload (e.g. the server-side session
      // validation inside the RPC raises Postgres 28000 / AUTH_REQUIRED
      // instead of answering). The mapper (or the datasource) classifies
      // that as [SessionRevokedException]; treating it as a skip-and-retry
      // tick would leave a revoked user issuing authenticated requests for
      // as long as the poll keeps failing, so it must be handled as an
      // access denial, exactly like the payload-driven path above.
      final classified = NetworkExceptionMapper.map(e);
      if (classified is SessionRevokedException) {
        if (_active) {
          debugPrint(
            '[Security] Poll detected session revocation '
            '(${classified.code}) — forcing sign-out.',
          );
          _onAccessDenied(reason: 'session_revoked');
        }
        return;
      }

      // This is the background polling/Realtime security-monitoring loop
      // (token_version checks), not a user-triggered call — an unexpected
      // failure here directly affects whether revocation/version-mismatch
      // detection is actually running, so genuine failures must still
      // reach Sentry.
      //
      // But this loop fires unconditionally every [pollingInterval]
      // (default 5 min) for as long as the service is active, including
      // while the device has no connectivity at all — in which case
      // `_supabase.rpc()` fails with a DNS/socket-level error on *every
      // tick* for as long as the device stays offline. That surfaces as a
      // plain `ClientException` wrapping a `SocketException`/`OSError`
      // (not a `PostgrestException`, since the request never reached
      // Supabase), and is expected, non-actionable environment noise —
      // not a defect in this service. Forwarding it to Sentry unfiltered
      // turns "user's phone lost signal" into a recurring production
      // "error" every 5 minutes, which drowns out real signal (Section 15:
      // observability must stay useful, not just complete). Mirrors how
      // `AuthErrorPolicy.isTransient` / `login()`'s catch block in
      // `auth_provider.dart` already keep connectivity failures out of
      // Sentry while still surfacing genuinely unexpected errors.
      final isConnectivityFailure = classified is NoInternetException ||
          classified is RequestTimeoutException;

      if (!isConnectivityFailure) {
        GlobalErrorHandler.logError(e, st);
      }
      debugPrint(
        '[Security] Check error: ${e.runtimeType}'
        '${isConnectivityFailure ? ' (connectivity — not reported to Sentry)' : ''}',
      );
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

  int? get _currentJwtTokenVersion => _authRemoteDataSource.currentJwtTokenVersion;
}
