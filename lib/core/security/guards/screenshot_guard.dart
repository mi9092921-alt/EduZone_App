import 'dart:io';

import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

class ScreenshotGuard {
  static const MethodChannel _screenProtectorChannel =
      MethodChannel('screen_protector');

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

      // screen_protector exposes this native operation on iOS but does not
      // include it in its Dart API. Keep recording protection enabled for the
      // whole app lifetime; Android is covered by FLAG_SECURE above/native.
      if (Platform.isIOS) {
        await _screenProtectorChannel.invokeMethod<void>('preventScreenRecordOn');
      }

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
