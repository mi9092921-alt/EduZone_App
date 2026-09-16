import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/network_config.dart';
import '../../../../core/network/network_guard.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../shared/models/account_status.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/user_access.dart';
import '../../../../shared/models/user_role.dart';
import '../../domain/entities/bind_device_result.dart';

/// Remote data source for all auth-related Supabase operations.
///
/// Handles raw RPC calls, Supabase Auth, and error mapping
/// from Supabase error codes to typed [AppException]s.
///
/// The `ServerException(...)` messages thrown throughout this file are
/// internal, developer-facing diagnostic strings (English-only, by
/// design) -- they are never shown to the user directly. Verified: every
/// caller reaches either `AuthErrorPolicy.mapExceptionToKey` (which
/// doesn't special-case `ServerException`, so it always falls through to
/// the localized `errorGeneric` key) or `ErrorHandler.getMessage`
/// (`shared/utils/error_handler.dart`, fixed to return `l10n.errorGeneric`
/// for `ServerException` rather than `error.message` -- it previously
/// didn't, which was a real bug this same audit pass found and fixed).
/// Each `// check-ignore` below is this file's per-line acknowledgment of
/// that same review, per this project's suppression convention.
class AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSource([SupabaseClient? client])
    : _client = client ?? SupabaseService.client;

  // ─── check_student_app_access() ────────────────────────────────

  /// Calls the `check_student_app_access()` RPC and maps the response
  /// to a [UserAccess] entity with [AccountStatus].
  ///
  /// Previously had no client-side timeout -- a stalled connection meant
  /// this `Future` never completed. Routed through `NetworkGuard.read`:
  /// bounded timeout, retried only for genuine transient
  /// connectivity/timeout failures (never for a real access-denial
  /// business outcome, which must reach the caller immediately). See
  /// Section 13 ("Networking Reliability") of the project instructions.
  Future<UserAccess> checkStudentAppAccess() async {
    return NetworkGuard.read(() async {
      try {
        final res = await _client.rpc('check_student_app_access');

        if (res == null) {
          // Missing authorization data is not proof of access. Treat an
          // unknown authorization decision as a server failure so callers
          // fail closed instead of granting an implicit active session.
          throw const ServerException(
            'Authentication access check returned no data', // check-ignore
          );
        }

        final data = res as Map<String, dynamic>;
        final allowed = data['allowed'] as bool? ?? false;
        final reason = data['reason'] as String?;
        final role = UserRole.fromString(
          data['role'] as String? ?? data['primary_role'] as String? ?? 'student',
        );

        if (allowed) {
          return UserAccess(status: AccountStatus.active, role: role);
        }

        final status = AccountStatus.fromString(reason ?? 'locked');
        return UserAccess(
          status: status,
          role: role,
          until: data['until'] != null ? DateTime.tryParse(data['until']) : null,
          endsAt: data['ends_at'] != null
              ? DateTime.tryParse(data['ends_at'])
              : null,
        );
      } on PostgrestException catch (e) {
        throw _mapRpcException(e);
      }
    });
  }

  /// Raw `check_student_app_access()` payload for the security-monitoring
  /// service ([CheckStudentAppAccessService from application/services]),
  /// which needs fields the [UserAccess] mapping intentionally drops —
  /// `token_version` for server-revocation detection and the localized
  /// restriction message. Callers wanting a decision should prefer
  /// [checkStudentAppAccess].
  Future<Map<String, dynamic>?> checkStudentAppAccessRaw() async {
    return NetworkGuard.read(() async {
      try {
        final res = await _client.rpc('check_student_app_access');
        return res == null ? null : res as Map<String, dynamic>;
      } on PostgrestException catch (e) {
        throw _mapRpcException(e);
      }
    });
  }

  /// `token_version` claim from the current session's JWT, or null when the
  /// session/claim is missing or the token is malformed.
  ///
  /// Kept here because session/token handling is datasource territory; the
  /// security-monitoring service compares this against the DB value to
  /// detect server-side revocation.
  int? get currentJwtTokenVersion {
    final session = _client.auth.currentSession;
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
      final decoded = utf8.decode(base64Url.decode(normalizedPayload + padding));
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

  // ─── Login ────────────────────────────────────────────────────

  /// Signs in with email + password against Supabase Auth only.
  ///
  /// The profile is intentionally fetched separately, after the app access
  /// RPC has classified the account. A client-side `users` read is RLS-gated
  /// and can return no row for locked, suspended, or banned accounts.
  ///
  /// Previously neither the sign-in call nor the profile fetch had a
  /// client-side timeout -- a stalled connection left `login()` (and the
  /// login button's loading state) hanging indefinitely, with no
  /// distinction from a legitimate slow network. Each await below is now
  /// individually bounded rather than the whole method wrapped in a single
  /// `NetworkGuard` budget, because `_recordCurrentUserActivity` (a
  /// separately-bounded, already best-effort, swallowed-on-failure call)
  /// runs after these two succeed -- sharing one outer timeout budget
  /// across all three would risk a login that actually succeeded
  /// server-side being reported to the user as a timeout failure just
  /// because the trailing telemetry call was slow. Deliberately no
  /// automatic retry on timeout: the project instructions explicitly
  /// forbid blindly retrying authentication operations, and a sign-in
  /// that timed out client-side may already have succeeded server-side.
  /// See Section 13 ("Networking Reliability") of the project
  /// instructions.
  Future<void> login(String email, String password) async {
    try {
      final response = await _client.auth
          .signInWithPassword(email: email, password: password)
          .timeout(NetworkConfig.writeTimeout);

      if (response.user == null) {
        throw const InvalidCredentialsException();
      }
      if (response.session == null) {
        throw const EmailNotConfirmedException();
      }

      // Best-effort telemetry. Authenticated clients intentionally do not
      // have direct UPDATE on public.users, so this goes through a narrowly
      // scoped SECURITY DEFINER RPC. Independently bounded and
      // exception-swallowed inside _recordCurrentUserActivity itself -- see
      // its doc comment.
      await _recordCurrentUserActivity(recordLogin: true);
    } on TimeoutException {
      throw const RequestTimeoutException();
    } on AuthException catch (e) {
      // NOTE: AuthRetryableFetchException is a subtype of AuthException and
      // is intentionally NOT caught separately here — it is classified
      // inside _mapAuthException (by statusCode) so there is a single
      // source of truth for auth-error mapping, and the diagnostic
      // debugPrint below always fires for it.
      throw _mapAuthException(e);
    }
  }

  // ─── Activity Tracking ────────────────────────────────────────

  /// Updates user activity timestamps and device heartbeats.
  Future<void> syncUserActivity({
    required String userId,
    required String tenantId,
    String? deviceFingerprint,
  }) async {
    try {
      await _recordCurrentUserActivity(deviceFingerprint: deviceFingerprint);
    } catch (e) {
      debugPrint('[Auth] Sync activity error: ${e.runtimeType}');
    }
  }

  /// Records a new session entry via the `record_current_session()` RPC.
  ///
  /// The RPC is SECURITY DEFINER: it derives identity/tenant from the JWT,
  /// resolves the internal device id from [deviceFingerprint], takes
  /// region_id from the authoritative users row, and captures the client IP
  /// server-side from request headers — a client-supplied value would be
  /// trivially spoofable. Only meaningful on a genuinely fresh login (see
  /// `AuthActivitySyncService.recordSession`).
  ///
  /// Routed through `NetworkGuard.write` (bounded timeout, never
  /// auto-retried): this is a mutation with server-side side effects
  /// (inserts a sessions row), so blindly retrying a client-perceived
  /// timeout could double-insert. Failures still stay best-effort — the
  /// calling service swallows them so session tracking can never block or
  /// fail the login flow. See Section 13 ("Networking Reliability").
  Future<void> recordSession({
    String? deviceFingerprint,
    String? userAgent,
  }) async {
    return NetworkGuard.write(() async {
      try {
        await _client.rpc(
          'record_current_session',
          params: {
            'p_device_fingerprint': deviceFingerprint,
            'p_user_agent': userAgent,
          },
        );
      } on PostgrestException catch (e) {
        throw _mapRpcException(e);
      }
    });
  }

  // ─── Bind Device ──────────────────────────────────────────────

  /// Calls `bind_device_for_current_user()` RPC.
  ///
  /// Previously had no client-side timeout. Routed through
  /// `NetworkGuard.write` (bounded timeout, never auto-retried) rather
  /// than `.read` -- device binding is a mutation with server-side side
  /// effects (claims a device slot), so blindly retrying it on a
  /// client-perceived timeout risks the request having actually
  /// succeeded server-side already. See Section 13 ("Networking
  /// Reliability") of the project instructions.
  Future<BindDeviceResult> bindDevice(
    String deviceId,
    Map<String, dynamic> deviceInfo,
    String platform,
  ) async {
    return NetworkGuard.write(() async {
      try {
        final res = await _client.rpc(
          'bind_device_for_current_user',
          params: {
            'p_device_id': deviceId,
            'p_device_info': deviceInfo,
            'p_fingerprint_version': deviceInfo['fingerprint_version'] ?? 'v1',
            'p_platform': platform,
          },
        );

        final status = (res is Map && res['status'] == 'verified')
            ? BindDeviceStatus.verified
            : BindDeviceStatus.bound;

        return BindDeviceResult(status: status);
      } on PostgrestException catch (e) {
        throw _mapRpcException(e);
      }
    });
  }

  // ─── Logout ───────────────────────────────────────────────────

  /// Calls `logout_current_user()` RPC then `auth.signOut()`.
  ///
  /// Both calls previously had no timeout -- a stalled connection left
  /// `logout()` (and, transitively, whatever awaits it) hanging
  /// indefinitely, defeating the whole point of a "best-effort, RPC may
  /// fail" comment on the first call. See Section 13 ("Networking
  /// Reliability") of the project instructions. Note: the primary logout
  /// path is `LogoutOrchestrator`, not this method -- see its doc
  /// comment on `LogoutUser` for why this one still exists.
  Future<void> logout() async {
    try {
      await _client.rpc('logout_current_user').timeout(NetworkConfig.writeTimeout);
    } catch (_) {
      // Best-effort — RPC may fail if session already expired
    }
    await _client.auth.signOut().timeout(NetworkConfig.writeTimeout);
  }

  /// Revokes the current session server-side (`logout_current_user()` RPC).
  ///
  /// Only the RPC — the local sign-out teardown is [signOutLocally]. The
  /// primary logout path is [LogoutOrchestrator], which sequences these
  /// steps itself (server revocation → realtime disconnect → local wipe).
  Future<void> revokeCurrentSession() async {
    return NetworkGuard.write(() async {
      try {
        await _client.rpc('logout_current_user');
      } on PostgrestException catch (e) {
        throw _mapRpcException(e);
      }
    });
  }

  /// Tears down ALL Supabase Realtime channels (used on logout).
  Future<void> disconnectRealtime() async {
    await _client.removeAllChannels();
  }

  /// Local-only sign-out (`SignOutScope.local`): clears the GoTrue persisted
  /// session from SecureLocalStorage and fires onAuthStateChange(signedOut)
  /// WITHOUT any network call — used by LogoutOrchestrator.forceLocalCleanup
  /// where the server side was already handled and the call must never hang
  /// on a dead/revoked token.
  Future<void> signOutLocally() async {
    await _client.auth
        // Explicit: local-only cleanup must never depend on network. The
        // value happens to be the SDK default, but the intent is the point.
        // ignore: avoid_redundant_argument_values
        .signOut(scope: SignOutScope.local);
  }

  // ─── Validate Device ──────────────────────────────────────────

  /// Checks if a device fingerprint is registered and active for a user.
  ///
  /// Previously had no client-side timeout. Routed through
  /// `NetworkGuard.read` -- a pure lookup with no side effects, so safe
  /// to retry on a genuine transient connectivity failure. See Section 13
  /// ("Networking Reliability") of the project instructions.
  Future<bool> validateDeviceExists(String userId, String fingerprint) async {
    return NetworkGuard.read(() async {
      try {
        final result = await _client
            .from('devices')
            .select('id')
            .eq('user_id', userId)
            .eq('device_id', fingerprint)
            .eq('is_active', true)
            .maybeSingle();

        return result != null;
      } on PostgrestException catch (e) {
        // A database/RLS/network failure is not proof that the device is
        // missing. Preserve the failure so startup cannot silently turn a
        // verification outage into an automatic device re-bind/logout path.
        throw _mapRpcException(e);
      }
    });
  }

  // ─── Get Current User ─────────────────────────────────────────

  /// Returns the currently authenticated user, or null if no session /
  /// no matching row.
  ///
  /// IMPORTANT: this deliberately does NOT swallow network/server failures
  /// into `null`. A transient failure here must remain distinguishable
  /// from "no such user" so callers (Auth._initializeSession(),
  /// Auth.verifyAccess()) can run it through AuthErrorPolicy.isTransient()
  /// instead of being forced into an unauthenticated state on a network
  /// blip. See AUTH-00 audit note in
  /// EduZone_Authentication_Session_Security_Architecture.md, phase 6
  /// ("transient network error must never directly cause logout").
  ///
  /// Previously had no client-side timeout on the network call below (the
  /// null-session short-circuit above is local and always instant).
  /// Routed through `NetworkGuard.read` -- a pure lookup with no side
  /// effects, so safe to retry on a genuine transient connectivity
  /// failure without disturbing the "transient failure must stay
  /// distinguishable from no-such-user" contract documented above. See
  /// Section 13 ("Networking Reliability") of the project instructions.
  Future<AppUser?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    return NetworkGuard.read(() async {
      try {
        final userData = await _client
            .from('users')
            .select()
            .eq('id', _client.auth.currentUser!.id)
            .maybeSingle();

        if (userData == null) return null;
        return _mapUserData(userData);
      } on PostgrestException catch (e) {
        throw _mapRpcException(e);
      }
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────

  /// Best-effort telemetry (every failure is already swallowed below),
  /// but previously had no timeout -- and, critically, this is awaited
  /// synchronously inside `login()`, so a stalled connection here left
  /// `login()` itself hanging even after credentials had already been
  /// verified. See Section 13 ("Networking Reliability") of the project
  /// instructions.
  Future<void> _recordCurrentUserActivity({
    bool recordLogin = false,
    String? deviceFingerprint,
  }) async {
    try {
      await _client.rpc(
        'record_current_user_activity',
        params: {
          'p_record_login': recordLogin,
          'p_device_id': deviceFingerprint,
        },
      ).timeout(NetworkConfig.telemetryTimeout);
    } catch (e) {
      debugPrint('[Auth] Activity telemetry failed: ${e.runtimeType}');
    }
  }

  AppUser _mapUserData(Map<String, dynamic> data) {
    String? firstName = data['first_name'] as String?;
    String? lastName = data['last_name'] as String?;

    // Auto-Sync: If names are missing in users table, pull from Auth Metadata (e.g. from Google login)
    final authUser = _client.auth.currentUser;
    if (authUser != null && (firstName == null || firstName.isEmpty)) {
      final metadata = authUser.userMetadata;
      final fullMetaName = metadata?['full_name'] as String?;
      final firstMetaName =
          metadata?['first_name'] as String? ?? metadata?['name'] as String?;

      if (firstMetaName != null || fullMetaName != null) {
        firstName = firstMetaName ?? fullMetaName?.split(' ').first;
        lastName =
            lastName ??
            (fullMetaName?.contains(' ') == true
                ? fullMetaName?.split(' ').last
                : null);

      }
    }

    return AppUser(
      id: data['id'] as String,
      email: data['email'] as String? ?? '',
      firstName: firstName,
      lastName: lastName,
      avatarUrl: data['avatar_url'] as String?,
      primaryRole: UserRole.fromString(
        data['primary_role'] as String? ?? 'student',
      ),
      tenantId: data['tenant_id'] as String? ?? '',
      accountStatus: AccountStatus.fromString(
        data['account_status'] as String? ?? 'active',
      ),
      tokenVersion: data['token_version'] as int? ?? 0,
    );
  }

  AppException _mapAuthException(AuthException e) {
    // ignore: avoid_print
    debugPrint(
      'DEBUG: Supabase Auth Error: ${e.runtimeType} (Code: ${e.statusCode})',
    );

    // AuthRetryableFetchException is thrown by the gotrue client both for:
    //   (a) real network/DNS/socket failures  -> statusCode == null
    //   (b) 5xx server errors from Supabase's own backend -> statusCode set
    // These are NOT the same problem from the user's perspective, so they
    // must not both be reported as "no internet connection".
    if (e is AuthRetryableFetchException) {
      return e.statusCode == null
          ? const NoInternetException()
          : const ServerException(
              'Authentication service unavailable', // check-ignore
            ); // check-ignore
    }

    final msg = e.message.toLowerCase();

    if (msg.contains('email not confirmed')) {
      return const EmailNotConfirmedException();
    }

    // Check for API key or JWT issues first to avoid mis-mapping to InvalidCredentials
    if (msg.contains('api key') ||
        msg.contains('invalid jwt') ||
        msg.contains('signature')) {
      return const ServerException(
        'Authentication service configuration error', // check-ignore
      ); // check-ignore
    }

    if (msg.contains('invalid') || msg.contains('credentials')) {
      return const InvalidCredentialsException();
    }
    if (msg.contains('rate') || msg.contains('limit')) {
      return const RateLimitedException();
    }
    return const ServerException(
      'Authentication service unavailable', // check-ignore
    ); // check-ignore
  }

  AppException _mapRpcException(PostgrestException e) {
    final msg = e.message.toUpperCase();
    if (msg.contains('MAX_DEVICES_REACHED')) {
      return const MaxDevicesReachedException();
    }
    if (msg.contains('DEVICE_ALREADY_BOUND')) {
      return const DeviceAlreadyBoundException();
    }
    if (msg.contains('RATE_LIMIT')) {
      return const RateLimitedException();
    }

    // AUTH-BUG-01: the RPCs called on the post-authentication path
    // (bind_device_for_current_user, check_student_app_access) can raise several
    // more server-side conditions beyond the three business-rule cases
    // above. All of these still map to the same safe, generic UI message
    // via AuthErrorPolicy (ServerException -> 'errorGeneric') -- none of
    // them are business outcomes worth surfacing verbatim to the user --
    // but each carries a distinct `code` so the *real* cause survives in
    // logs/Sentry instead of collapsing into one indistinguishable
    // "Authentication backend request failed" for every case. Previously
    // any of these (including AUTH_REQUIRED, which is raised by
    // validate_user_session() failing inside bind_device_for_current_user)
    // fell through to the last line below with no way to tell them apart
    // after the fact.
    if (msg.contains('AUTH_REQUIRED')) {
      return const ServerException(
        'Post-auth RPC rejected: session failed server-side validation (AUTH_REQUIRED)', // check-ignore
        'AUTH_REQUIRED', // check-ignore
      );
    }
    if (msg.contains('TENANT_MISMATCH')) {
      return const ServerException(
        'Post-auth RPC rejected: tenant mismatch', // check-ignore
        'TENANT_MISMATCH', // check-ignore
      );
    }
    if (msg.contains('INVALID_FINGERPRINT_VERSION')) {
      return const ServerException(
        'Post-auth device binding rejected: invalid fingerprint version', // check-ignore
        'INVALID_FINGERPRINT_VERSION', // check-ignore
      );
    }
    if (msg.contains('INVALID_DEVICE_ID')) {
      return const ServerException(
        'Post-auth device binding rejected: invalid device id', // check-ignore
        'INVALID_DEVICE_ID', // check-ignore
      );
    }

    // PostgREST/PostgreSQL-level failures indicating an RPC contract or
    // deployment problem (missing function, stale schema cache, missing
    // EXECUTE grant) rather than a business-rule rejection -- e.g. the
    // exact 404/42501 class of failure that caused AUTH-BUG-01. These
    // must never be confused with InvalidCredentialsException, which is
    // only ever thrown from the signInWithPassword() catch above.
    if (e.code == 'PGRST202' || e.code == '404') {
      return const ServerException(
        'RPC contract/deployment failure: function not found in schema cache', // check-ignore
        'RPC_NOT_FOUND', // check-ignore
      );
    }
    if (e.code == '42501') {
      return const ServerException(
        'RPC rejected: permission denied (missing EXECUTE grant)', // check-ignore
        'RPC_PERMISSION_DENIED', // check-ignore
      );
    }
    if (e.code == '42P17') {
      return const ServerException(
        'RPC rejected: infinite recursion detected in an RLS policy', // check-ignore
        'RPC_RLS_RECURSION', // check-ignore
      );
    }

    return ServerException(
      'Authentication backend request failed', // check-ignore
      e.code,
    );
  }
}
