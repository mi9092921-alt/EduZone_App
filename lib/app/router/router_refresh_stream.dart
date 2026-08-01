import 'dart:async';
import 'package:flutter/foundation.dart';

/// Bridges a [Stream] into a [Listenable] so GoRouter can reactively
/// evaluate redirects without rebuilding the router instance.
class RouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  RouterRefreshStream(Stream<dynamic> stream) {
    // Trigger at least once to cover initial state.
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
