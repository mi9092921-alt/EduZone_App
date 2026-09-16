import 'dart:async';
import 'dart:io';

import 'package:app/core/error/exceptions.dart';
import 'package:app/core/network/network_exception_mapper.dart';
import 'package:app/core/network/session_revocation_hook.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('NetworkExceptionMapper.map', () {
    test('passes through an already-typed AppException unchanged', () {
      const original = MaxDevicesReachedException();
      expect(NetworkExceptionMapper.map(original), same(original));
    });

    test('classifies SocketException as NoInternetException', () {
      final mapped = NetworkExceptionMapper.map(
        const SocketException('Failed host lookup'),
      );
      expect(mapped, isA<NoInternetException>());
    });

    test('classifies TimeoutException as RequestTimeoutException', () {
      final mapped = NetworkExceptionMapper.map(
        TimeoutException('deadline exceeded'),
      );
      expect(mapped, isA<RequestTimeoutException>());
    });

    test('classifies AuthRetryableFetchException with null status as NoInternetException', () {
      final mapped = NetworkExceptionMapper.map(
        AuthRetryableFetchException(message: 'network down'),
      );
      expect(mapped, isA<NoInternetException>());
    });

    test('classifies AuthRetryableFetchException with a status code as ServerException', () {
      final mapped = NetworkExceptionMapper.map(
        AuthRetryableFetchException(
          message: 'bad gateway',
          statusCode: '502',
        ),
      );
      expect(mapped, isA<ServerException>());
      expect((mapped as ServerException).code, 'auth_service_unavailable');
    });

    test('preserves the Postgrest error code on PostgrestException', () {
      final mapped = NetworkExceptionMapper.map(
        const PostgrestException(message: 'permission denied', code: '42501'),
      );
      expect(mapped, isA<ServerException>());
      expect((mapped as ServerException).message, 'permission denied');
      expect(mapped.code, '42501');
    });

    group('session revocation (28000 / AUTH_REQUIRED)', () {
      tearDown(() {
        SessionRevocationHook.onSessionRevoked = null;
      });

      test('classifies Postgrest ERRCODE 28000 as SessionRevokedException', () {
        final mapped = NetworkExceptionMapper.map(
          const PostgrestException(
            message: 'new row violates row-level security policy',
            code: '28000',
          ),
        );
        expect(mapped, isA<SessionRevokedException>());
        expect((mapped as SessionRevokedException).code, 'SESSION_REVOKED');
      });

      test('classifies "invalid user session" message as revocation', () {
        final mapped = NetworkExceptionMapper.map(
          const PostgrestException(
            message: 'Invalid user session: token_version mismatch',
          ),
        );
        expect(mapped, isA<SessionRevokedException>());
      });

      test('classifies AUTH_REQUIRED message as revocation', () {
        final mapped = NetworkExceptionMapper.map(
          const PostgrestException(message: 'AUTH_REQUIRED'),
        );
        expect(mapped, isA<SessionRevokedException>());
      });

      test('notifies the wired hook exactly once', () {
        var hookCalls = 0;
        SessionRevocationHook.onSessionRevoked = (_) => hookCalls++;

        NetworkExceptionMapper.map(
          const PostgrestException(message: 'Invalid user session', code: '28000'),
        );

        expect(hookCalls, 1);
      });

      test('stays inert (no throw, still classified) when unwired', () {
        expect(SessionRevocationHook.isWired, isFalse);

        final mapped = NetworkExceptionMapper.map(
          const PostgrestException(message: 'AUTH_REQUIRED', code: '28000'),
        );

        expect(mapped, isA<SessionRevokedException>());
      });

      test('hook errors never escape into the caller path', () {
        SessionRevocationHook.onSessionRevoked = (_) {
          throw StateError('handler exploded');
        };

        expect(
          () => NetworkExceptionMapper.map(
            const PostgrestException(message: 'AUTH_REQUIRED', code: '28000'),
          ),
          returnsNormally,
        );
      });

      test('ordinary Postgrest errors do NOT trip the hook', () {
        var hookCalls = 0;
        SessionRevocationHook.onSessionRevoked = (_) => hookCalls++;

        NetworkExceptionMapper.map(
          const PostgrestException(message: 'permission denied', code: '42501'),
        );

        expect(hookCalls, 0);
      });
    });

    test('classifies FormatException without leaking parser internals', () {
      final mapped = NetworkExceptionMapper.map(
        const FormatException('Unexpected character at offset 42'),
      );
      expect(mapped, isA<ServerException>());
      expect(
        (mapped as ServerException).message,
        isNot(contains('offset 42')),
      );
    });

    test('falls back to string-matching a plain Exception wrapping a socket failure', () {
      final mapped = NetworkExceptionMapper.map(
        Exception('SocketException: Failed host lookup: example.com'),
      );
      expect(mapped, isA<NoInternetException>());
    });

    test('falls back to ServerException for anything unclassified', () {
      final mapped = NetworkExceptionMapper.map(StateError('boom'));
      expect(mapped, isA<ServerException>());
    });
  });

  group('NetworkExceptionMapper.isRetryable', () {
    test('NoInternetException is retryable', () {
      expect(
        NetworkExceptionMapper.isRetryable(const NoInternetException()),
        isTrue,
      );
    });

    test('RequestTimeoutException is retryable', () {
      expect(
        NetworkExceptionMapper.isRetryable(const RequestTimeoutException()),
        isTrue,
      );
    });

    test('ServerException (a real business/server error) is not retryable', () {
      expect(
        NetworkExceptionMapper.isRetryable(const ServerException('nope')), // check-ignore
        isFalse,
      );
    });

    test('a deliberately-thrown business exception is not retryable', () {
      expect(
        NetworkExceptionMapper.isRetryable(const MaxDevicesReachedException()),
        isFalse,
      );
    });
  });
}
