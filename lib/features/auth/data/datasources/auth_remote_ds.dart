import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/supabase_client.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/bind_device_result.dart';
import '../../domain/entities/user_access.dart';
import '../../domain/enums/account_status.dart';
import '../../domain/enums/user_role.dart';

/// Remote data source for all auth-related Supabase operations.
///
/// Handles raw RPC calls, Supabase Auth, and error mapping
/// from Supabase error codes to typed [AppException]s.
class AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSource([SupabaseClient? client])
    : _client = client ?? SupabaseService.client;

  // ─── check_user_access() ──────────────────────────────────────

  /// Calls the `check_user_access()` RPC and maps the response
  /// to a [UserAccess] entity with [AccountStatus].
  Future<UserAccess> checkUserAccess() async {
    try {
      final res = await _client.rpc('check_user_access');

      if (res == null) {
        return const UserAccess(status: AccountStatus.active);
      }

      final data = res as Map<String, dynamic>;
      final allowed = data['allowed'] as bool? ?? false;
      final reason = data['reason'] as String?;

      if (allowed) {
        return const UserAccess(status: AccountStatus.active);
      }

      final status = AccountStatus.fromString(reason ?? 'locked');
      return UserAccess(
        status: status,
        message: data['message'] as String?,
        until: data['until'] != null ? DateTime.tryParse(data['until']) : null,
        endsAt: data['ends_at'] != null
            ? DateTime.tryParse(data['ends_at'])
            : null,
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  // ─── Login ────────────────────────────────────────────────────

  /// Signs in with email + password.
  /// On success, fetches the user row from the `users` table.
  Future<AppUser> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const InvalidCredentialsException();
      }
      if (response.session == null) {
        throw const EmailNotConfirmedException();
      }

      // Fetch full user profile from users table
      final userData = await _client
          .from('users')
          .select()
          .eq('id', response.user!.id)
          .maybeSingle();

      if (userData == null) {
        throw const ServerException('User profile not found');
      }

      // Update last_login in the background
      await _client
          .from('users')
          .update({
            'last_login': DateTime.now().toIso8601String(),
            'last_seen_at': DateTime.now().toIso8601String(),
          })
          .eq('id', response.user!.id)
          .then((_) {})
          .catchError((_) {});

      return _mapUserData(userData);
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
    final now = DateTime.now().toIso8601String();

    try {
      // 1. Update users table
      await _client
          .from('users')
          .update({'last_seen_at': now})
          .eq('id', userId);

      // 2. Update devices table if fingerprint provided
      if (deviceFingerprint != null) {
        await _client
            .from('devices')
            .update({'last_seen': now})
            .eq('user_id', userId)
            .eq('device_id', deviceFingerprint);
      }
    } catch (e) {
      debugPrint('[Auth] Sync activity error: $e');
    }
  }

  /// Records a new session entry.
  Future<void> recordSession({
    required String userId,
    required String tenantId,
    String? deviceFingerprint,
    String? regionId,
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      // Get internal device ID if fingerprint exists
      String? internalDeviceId;
      if (deviceFingerprint != null) {
        final device = await _client
            .from('devices')
            .select('id')
            .eq('user_id', userId)
            .eq('device_id', deviceFingerprint)
            .maybeSingle();
        internalDeviceId = device?['id'] as String?;
      }

      await _client.from('sessions').insert({
        'user_id': userId,
        'tenant_id': tenantId,
        'device_id': internalDeviceId,
        'region_id': regionId,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'is_active': true,
        'started_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Auth] Record session error: $e');
    }
  }

  // ─── Bind Device ──────────────────────────────────────────────

  /// Calls `bind_device_for_current_user()` RPC.
  Future<BindDeviceResult> bindDevice(
    String deviceId,
    Map<String, dynamic> deviceInfo,
    String platform,
  ) async {
    try {
      final res = await _client.rpc(
        'bind_device_for_current_user',
        params: {
          'p_device_id': deviceId,
          'p_device_info': deviceInfo,
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
  }

  // ─── Logout ───────────────────────────────────────────────────

  /// Calls `logout_current_user()` RPC then `auth.signOut()`.
  Future<void> logout() async {
    try {
      await _client.rpc('logout_current_user');
    } catch (_) {
      // Best-effort — RPC may fail if session already expired
    }
    await _client.auth.signOut();
  }

  // ─── Validate Device ──────────────────────────────────────────

  /// Checks if a device fingerprint is registered and active for a user.
  Future<bool> validateDeviceExists(String userId, String fingerprint) async {
    try {
      final result = await _client
          .from('devices')
          .select('id')
          .eq('user_id', userId)
          .eq('device_id', fingerprint)
          .eq('is_active', true)
          .maybeSingle();

      return result != null;
    } on PostgrestException {
      return false;
    }
  }

  // ─── Get Current User ─────────────────────────────────────────

  /// Returns the currently authenticated user, or null if no session.
  Future<AppUser?> getCurrentUser() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    try {
      final userData = await _client
          .from('users')
          .select()
          .eq('id', _client.auth.currentUser!.id)
          .maybeSingle();

      if (userData == null) return null;
      return _mapUserData(userData);
    } catch (_) {
      return null;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────

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

        // Fire-and-forget background sync to database
        final updates = <String, dynamic>{};
        if (firstName != null) updates['first_name'] = firstName;
        if (lastName != null) updates['last_name'] = lastName;

        _client
            .from('users')
            .update(updates)
            .eq('id', authUser.id)
            .then((_) {
              /* Log success or ignore */
            })
            .catchError((_) {
              /* Ignore */
            });
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
      'DEBUG: Supabase Auth Error: ${e.message} (Code: ${e.statusCode})',
    );

    // AuthRetryableFetchException is thrown by the gotrue client both for:
    //   (a) real network/DNS/socket failures  -> statusCode == null
    //   (b) 5xx server errors from Supabase's own backend -> statusCode set
    // These are NOT the same problem from the user's perspective, so they
    // must not both be reported as "no internet connection".
    if (e is AuthRetryableFetchException) {
      return e.statusCode == null
          ? const NoInternetException()
          : ServerException(e.message);
    }

    final msg = e.message.toLowerCase();

    if (msg.contains('email not confirmed')) {
      return const EmailNotConfirmedException();
    }

    // Check for API key or JWT issues first to avoid mis-mapping to InvalidCredentials
    if (msg.contains('api key') ||
        msg.contains('invalid jwt') ||
        msg.contains('signature')) {
      return ServerException('Configuration error: ${e.message}');
    }

    if (msg.contains('invalid') || msg.contains('credentials')) {
      return const InvalidCredentialsException();
    }
    if (msg.contains('rate') || msg.contains('limit')) {
      return const RateLimitedException();
    }
    return ServerException(e.message);
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
    return ServerException(e.message);
  }
}
