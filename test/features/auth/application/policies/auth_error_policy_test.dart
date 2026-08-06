import 'dart:async';
import 'dart:io';

import 'package:app/core/error/exceptions.dart';
import 'package:app/features/auth/application/policies/auth_error_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthErrorPolicy.isTransient', () {
    test('returns true for NoInternetException', () {
      expect(AuthErrorPolicy.isTransient(const NoInternetException()), isTrue);
    });

    test('returns true for TimeoutException', () {
      expect(AuthErrorPolicy.isTransient(TimeoutException('timed out')), isTrue);
    });

    test('returns true for SocketException', () {
      expect(
        AuthErrorPolicy.isTransient(const SocketException('failed')),
        isTrue,
      );
    });

    test('returns true for ServerException whose message mentions network', () {
      expect(
        AuthErrorPolicy.isTransient(const ServerException('Network error occurred')),
        isTrue,
      );
    });

    test('returns true for ServerException whose message mentions timeout', () {
      expect(
        AuthErrorPolicy.isTransient(const ServerException('Request timeout')),
        isTrue,
      );
    });

    test('returns true for ServerException whose message mentions connection', () {
      expect(
        AuthErrorPolicy.isTransient(const ServerException('Connection refused')),
        isTrue,
      );
    });

    test('is case-insensitive when matching ServerException messages', () {
      expect(
        AuthErrorPolicy.isTransient(const ServerException('NETWORK ISSUE')),
        isTrue,
      );
    });

    test('returns false for ServerException with an unrelated message', () {
      expect(
        AuthErrorPolicy.isTransient(const ServerException('Internal server error')),
        isFalse,
      );
    });

    test('returns false for InvalidCredentialsException', () {
      expect(
        AuthErrorPolicy.isTransient(const InvalidCredentialsException()),
        isFalse,
      );
    });

    test('returns false for an arbitrary unrelated exception', () {
      expect(AuthErrorPolicy.isTransient(Exception('boom')), isFalse);
    });
  });

  group('AuthErrorPolicy.mapExceptionToKey', () {
    test('maps InvalidCredentialsException to errorAuth', () {
      expect(
        AuthErrorPolicy.mapExceptionToKey(const InvalidCredentialsException()),
        'errorAuth',
      );
    });

    test('maps EmailNotConfirmedException to errorEmailNotConfirmed', () {
      expect(
        AuthErrorPolicy.mapExceptionToKey(const EmailNotConfirmedException()),
        'errorEmailNotConfirmed',
      );
    });

    test('maps NoInternetException to errorNetwork', () {
      expect(
        AuthErrorPolicy.mapExceptionToKey(const NoInternetException()),
        'errorNetwork',
      );
    });

    test('maps RateLimitedException to errorRateLimit with retry seconds', () {
      expect(
        AuthErrorPolicy.mapExceptionToKey(
          const RateLimitedException(retryAfterSeconds: 42),
        ),
        'errorRateLimit:42',
      );
    });

    test('maps MaxDevicesReachedException to errorMaxDevices', () {
      expect(
        AuthErrorPolicy.mapExceptionToKey(const MaxDevicesReachedException()),
        'errorMaxDevices',
      );
    });

    test('maps DeviceAlreadyBoundException to errorDeviceBound', () {
      expect(
        AuthErrorPolicy.mapExceptionToKey(const DeviceAlreadyBoundException()),
        'errorDeviceBound',
      );
    });

    test('falls back to errorGeneric for an unmapped exception type', () {
      expect(
        AuthErrorPolicy.mapExceptionToKey(Exception('unexpected')),
        'errorGeneric',
      );
    });

    test('falls back to errorGeneric for a ServerException (not explicitly mapped)', () {
      expect(
        AuthErrorPolicy.mapExceptionToKey(const ServerException('500')),
        'errorGeneric',
      );
    });
  });
}
