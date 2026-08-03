// ignore_for_file: avoid_redundant_argument_values

import 'package:app/shared/providers/network_banner_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// connectivity_plus's default MethodChannel/EventChannel implementation.
// These channel names have been stable across major versions of the plugin.
const _methodChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _eventChannel = EventChannel('dev.fluttercommunity.plus/connectivity_status');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetworkBannerState', () {
    test('defaults to online and not dismissed', () {
      const state = NetworkBannerState();
      expect(state.isOffline, isFalse);
      expect(state.isDismissed, isFalse);
      expect(state.shouldShow, isFalse);
    });

    test('shouldShow is true only when offline AND not dismissed', () {
      const offlineVisible = NetworkBannerState(isOffline: true, isDismissed: false);
      const offlineDismissed = NetworkBannerState(isOffline: true, isDismissed: true);
      const onlineDismissed = NetworkBannerState(isOffline: false, isDismissed: true);
      const onlineNotDismissed = NetworkBannerState(isOffline: false, isDismissed: false);

      expect(offlineVisible.shouldShow, isTrue);
      expect(offlineDismissed.shouldShow, isFalse);
      expect(onlineDismissed.shouldShow, isFalse);
      expect(onlineNotDismissed.shouldShow, isFalse);
    });

    test('copyWith overrides only the provided fields', () {
      const original = NetworkBannerState(isOffline: false, isDismissed: false);

      final wentOffline = original.copyWith(isOffline: true);
      expect(wentOffline.isOffline, isTrue);
      expect(wentOffline.isDismissed, isFalse);

      final dismissed = wentOffline.copyWith(isDismissed: true);
      expect(dismissed.isOffline, isTrue);
      expect(dismissed.isDismissed, isTrue);
    });

    test('copyWith with no arguments returns an equivalent state', () {
      const original = NetworkBannerState(isOffline: true, isDismissed: true);
      final copy = original.copyWith();
      expect(copy.isOffline, original.isOffline);
      expect(copy.isDismissed, original.isDismissed);
    });
  });

  group('NetworkBannerNotifier', () {
    setUp(() {
      // Stub connectivity_plus's platform channels so build() doesn't hit
      // a real platform implementation during tests.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_methodChannel, (call) async {
        // connectivity_plus v7's `check` method returns a List<String> of
        // simultaneous connectivity results (e.g. ['wifi']), not a bare String.
        if (call.method == 'check') return <String>['wifi'];
        return null;
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        _eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {},
        ),
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_methodChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(_eventChannel, null);
    });

    test('build() starts with the default (online, not dismissed) state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(networkBannerProvider);
      expect(state.isOffline, isFalse);
      expect(state.isDismissed, isFalse);
    });

    test('dismiss() is a no-op while online', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(networkBannerProvider.notifier).dismiss();

      final state = container.read(networkBannerProvider);
      expect(state.isDismissed, isFalse);
    });
  });
}