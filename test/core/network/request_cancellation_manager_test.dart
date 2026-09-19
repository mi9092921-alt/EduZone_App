import 'package:app/core/network/request_cancellation_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RequestCancellationManager', () {
    test('a fresh token is not cancelled', () {
      final manager = RequestCancellationManager();

      expect(manager.token.isCancelled, isFalse);
    });

    test('cancelAll cancels the active token with the given reason', () {
      final manager = RequestCancellationManager();
      final original = manager.token;

      manager.cancelAll(reason: 'session-expired');

      expect(original.isCancelled, isTrue);
    });

    test('cancelAll swaps in a fresh, uncancelled token for future requests',
        () {
      final manager = RequestCancellationManager();
      final original = manager.token;

      manager.cancelAll(reason: 'session-expired');

      final next = manager.token;
      expect(identical(next, original), isFalse,
          reason: 'a new token must be handed out after a cancel');
      expect(next.isCancelled, isFalse);
    });

    test('successive cancelAll calls cancel their own generation only', () {
      final manager = RequestCancellationManager();
      final first = manager.token;

      manager.cancelAll();
      final second = manager.token;
      manager.cancelAll();

      expect(first.isCancelled, isTrue);
      expect(second.isCancelled, isTrue);
      expect(manager.token.isCancelled, isFalse);
    });

    test('provider is keepAlive: the same instance is returned on re-read',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final first = container.read(requestCancellationManagerProvider);
      final second = container.read(requestCancellationManagerProvider);

      expect(identical(first, second), isTrue);
    });
  });
}
