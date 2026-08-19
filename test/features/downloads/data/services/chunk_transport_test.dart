import 'dart:typed_data';

import 'package:app/features/downloads/data/services/chunk_transport.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeChunkTransport implements ChunkTransport {
  FakeChunkTransport(this.bytes);

  final Uint8List bytes;
  int? lastStart;
  int? lastEnd;

  @override
  Future<ChunkTransportResponse> openRange({
    required String url,
    required int start,
    required int end,
    required Map<String, String> headers,
    required CancelToken cancelToken,
  }) async {
    lastStart = start;
    lastEnd = end;
    return ChunkTransportResponse(
      stream: Stream<Uint8List>.value(bytes),
      statusCode: 206,
    );
  }
}

void main() {
  test('transport boundary exposes a range stream without owning retry state',
      () async {
    final transport = FakeChunkTransport(Uint8List.fromList([1, 2, 3]));

    final response = await transport.openRange(
      url: 'https://cdn.example.test/video',
      start: 512,
      end: 1023,
      headers: const {'Accept': '*/*'},
      cancelToken: CancelToken(),
    );

    expect(response.statusCode, 206);
    expect(await response.stream.expand((bytes) => bytes).toList(), [1, 2, 3]);
    expect(transport.lastStart, 512);
    expect(transport.lastEnd, 1023);
  });
}
