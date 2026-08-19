import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the global "no internet connection" banner.
///
/// [isOffline] reflects the real connectivity status.
/// [isDismissed] reflects whether the student manually closed the banner
/// while still offline (e.g. because they are watching a downloaded video
/// and don't need to be reminded).
class NetworkBannerState {
  final bool isOffline;
  final bool isDismissed;

  const NetworkBannerState({this.isOffline = false, this.isDismissed = false});

  /// The banner should only be visible while offline AND not dismissed.
  bool get shouldShow => isOffline && !isDismissed;

  NetworkBannerState copyWith({bool? isOffline, bool? isDismissed}) {
    return NetworkBannerState(
      isOffline: isOffline ?? this.isOffline,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}

/// Notifier that tracks connectivity and lets the user dismiss the banner.
///
/// Follows the same `Notifier<State>` pattern used by `TodoNotifier`
/// (see `features/todo/application/providers/todo_provider.dart`) so the
/// UI layer only ever reacts to `state`, instead of owning a
/// StreamSubscription/AnimationController itself.
class NetworkBannerNotifier extends Notifier<NetworkBannerState> {
  Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  int _buildGeneration = 0;

  @override
  NetworkBannerState build() {
    final buildGeneration = ++_buildGeneration;
    _connectivity = Connectivity();
    _subscription = _connectivity!.onConnectivityChanged.listen(
      (results) => _onConnectivityChanged(results, buildGeneration),
    );

    ref.onDispose(() {
      ++_buildGeneration;
      _subscription?.cancel();
    });

    // Fire-and-forget: check current status once the provider is built.
    Future.microtask(() => _checkInitialStatus(buildGeneration));

    return const NetworkBannerState();
  }

  Future<void> _checkInitialStatus(int buildGeneration) async {
    final connectivity = _connectivity;
    if (connectivity == null) return;

    final result = await connectivity.checkConnectivity();
    _onConnectivityChanged(result, buildGeneration);
  }

  void _onConnectivityChanged(
    List<ConnectivityResult> results,
    int buildGeneration,
  ) {
    if (!ref.mounted || buildGeneration != _buildGeneration) return;

    final isNowOffline = results.every((r) => r == ConnectivityResult.none);

    if (isNowOffline == state.isOffline) return;

    if (isNowOffline) {
      // Went offline: (re)show the banner, resetting any previous dismiss.
      state = state.copyWith(isOffline: true, isDismissed: false);
    } else {
      // Back online: hide the banner and reset dismiss for next time.
      state = state.copyWith(isOffline: false, isDismissed: false);
    }
  }

  /// Called when the student taps the close (X) button.
  ///
  /// Only takes effect while offline — there's nothing to dismiss when
  /// the banner isn't shown anyway.
  void dismiss() {
    if (!state.isOffline || state.isDismissed) return;
    state = state.copyWith(isDismissed: true);
  }
}

final networkBannerProvider =
    NotifierProvider.autoDispose<NetworkBannerNotifier, NetworkBannerState>(
      NetworkBannerNotifier.new,
    );
