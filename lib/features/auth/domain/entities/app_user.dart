import 'package:equatable/equatable.dart';
import '../enums/account_status.dart';
import '../enums/user_role.dart';

/// Core user entity for the authenticated user.
///
/// Fields match the `users` table columns returned by
/// `check_user_access()` and profile queries.
class AppUser extends Equatable {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final UserRole primaryRole;
  final String tenantId;
  final String regionId;
  final AccountStatus accountStatus;
  final int tokenVersion;
  final String? phone;
  final String? timezone;
  final String? locale;
  final int warningCount;
  final int loginCount;
  final DateTime? lastLogin;
  final DateTime? lastSeenAt;

  const AppUser({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.primaryRole = UserRole.student,
    this.tenantId = '',
    this.regionId = '',
    this.accountStatus = AccountStatus.active,
    this.tokenVersion = 0,
    this.phone,
    this.timezone = 'UTC',
    this.locale = 'en',
    this.warningCount = 0,
    this.loginCount = 0,
    this.lastLogin,
    this.lastSeenAt,
  });

  /// Full display name — falls back to email prefix if no name provided.
  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) return firstName!;
    return email.split('@').first;
  }

  /// Initials for avatar fallback.
  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    if (firstName != null) return firstName![0].toUpperCase();
    return email[0].toUpperCase();
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? avatarUrl,
    UserRole? primaryRole,
    String? tenantId,
    String? regionId,
    AccountStatus? accountStatus,
    int? tokenVersion,
    String? phone,
    String? timezone,
    String? locale,
    int? warningCount,
    int? loginCount,
    DateTime? lastLogin,
    DateTime? lastSeenAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      primaryRole: primaryRole ?? this.primaryRole,
      tenantId: tenantId ?? this.tenantId,
      regionId: regionId ?? this.regionId,
      accountStatus: accountStatus ?? this.accountStatus,
      tokenVersion: tokenVersion ?? this.tokenVersion,
      phone: phone ?? this.phone,
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      warningCount: warningCount ?? this.warningCount,
      loginCount: loginCount ?? this.loginCount,
      lastLogin: lastLogin ?? this.lastLogin,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    email,
    firstName,
    lastName,
    avatarUrl,
    primaryRole,
    tenantId,
    regionId,
    accountStatus,
    tokenVersion,
    phone,
    timezone,
    locale,
    warningCount,
    loginCount,
    lastLogin,
    lastSeenAt,
  ];
}
