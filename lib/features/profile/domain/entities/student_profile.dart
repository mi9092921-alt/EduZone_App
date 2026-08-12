import 'package:equatable/equatable.dart';
import '../../../auth/domain/enums/account_status.dart';
import '../../../auth/domain/enums/user_role.dart';

/// Student profile entity — mirrors `users` table fields.
///
/// Used for profile display and editing. Includes fields
/// that are read-only (email, role) and editable (name, avatar).
class StudentProfile extends Equatable {
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
  final int loginCount;
  final DateTime? createdAt;

  const StudentProfile({
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
    this.loginCount = 0,
    this.createdAt,
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

  /// Create a copy with updated fields (for optimistic updates).
  StudentProfile copyWith({
    String? firstName,
    String? lastName,
    String? avatarUrl,
  }) {
    return StudentProfile(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      primaryRole: primaryRole,
      tenantId: tenantId,
      regionId: regionId,
      accountStatus: accountStatus,
      tokenVersion: tokenVersion,
      loginCount: loginCount,
      createdAt: createdAt,
    );
  }

  /// Factory for skeleton dummy data
  factory StudentProfile.skeleton() {
    return const StudentProfile(
      id: 'skeleton',
      email: 'loading@example.com',
      firstName: 'Loading',
      lastName: 'Name',
      avatarUrl: '',
    );
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      primaryRole: UserRole.fromString(json['primary_role'] as String? ?? 'student'),
      tenantId: json['tenant_id'] as String? ?? '',
      regionId: json['region_id'] as String? ?? '',
      accountStatus: AccountStatus.fromString(json['account_status'] as String? ?? 'active'),
      tokenVersion: json['token_version'] as int? ?? 0,
      loginCount: json['login_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
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
        accountStatus,
        tokenVersion,
        loginCount,
        createdAt,
      ];
}
