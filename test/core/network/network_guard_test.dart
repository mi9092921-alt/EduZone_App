import 'dart:io';

import 'package:app/core/error/exceptions.dart';
import 'package:app/core/network/network_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkGuard.read', () {
    test('returns the value on first success without retrying', () async {
      var calls = 0;
      final result = await NetworkGuard.read(() async {
        calls++;
        return 'ok';
      });
      expect(result, 'ok');
      expect(calls, 1);
    });

    test('retries a transient SocketException up to maxAttempts, then succeeds', () async {
      var calls = 0;
      final result = await NetworkGuard.read(
        () async {
          calls++;
          if (calls < 3) {
            throw const SocketException('temporary failure');
          }
          return 'ok';
        },
        retryBaseDelay: const Duration(milliseconds: 1),
      );
      expect(result, 'ok');
      expect(calls, 3);
    });

    test('gives up after maxAttempts and throws the classified exception', () async {
      var calls = 0;
      await expectLater(
        NetworkGuard.read(
          () async {
            calls++;
            throw const SocketException('always fails');
          },
          maxAttempts: 2,
          retryBaseDelay: const Duration(milliseconds: 1),
        ),
        throwsA(isA<NoInternetException>()),
      );
      expect(calls, 2);
    });

    test('does not retry a non-transient business error', () async {
      var calls = 0;
      await expectLater(
        NetworkGuard.read(
          () async {
            calls++;
            throw const MaxDevicesReachedException();
          },
          retryBaseDelay: const Duration(milliseconds: 1),
        ),
        throwsA(isA<MaxDevicesReachedException>()),
      );
      // A business/validation error must fail fast on the first attempt --
      // retrying it would only delay a failure the caller needs to see.
      expect(calls, 1);
    });

    test('a client-side timeout is classified as RequestTimeoutException', () async {
      await expectLater(
        NetworkGuard.read(
          () => Future<String>.delayed(const Duration(milliseconds: 50), () => 'too late'),
          timeout: const Duration(milliseconds: 5),
          maxAttempts: 1,
        ),
        throwsA(isA<RequestTimeoutException>()),
      );
    });
  });

  group('NetworkGuard.write', () {
    test('returns the value on success', () async {
      final result = await NetworkGuard.write(() async => 'written');
      expect(result, 'written');
    });

    test('never retries, even for a transient-looking failure', () async {
      var calls = 0;
      await expectLater(
        NetworkGuard.write(() async {
          calls++;
          throw const SocketException('no internet');
        }),
        throwsA(isA<NoInternetException>()),
      );
      expect(calls, 1);
    });

    test('maps a client-side timeout the same way as read()', () async {
      await expectLater(
        NetworkGuard.write(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
          timeout: const Duration(milliseconds: 5),
        ),
        throwsA(isA<RequestTimeoutException>()),
      );
    });
  });
}
