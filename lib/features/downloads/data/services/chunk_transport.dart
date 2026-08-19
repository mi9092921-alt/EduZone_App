import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Result of opening one byte-range stream.
class ChunkTransportResponse {
  const ChunkTransportResponse({
    required this.stream,
    required this.statusCode,
  });

  final Stream<Uint8List> stream;
  final int statusCode;
}

/// Network boundary for chunk transfers.
///
/// The transport validates the HTTP range response and exposes only a byte
/// stream. Retry policy, manifest state, encryption, and file writes stay
/// outside this class.
abstract interface class ChunkTransport {
  Future<ChunkTransportResponse> openRange({
    required String url,
    required int start,
    required int end,
    required Map<String, String> headers,
    required CancelToken cancelToken,
  });
}

class DioChunkTransport implements ChunkTransport {
  DioChunkTransport(this._dio);

  final Dio _dio;

  @override
  Future<ChunkTransportResponse> openRange({
    required String url,
    required int start,
    required int end,
    required Map<String, String> headers,
    required CancelToken cancelToken,
  }) async {
    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        headers: {...headers, 'Range': 'bytes=$start-$end'},
        followRedirects: true,
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
        sendTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status == 206,
      ),
      cancelToken: cancelToken,
    );

    final body = response.data;
    if (body == null) {
      throw StateError('Range response body is empty');
    }

    return ChunkTransportResponse(
      stream: body.stream,
      statusCode: response.statusCode ?? 206,
    );
  }
}
