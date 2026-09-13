import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

enum DownloadNetworkBlock { none, offline, wifiOnlyMobileData }

class DownloadNetworkPolicyState {
  final bool wifiOnly;
  final List<ConnectivityResult> connectivity;
  final bool ready;

  const DownloadNetworkPolicyState({
    this.wifiOnly = false,
    this.connectivity = const [ConnectivityResult.none],
    this.ready = false,
  });

  bool get isOffline => connectivity.every((c) => c == ConnectivityResult.none);

  bool get onUnmetered => connectivity.any(
        (c) => c == ConnectivityResult.wifi || c == ConnectivityResult.ethernet,
      );

  DownloadNetworkBlock get block {
    if (ready && isOffline) return DownloadNetworkBlock.offline;
    if (wifiOnly && ready && !onUnmetered) {
      return DownloadNetworkBlock.wifiOnlyMobileData;
    }
    return DownloadNetworkBlock.none;
  }

  DownloadNetworkPolicyState copyWith({
    bool? wifiOnly,
    List<ConnectivityResult>? connectivity,
    bool? ready,
  }) {
    return DownloadNetworkPolicyState(
      wifiOnly: wifiOnly ?? this.wifiOnly,
      connectivity: connectivity ?? this.connectivity,
      ready: ready ?? this.ready,
    );
  }
}

class DownloadNetworkPolicyNotifier
    extends Notifier<DownloadNetworkPolicyState> {
  Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  int _buildGeneration = 0;

  @override
  DownloadNetworkPolicyState build() {
    final generation = ++_buildGeneration;
    _connectivity = Connectivity();
    _subscription = _connectivity!.onConnectivityChanged.listen(
      (results) => _updateConnectivity(results, generation),
    );
    ref.onDispose(() {
      ++_buildGeneration;
      _subscription?.cancel();
    });
    Future.microtask(() => _initialize(generation));
    return const DownloadNetworkPolicyState();
  }

  Future<void> _initialize(int generation) async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || generation != _buildGeneration) return;
    state = state.copyWith(wifiOnly: prefs.getBool(StorageKeys.downloadWifiOnly) ?? false);
    final connectivity = _connectivity;
    if (connectivity == null) return;
    final results = await connectivity.checkConnectivity();
    _updateConnectivity(results, generation);
  }

  void _updateConnectivity(List<ConnectivityResult> results, int generation) {
    if (!ref.mounted || generation != _buildGeneration) return;
    state = state.copyWith(connectivity: results, ready: true);
  }

  Future<void> setWifiOnly(bool value) async {
    state = state.copyWith(wifiOnly: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.downloadWifiOnly, value);
  }
}

// Deliberate keep-alive singleton (check-ignore): this notifier owns the
// connectivity_plus subscription that drives the Wi-Fi-only download policy.
// DownloadManager and the long-running download flows read it via ref.read
// mid-download; an auto-dispose variant would tear the connectivity
// subscription down whenever no widget is actively watching, leaving
// in-flight downloads making policy decisions on a dead state stream.
final downloadNetworkPolicyProvider = NotifierProvider< // check-ignore
    DownloadNetworkPolicyNotifier, DownloadNetworkPolicyState>(
  DownloadNetworkPolicyNotifier.new,
);
