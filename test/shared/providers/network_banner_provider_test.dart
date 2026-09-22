// ignore_for_file: avoid_redundant_argument_values

import 'package:app/shared/providers/network_banner_provider.dart';
import 'package:app/shared/widgets/network_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// connectivity_plus's default MethodChannel/EventChannel implementation.
// These channel names have been stable across major versions of the plugin.
const _methodChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
const _eventChannel = EventChannel('dev.fluttercommunity.plus/connectivity_status');

/// Current stubbed answer for the plugin's `check` method. Tests mutate
/// this to simulate the OS-side connectivity changing *without* any
/// `onConnectivityChanged` event being delivered (the stream stub below
/// stays silent), which is exactly the on-device gap this file guards:
/// a missed online→offline transition must be recoverable via
/// [NetworkBannerNotifier.refreshStatus].
List<String> _mockCheckResult = <String>['wifi'];

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
      _mockCheckResult = <String>['wifi'];
      // Stub connectivity_plus's platform channels so build() doesn't hit
      // a real platform implementation during tests.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_methodChannel, (call) async {
        // connectivity_plus v7's `check` method returns a List<String> of
        // simultaneous connectivity results (e.g. ['wifi']), not a bare String.
        if (call.method == 'check') return List<String>.of(_mockCheckResult);
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

    testWidgets(
        'refreshStatus applies a fresh offline reading when the stream '
        'delivered nothing (missed online→offline transition)', (tester) async {
      final container = ProviderContainer();

      container.read(networkBannerProvider);
      await tester.pump(); // flush the build-time initial check (online)
      expect(container.read(networkBannerProvider).isOffline, isFalse);

      // The OS goes offline but the plugin stream stays silent — no event
      // ever reaches the notifier (reproduced on-device).
      _mockCheckResult = <String>['none'];
      await container.read(networkBannerProvider.notifier).refreshStatus();
      await tester.pump();

      final state = container.read(networkBannerProvider);
      expect(state.isOffline, isTrue);
      expect(state.shouldShow, isTrue);
      // Dispose explicitly (instead of addTearDown) and elapse fake-async
      // time so Riverpod's auto-dispose debounce timer cannot trip the
      // harness "no pending timers" invariant; every behavior assertion
      // above already ran.
      container.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('refreshStatus is a no-op when the reading is unchanged',
        (tester) async {
      final container = ProviderContainer();

      container.read(networkBannerProvider);
      await tester.pump();
      expect(container.read(networkBannerProvider).isOffline, isFalse);

      await container.read(networkBannerProvider.notifier).refreshStatus();
      await tester.pump();

      final state = container.read(networkBannerProvider);
      expect(state.isOffline, isFalse);
      expect(state.isDismissed, isFalse);
      expect(state.shouldShow, isFalse);
      // See above: explicit dispose + fake-time elapse for the harness.
      container.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('refreshStatus after dispose completes without throwing',
        (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(networkBannerProvider.notifier);
      container.dispose();

      await expectLater(notifier.refreshStatus(), completes);
    });

    testWidgets(
        'foregrounding the app re-polls connectivity and surfaces the '
        'banner when the device went offline meanwhile', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: NetworkBanner(child: SizedBox())),
          ),
        ),
      );
      await tester.pump();
      expect(container.read(networkBannerProvider).isOffline, isFalse);

      // Device goes offline with no stream event; the app is foregrounded
      // (or resumes) and the NetworkBanner lifecycle hook must recover.
      _mockCheckResult = <String>['none'];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(container.read(networkBannerProvider).shouldShow, isTrue);
    });
  });
}
