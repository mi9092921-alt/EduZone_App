/// Cross-feature facade for `features/notifications`.
///
/// `home` reads the notifications list/count for its dashboard preview.
/// See `auth_shared.dart` for the full rationale — this is the same
/// import-indirection pattern applied to notifications.
library;

export '../../features/notifications/presentation/providers/notifications_provider.dart';
export '../../features/notifications/presentation/widgets/notification_tile.dart';
