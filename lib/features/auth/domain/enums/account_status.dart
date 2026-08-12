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
  appLocked;

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
      _ => AccountStatus.active,
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
      };
}
