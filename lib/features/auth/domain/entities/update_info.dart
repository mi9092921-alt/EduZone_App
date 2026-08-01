import 'package:equatable/equatable.dart';

/// Represents the three possible update states the server can return.
enum UpdateStatus {
  /// App is current — no action needed.
  upToDate,

  /// A newer version is available but not required.
  optionalUpdate,

  /// App version is below the minimum — access must be blocked.
  forceUpdate,
}

/// Carries all data needed for both the Force Update screen
/// and the Optional Update dialog.
class UpdateInfo extends Equatable {
  final UpdateStatus status;

  /// Server-defined message (localized on backend).
  final String message;

  /// Platform-appropriate store URL (Android / iOS).
  final String storeUrl;

  /// The latest version string from the server (used for dismiss persistence).
  final String latestVersion;

  const UpdateInfo({
    required this.status,
    required this.message,
    required this.storeUrl,
    required this.latestVersion,
  });

  /// Convenience factory for the "all good" case.
  const UpdateInfo.upToDate({required this.latestVersion})
      : status = UpdateStatus.upToDate,
        message = '',
        storeUrl = '';

  bool get requiresAction =>
      status == UpdateStatus.forceUpdate ||
      status == UpdateStatus.optionalUpdate;

  @override
  List<Object?> get props => [status, message, storeUrl, latestVersion];
}
