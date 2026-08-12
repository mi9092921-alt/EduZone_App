import 'package:screen_protector/screen_protector.dart';

class ScreenshotGuard {
  /// Enables screenshot and screen recording protection across both platforms.
  static Future<void> protect() async {
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (_) {
      // Silently catch native wrapper exceptions to prevent app startup crashes
    }
  }
}
