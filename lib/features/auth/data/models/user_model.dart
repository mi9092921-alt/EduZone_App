import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/enums/account_status.dart';
import '../../domain/enums/user_role.dart';

/// Data-layer model for the `users` table.
///
/// Intentionally NOT a subclass of [AppUser] — the data layer should not
/// inherit from domain entities. Use [toEntity()] to convert to domain.
class UserModel {
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
  final String timezone;
  final String locale;
  final int warningCount;
  final int loginCount;
  final DateTime? lastLogin;
  final DateTime? lastSeenAt;

  const UserModel({
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

  factory UserModel.fromSupabase(User user) {
    final metadata = user.userMetadata ?? {};
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      firstName: metadata['first_name'] as String?,
      lastName: metadata['last_name'] as String?,
      avatarUrl: metadata['avatar_url'] as String?,
      primaryRole:
          UserRole.fromString(metadata['primary_role'] as String? ?? 'student'),
      tenantId: metadata['tenant_id'] as String? ?? '',
      regionId: metadata['region_id'] as String? ?? '',
      accountStatus: AccountStatus.fromString(
          metadata['account_status'] as String? ?? 'active'),
      tokenVersion: metadata['token_version'] as int? ?? 0,
      phone: user.phone,
      timezone: metadata['timezone'] as String? ?? 'UTC',
      locale: metadata['locale'] as String? ?? 'en',
      warningCount: metadata['warning_count'] as int? ?? 0,
      loginCount: metadata['login_count'] as int? ?? 0,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      primaryRole: UserRole.fromString(
          json['primary_role'] as String? ?? 'student'),
      tenantId: json['tenant_id'] as String? ?? '',
      regionId: json['region_id'] as String? ?? '',
      accountStatus: AccountStatus.fromString(
          json['account_status'] as String? ?? 'active'),
      tokenVersion: json['token_version'] as int? ?? 0,
      phone: json['phone'] as String?,
      timezone: json['timezone'] as String? ?? 'UTC',
      locale: json['locale'] as String? ?? 'en',
      warningCount: json['warning_count'] as int? ?? 0,
      loginCount: json['login_count'] as int? ?? 0,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'] as String)
          : null,
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'avatar_url': avatarUrl,
        'primary_role': primaryRole.toDbString,
        'tenant_id': tenantId,
        'region_id': regionId,
        'account_status': accountStatus.toDbString,
        'token_version': tokenVersion,
        'phone': phone,
        'timezone': timezone,
        'locale': locale,
        'warning_count': warningCount,
        'login_count': loginCount,
        'last_login': lastLogin?.toIso8601String(),
        'last_seen_at': lastSeenAt?.toIso8601String(),
      };

  AppUser toEntity() => AppUser(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        avatarUrl: avatarUrl,
        primaryRole: primaryRole,
        tenantId: tenantId,
        regionId: regionId,
        accountStatus: accountStatus,
        tokenVersion: tokenVersion,
        phone: phone,
        timezone: timezone,
        locale: locale,
        warningCount: warningCount,
        loginCount: loginCount,
        lastLogin: lastLogin,
        lastSeenAt: lastSeenAt,
      );

  factory UserModel.fromEntity(AppUser user) => UserModel(
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        avatarUrl: user.avatarUrl,
        primaryRole: user.primaryRole,
        tenantId: user.tenantId,
        regionId: user.regionId,
        accountStatus: user.accountStatus,
        tokenVersion: user.tokenVersion,
        phone: user.phone,
        timezone: user.timezone ?? 'UTC',
        locale: user.locale ?? 'en',
        warningCount: user.warningCount,
        loginCount: user.loginCount,
        lastLogin: user.lastLogin,
        lastSeenAt: user.lastSeenAt,
      );
}
