import 'package:app/shared/providers/download_network_policy_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

// The notifier hard-instantiates `Connectivity()` inside `build()` (no
// injection seam), so exercising the live provider in a unit test would hit
// the platform channel (MissingPluginException). That is documented debt —
// same class as the WorkManager isolate in CleanupScheduler. What CAN be
// verified purely is the state machine itself: the block matrix that
// DownloadManager consults before every download. These tests pin that
// matrix so refactors (e.g. adding a DI seam later) cannot silently change
// policy behavior.

void main() {
  group('DownloadNetworkPolicyState.block', () {
    test('default state (not ready, no connectivity) blocks nothing', () {
      // Not-yet-initialized: `ready` is false, connectivity defaults to
      // [ConnectivityResult.none]. A decision made on a dead stream must not
      // look like "offline" to the user — hence the `ready` guard.
      const state = DownloadNetworkPolicyState();

      expect(state.block, DownloadNetworkBlock.none);
      expect(state.isOffline, isTrue);
      expect(state.ready, isFalse);
    });

    test('ready + no connectivity reports offline', () {
      // [ConnectivityResult.none] is the constructor default; `ready: true`
      // alone triggers the offline block.
      const state = DownloadNetworkPolicyState(ready: true);

      expect(state.block, DownloadNetworkBlock.offline);
    });

    test('wifiOnly + ready + mobile data blocks with wifiOnlyMobileData', () {
      const state = DownloadNetworkPolicyState(
        wifiOnly: true,
        connectivity: [ConnectivityResult.mobile],
        ready: true,
      );

      expect(state.block, DownloadNetworkBlock.wifiOnlyMobileData);
    });

    test('wifiOnly + ready + wifi does not block', () {
      const state = DownloadNetworkPolicyState(
        wifiOnly: true,
        connectivity: [ConnectivityResult.wifi],
        ready: true,
      );

      expect(state.block, DownloadNetworkBlock.none);
    });

    test('ethernet counts as unmetered for the wifiOnly policy', () {
      const state = DownloadNetworkPolicyState(
        wifiOnly: true,
        connectivity: [ConnectivityResult.ethernet],
        ready: true,
      );

      expect(state.block, DownloadNetworkBlock.none);
      expect(state.onUnmetered, isTrue);
    });

    test('offline wins over wifiOnly when both apply', () {
      // ready + offline + wifiOnly: the offline block is checked first.
      const state = DownloadNetworkPolicyState(wifiOnly: true, ready: true);

      expect(state.block, DownloadNetworkBlock.offline);
    });

    test('wifiOnly with no connectivity and not ready blocks nothing', () {
      // Same rationale as the default state: a policy decision before the
      // connectivity stream has reported must not block the flow.
      const state = DownloadNetworkPolicyState(wifiOnly: true);

      expect(state.block, DownloadNetworkBlock.none);
    });

    test('no wifiOnly + ready + mobile data does not block', () {
      const state = DownloadNetworkPolicyState(
        connectivity: [ConnectivityResult.mobile],
        ready: true,
      );

      expect(state.block, DownloadNetworkBlock.none);
    });
  });

  group('DownloadNetworkPolicyState.isOffline / onUnmetered', () {
    test('isOffline requires every result to be none', () {
      // Android can report multiple transports; one live transport means
      // the device is not offline.
      const mixed = DownloadNetworkPolicyState(
        connectivity: [ConnectivityResult.none, ConnectivityResult.wifi],
        ready: true,
      );
      const allNone = DownloadNetworkPolicyState(
        connectivity: [ConnectivityResult.none, ConnectivityResult.none],
        ready: true,
      );

      expect(mixed.isOffline, isFalse);
      expect(allNone.isOffline, isTrue);
    });
  });

  group('DownloadNetworkPolicyState.copyWith', () {
    test('overrides only the provided fields', () {
      const state = DownloadNetworkPolicyState();

      final updated = state.copyWith(
        wifiOnly: true,
        connectivity: const [ConnectivityResult.mobile],
        ready: true,
      );

      expect(updated.wifiOnly, isTrue);
      expect(updated.connectivity, const [ConnectivityResult.mobile]);
      expect(updated.ready, isTrue);
    });

    test('keeps existing values for omitted fields', () {
      const state = DownloadNetworkPolicyState(
        wifiOnly: true,
        connectivity: [ConnectivityResult.wifi],
        ready: true,
      );

      final updated = state.copyWith(ready: false);

      expect(updated.wifiOnly, isTrue);
      expect(updated.connectivity, const [ConnectivityResult.wifi]);
      expect(updated.ready, isFalse);
    });
  });
}
