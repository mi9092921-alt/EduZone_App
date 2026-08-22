/// Global application configuration and feature toggles.
class AppConfig {
  /// Toggle for Firebase Cloud Messaging.
  /// Set to false if FCM is not yet configured on the backend/device.
  static const bool fcmEnabled = true;

  /// Default timeout for remote network operations.
  static const Duration networkTimeout = Duration(seconds: 5);
}
