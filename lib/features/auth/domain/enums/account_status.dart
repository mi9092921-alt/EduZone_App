/// Account status enum matching both the `public.users` table schema
/// and the `check_user_access()` RPC response states.
enum AccountStatus {
  active,
  inactive,
  suspended,
  locked,
  banned,
  maintenance,
  unauthenticated,
  appLocked,

  /// Fail-closed sentinel for any `reason`/`account_status` string this
  /// client doesn't recognize (a new server-side reason it predates, a
  /// typo, malformed data, etc).
  ///
  /// SECURITY: this must NEVER default to [active]. `checkUserAccess()`
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
  static AccountStatus fromString(String value) {
    return switch (value) {
      'active' => AccountStatus.active,
      'inactive' => AccountStatus.inactive,
      'suspended' || 'account_suspended' => AccountStatus.suspended,
      'locked' || 'account_locked' => AccountStatus.locked,
      'banned' || 'account_banned' => AccountStatus.banned,
      'maintenance' || 'maintenance_mode' => AccountStatus.maintenance,
      'unauthenticated' || 'auth_required' => AccountStatus.unauthenticated,
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
        maintenance => 'maintenance',
        unauthenticated => 'unauthenticated',
        appLocked => 'appLocked',
        unrecognized => 'unrecognized',
      };
}
