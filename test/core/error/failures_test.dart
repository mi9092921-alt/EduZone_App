import 'package:app/core/error/exceptions.dart';
import 'package:app/core/error/failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('failureFromError', () {
    test('classifies NoInternetException as NetworkFailure', () {
      final failure = failureFromError(const NoInternetException());
      expect(failure, isA<NetworkFailure>());
    });

    test('classifies RequestTimeoutException as RequestTimeoutFailure', () {
      final failure = failureFromError(const RequestTimeoutException());
      expect(failure, isA<RequestTimeoutFailure>());
    });

    test('classifies any other AppException as ServerFailure, preserving the message', () {
      final failure = failureFromError(const ServerException('boom')); // check-ignore
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'boom');
    });

    test('classifies a raw, non-AppException error as ServerFailure via toString()', () {
      final failure = failureFromError(StateError('unexpected'));
      expect(failure, isA<ServerFailure>());
      expect(failure.message, contains('unexpected'));
    });
  });

  group('FailureToAppException.toAppException', () {
    test('NetworkFailure round-trips to NoInternetException', () {
      const failure = NetworkFailure();
      expect(failure.toAppException(), isA<NoInternetException>());
    });

    test('RequestTimeoutFailure round-trips to RequestTimeoutException', () {
      const failure = RequestTimeoutFailure();
      expect(failure.toAppException(), isA<RequestTimeoutException>());
    });

    test('any other Failure becomes a ServerException carrying its message', () {
      const failure = ServerFailure('server exploded'); // check-ignore
      final exception = failure.toAppException();
      expect(exception, isA<ServerException>());
      expect(exception.message, 'server exploded');
    });
  });

  test(
    'round-trip: an error classified into a Failure and back reconstructs '
    'the same exception category (regression guard for the '
    'courses/home provider fix -- this used to be `Exception(failure.message)`, '
    'which discarded the category entirely)',
    () {
      for (final original in <AppException>[
        const NoInternetException(),
        const RequestTimeoutException(),
        const ServerException('server-side failure'), // check-ignore
      ]) {
        final failure = failureFromError(original);
        final reconstructed = failure.toAppException();
        expect(reconstructed.runtimeType, original.runtimeType);
      }
    },
  );
}
