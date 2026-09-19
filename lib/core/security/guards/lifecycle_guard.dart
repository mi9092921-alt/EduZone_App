import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

class LifecycleGuard with WidgetsBindingObserver {
  static final LifecycleGuard instance = LifecycleGuard();

  /// Exposes lifecycle handler called by SecurityService.
  /// Protects background screen preview without disabling the permanent
  /// screenshot/recording protection when the app resumes.
  ///
  /// Declared `async` (while keeping the required `void` override
  /// signature — Dart permits this) specifically so the try/catch below
  /// can catch failures from the native `screen_protector` plugin. Without
  /// `await`, those calls return a `Future<void>` whose rejection cannot
  /// be caught by a synchronous try/catch — it would instead leak as an
  /// unhandled async error from a background lifecycle callback.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    try {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        if (Platform.isAndroid) {
          // On Android this maps to FLAG_SECURE, which must remain enabled
          // while the app is visible as well as in the task switcher.
          await ScreenProtector.protectDataLeakageOn();
        } else if (Platform.isIOS) {
          await ScreenProtector.protectDataLeakageWithBlur();
        }
      } else if (state == AppLifecycleState.resumed && Platform.isIOS) {
        // Only remove the temporary iOS app-switcher blur. Do not call the
        // Android protectDataLeakageOff equivalent: it clears FLAG_SECURE.
        await ScreenProtector.protectDataLeakageWithBlurOff();
      }
    } catch (_) {
      // Silently catch native exceptions in background lifecycle events
    }
  }
}
