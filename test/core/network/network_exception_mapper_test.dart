import 'dart:async';
import 'dart:io';

import 'package:app/core/error/exceptions.dart';
import 'package:app/core/network/network_exception_mapper.dart';
import 'package:app/core/network/session_revocation_hook.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

    group('session revocation via pre-converted ServerException (datasource '
        'catch blocks throw ServerException before the mapper runs)', () {
      tearDown(() {
        SessionRevocationHook.onSessionRevoked = null;
      });

      test('ServerException with code 28000 → SessionRevokedException + hook', () {
        var hookCalls = 0;
        SessionRevocationHook.onSessionRevoked = (_) => hookCalls++;

        final mapped = NetworkExceptionMapper.map(
          const ServerException('invalid user session', '28000'), // check-ignore
        );

        expect(mapped, isA<SessionRevokedException>());
        expect((mapped as SessionRevokedException).code, 'SESSION_REVOKED');
        expect(hookCalls, 1);
      });

      test('ServerException with code AUTH_REQUIRED → SessionRevokedException '
          '+ hook', () {
        var hookCalls = 0;
        SessionRevocationHook.onSessionRevoked = (_) => hookCalls++;

        final mapped = NetworkExceptionMapper.map(
          const ServerException('Session validation failed', 'AUTH_REQUIRED'), // check-ignore
        );

        expect(mapped, isA<SessionRevokedException>());
        expect(hookCalls, 1);
      });

      test('ServerException with an "invalid user session" message (no code) '
          '→ SessionRevokedException', () {
        final mapped = NetworkExceptionMapper.map(
          const ServerException('Invalid user session: token_version bump'), // check-ignore
        );

        expect(mapped, isA<SessionRevokedException>());
      });

      test('a business ServerException is returned unchanged and the hook '
          'stays silent', () {
        var hookCalls = 0;
        SessionRevocationHook.onSessionRevoked = (_) => hookCalls++;

        const original = ServerException('Maximum devices reached', 'MAX_DEVICES_REACHED'); // check-ignore
        final mapped = NetworkExceptionMapper.map(original);

        expect(mapped, same(original));
        expect(hookCalls, 0);
      });

      test('a raw SessionRevokedException is returned as-is without '
          'double-notifying the hook', () {
        var hookCalls = 0;
        SessionRevocationHook.onSessionRevoked = (_) => hookCalls++;

        const original = SessionRevokedException();
        final mapped = NetworkExceptionMapper.map(original);

        expect(mapped, same(original));
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

    group('transport-level http.ClientException (Sentry EDUZONE-V)', () {
      // Production incident: a connection dropped mid-request surfaces as
      // http.ClientException("Software caused connection abort") from the
      // Supabase REST client. It used to fall through to a generic
      // ServerException — skipping NetworkGuard.read's retry path and
      // leaking into Sentry as an "error". It is pure connectivity noise.
      test('classifies a bare ClientException as NoInternetException', () {
        final mapped = NetworkExceptionMapper.map(
          http.ClientException(
            'Software caused connection abort',
            Uri.parse(
              'https://example.supabase.co/rest/v1/rpc/check_student_app_access',
            ),
          ),
        );
        expect(mapped, isA<NoInternetException>());
      });

      test('classifies the production message shape wrapped in a plain '
          'Exception', () {
        final mapped = NetworkExceptionMapper.map(
          Exception(
            'ClientException: Software caused connection abort, '
            'uri=https://example.supabase.co/rest/v1/rpc/check_student_app_access',
          ),
        );
        expect(mapped, isA<NoInternetException>());
      });

      test('classifies a raw OSError connection-abort message', () {
        final mapped = NetworkExceptionMapper.map(
          Exception('OSError: Software caused connection abort, errno = 103'),
        );
        expect(mapped, isA<NoInternetException>());
      });

      test('classifies "connection closed while receiving data"', () {
        final mapped = NetworkExceptionMapper.map(
          http.ClientException('Connection closed while receiving data'),
        );
        expect(mapped, isA<NoInternetException>());
      });

      test('a ClientException-mapped failure is retryable for reads', () {
        final mapped = NetworkExceptionMapper.map(
          http.ClientException('Software caused connection abort'),
        );
        expect(NetworkExceptionMapper.isRetryable(mapped), isTrue);
      });
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
