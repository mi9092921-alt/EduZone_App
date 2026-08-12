import 'package:equatable/equatable.dart';

import '../enums/account_status.dart';
import '../enums/user_role.dart';

/// Represents the result of a `check_user_access()` RPC call.
///
/// Maps the access status plus optional metadata (suspension
/// reason, ban message, maintenance end time).
class UserAccess extends Equatable {
  final AccountStatus status;
  final UserRole? role;
  final String? message;
  final DateTime? until;
  final DateTime? endsAt;

  const UserAccess({
    required this.status,
    this.role,
    this.message,
    this.until,
    this.endsAt,
  });

  /// Whether the user has full access to the app.
  bool get isAllowed =>
      status == AccountStatus.active &&
      (role == null || role == UserRole.student);

  /// Factory for quick unauthenticated state.
  const UserAccess.unauthenticated()
    : status = AccountStatus.unauthenticated,
      role = null,
      message = null,
      until = null,
      endsAt = null;

  @override
  List<Object?> get props => [status, role, message, until, endsAt];
}
