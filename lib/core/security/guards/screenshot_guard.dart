import 'dart:io';

import 'package:screen_protector/screen_protector.dart';

class ScreenshotGuard {
  /// Enables screenshot and screen recording protection across both platforms.
  ///
  /// • **Android** — `preventScreenshotOn()` sets `FLAG_SECURE`, which blocks
  ///   screenshots *and* screen recording at the OS level.
  ///   `protectDataLeakageOn()` hides content in the task-switcher preview.
  ///
  /// • **iOS** — `preventScreenshotOn()` overlays a hidden field to block
  ///   screenshots. `protectDataLeakageWithBlur()` applies a blur in the
  ///   app-switcher to stop content leaking from background previews.
  static Future<void> protect() async {
    try {
      // Blocks screenshots (and screen recording on Android via FLAG_SECURE).
      await ScreenProtector.preventScreenshotOn();

      // Hide content when the app is in the task-switcher / app-switcher.
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageOn();
      } else if (Platform.isIOS) {
        await ScreenProtector.protectDataLeakageWithBlur();
      }
    } catch (_) {
      // Silently catch native wrapper exceptions to prevent app startup
      // crashes on devices where the underlying API isn't supported.
    }
  }
}
