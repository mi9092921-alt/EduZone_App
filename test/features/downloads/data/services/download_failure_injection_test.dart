import 'dart:async';

import 'package:app/features/downloads/data/services/download_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException dioError({
  required DioExceptionType type,
  int? statusCode,
}) {
  return DioException(
    requestOptions: RequestOptions(path: 'https://cdn.example.test/video'),
    type: type,
    response: statusCode == null
        ? null
        : Response(
            requestOptions: RequestOptions(
              path: 'https://cdn.example.test/video',
            ),
            statusCode: statusCode,
          ),
  );
}

void main() {
  group('DownloadManager failure classification', () {
    test('retries network, timeout, rate-limit, and server failures', () {
      final retryable = <Object>[
        dioError(type: DioExceptionType.connectionTimeout),
        dioError(type: DioExceptionType.sendTimeout),
        dioError(type: DioExceptionType.receiveTimeout),
        dioError(type: DioExceptionType.connectionError),
        dioError(type: DioExceptionType.badResponse, statusCode: 408),
        dioError(type: DioExceptionType.badResponse, statusCode: 429),
        dioError(type: DioExceptionType.badResponse, statusCode: 500),
        dioError(type: DioExceptionType.badResponse, statusCode: 502),
        dioError(type: DioExceptionType.badResponse, statusCode: 503),
        TimeoutException('idle timeout'),
        StateError('truncated or empty response'),
      ];

      for (final error in retryable) {
        expect(
          DownloadManager.isTransientDownloadError(error),
          isTrue,
          reason: error.toString(),
        );
      }
    });

    test('does not retry definitive authorization or cancellation failures',
        () {
      final nonRetryable = <Object>[
        dioError(type: DioExceptionType.badResponse, statusCode: 401),
        dioError(type: DioExceptionType.badResponse, statusCode: 403),
        dioError(type: DioExceptionType.badResponse, statusCode: 410),
        dioError(type: DioExceptionType.cancel),
        Exception('invalid request'),
      ];

      for (final error in nonRetryable) {
        expect(
          DownloadManager.isTransientDownloadError(error),
          isFalse,
          reason: error.toString(),
        );
      }
    });

    test('recognizes expired signed-link status codes separately', () {
      for (final statusCode in [401, 403, 410]) {
        expect(
          DownloadManager.looksLikeExpiredLinkError(
            dioError(
              type: DioExceptionType.badResponse,
              statusCode: statusCode,
            ),
          ),
          isTrue,
        );
      }

      expect(
        DownloadManager.looksLikeExpiredLinkError(
          dioError(type: DioExceptionType.badResponse, statusCode: 503),
        ),
        isFalse,
      );
    });
  });
}
