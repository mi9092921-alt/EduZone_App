import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

class LifecycleGuard with WidgetsBindingObserver {
  static final LifecycleGuard instance = LifecycleGuard();

  /// Exposes lifecycle handler called by SecurityService.
  /// Protects background screen preview by turning protectDataLeakage on/off.
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
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        await ScreenProtector.protectDataLeakageOn();
      } else if (state == AppLifecycleState.resumed) {
        await ScreenProtector.protectDataLeakageOff();
      }
    } catch (_) {
      // Silently catch native exceptions in background lifecycle events
    }
  }
}
