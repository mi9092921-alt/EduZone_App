import 'package:equatable/equatable.dart';
import '../enums/account_status.dart';

/// Represents the result of a `check_user_access()` RPC call.
///
/// Maps the access status plus optional metadata (suspension
/// reason, ban message, maintenance end time).
class UserAccess extends Equatable {
  final AccountStatus status;
  final String? message;
  final DateTime? until;
  final DateTime? endsAt;

  const UserAccess({
    required this.status,
    this.message,
    this.until,
    this.endsAt,
  });

  /// Whether the user has full access to the app.
  bool get isAllowed => status == AccountStatus.active;

  /// Factory for quick unauthenticated state.
  const UserAccess.unauthenticated()
    : status = AccountStatus.unauthenticated,
      message = null,
      until = null,
      endsAt = null;

  @override
  List<Object?> get props => [status, message, until, endsAt];
}
