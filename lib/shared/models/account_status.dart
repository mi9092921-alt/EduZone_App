/// Account status enum matching both the `public.users` table schema
/// and the `check_student_app_access()` RPC response states.
enum AccountStatus {
  active,
  inactive,
  suspended,
  locked,
  banned,

  /// Soft-deleted account (`deleted_at IS NOT NULL`), reported by the access
  /// gate as reason `deleted`; also covers a missing profile row
  /// (`user_not_found`). Denial is fail-closed; the local session is torn
  /// down at login/cold-start (DENIAL-SESSION-CLEANUP, 2026-09-25).
  deleted,
  maintenance,
  unauthenticated,
  appLocked,

  /// Fail-closed sentinel for any `reason`/`account_status` string this
  /// client doesn't recognize (a new server-side reason it predates, a
  /// typo, malformed data, etc).
  ///
  /// SECURITY: this must NEVER default to [active]. `checkStudentAppAccess()`
  /// (`auth_remote_ds.dart`) only reaches [fromString] when the server
  /// has already returned `allowed: false` — an explicit denial. Silently
  /// mapping an unrecognized denial reason to [active] would make
  /// `UserAccess.isAllowed` (`status == AccountStatus.active`) evaluate
  /// to `true`, granting full app access despite the server's explicit
  /// refusal — a fail-open authorization bypass reachable simply by the
  /// backend adding a new `reason` value the client hasn't shipped
  /// support for yet. [unrecognized] falls through
  /// `AuthRestricted() => AppAuthState.unauthenticated` in
  /// `app_state_provider.dart`, so the safe/default outcome for any
  /// status this client doesn't understand is "treat as logged out",
  /// never "treat as active".
  unrecognized;

  /// Deserialize from DB string or RPC reason.
  ///
  /// MAPPING-FIX (2026-09-25): `deleted`, `user_not_found`,
  /// `account_inactive` and `token_version_mismatch` previously fell through
  /// to [unrecognized], which was fail-closed but left the fresh JWT on disk
  /// at login/cold-start and showed an unexplained plain login screen. They
  /// are now explicit; see [isKeepSessionRestriction] for the session
  /// teardown rule that consumes these values.
  static AccountStatus fromString(String value) {
    return switch (value) {
      'active' => AccountStatus.active,
      'inactive' || 'account_inactive' => AccountStatus.inactive,
      'suspended' || 'account_suspended' => AccountStatus.suspended,
      'locked' || 'account_locked' => AccountStatus.locked,
      'banned' || 'account_banned' => AccountStatus.banned,
      'deleted' || 'user_not_found' => AccountStatus.deleted,
      'maintenance' || 'maintenance_mode' => AccountStatus.maintenance,
      'unauthenticated' || 'auth_required' || 'token_version_mismatch' =>
        AccountStatus.unauthenticated,
      'appLocked' || 'app_locked' => AccountStatus.appLocked,
      _ => AccountStatus.unrecognized,
    };
  }

  /// Serialize to DB string.
  String get toDbString => switch (this) {
        active => 'active',
        inactive => 'inactive',
        suspended => 'suspended',
        locked => 'locked',
        banned => 'banned',
        deleted => 'deleted',
        maintenance => 'maintenance',
        unauthenticated => 'unauthenticated',
        appLocked => 'appLocked',
        unrecognized => 'unrecognized',
      };

  /// Whether this denial must KEEP the local session alive.
  ///
  /// Only maintenance_mode and app_locked are "keep-session" restrictions:
  /// their screens re-check access against the live session on a timer, and
  /// a mid-outage restart would otherwise re-login the user into a session
  /// that is immediately destroyed again. EVERY other denial (suspended,
  /// locked, banned, deleted, inactive, token_version_mismatch,
  /// unauthenticated, unrecognized, …) represents an account or session the
  /// server has refused, so the local JWT must be torn down instead of
  /// lingering in secure storage (DENIAL-SESSION-CLEANUP, 2026-09-25).
  bool get isKeepSessionRestriction => this == maintenance || this == appLocked;
}
