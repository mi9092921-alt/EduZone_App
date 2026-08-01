import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

import 'encryption_service.dart';

/// Local HTTP proxy that serves decrypted plaintext ranges from a chunked
/// `.edz` encrypted file. Binds to loopback only and exposes a single
/// `/stream/{token}` path for the session.
class EdzLocalProxy {
  HttpServer? _server;
  String? _token;
  File? _encryptedFile;
  String? _keyBase64;
  ChunkIndex? _index;
  // Real MIME type of the decrypted content (e.g. 'video/webm' for a VP9
  // download), so mpv/ffmpeg get an accurate demuxer hint instead of the
  // previous hardcoded 'video/mp4' regardless of the actual container.
  String _contentType = 'video/mp4';

  // Small LRU cache of decrypted chunks. media_kit/mpv frequently issue
  // overlapping small range requests while buffering or seeking within the
  // same region, which would otherwise re-decrypt the same chunk repeatedly.
  // Keyed by chunk index; insertion order == recency (LinkedHashMap).
  static const int _maxCachedChunks = 12; // ~6 MB at 512 KB/chunk
  final LinkedHashMap<int, Uint8List> _chunkCache =
      LinkedHashMap<int, Uint8List>();

  EdzLocalProxy();

  /// Starts the proxy and returns the full URI to stream from.
  Future<Uri> start({
    required File encryptedFile,
    required String keyBase64,
    required ChunkIndex index,
    String contentType = 'video/mp4',
  }) async {
    if (_server != null) throw StateError('Proxy already started');
    _encryptedFile = encryptedFile;
    _keyBase64 = keyBase64;
    _index = index;
    _contentType = contentType;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _token = _generateToken();

    _server!.listen((HttpRequest req) async {
      try {
        await _handleRequest(req);
      } catch (e) {
        try {
          // Headers may already be sent if the error happened mid-stream
          // (partway through writing decrypted chunks); setting statusCode
          // at that point throws, so this is guarded separately from the
          // close() below rather than letting it produce a second,
          // unhandled error.
          req.response.statusCode = HttpStatus.internalServerError;
          req.response.write('Internal server error');
        } catch (_) {
          // Headers already sent — nothing more to do but close below.
        }
        try {
          await req.response.close();
        } catch (_) {}
      }
    });

    final port = _server!.port;
    return Uri.http('${InternetAddress.loopbackIPv4.address}:$port', '/stream/$_token');
  }

  String _generateToken() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    _token = null;
    _encryptedFile = null;
    _keyBase64 = null;
    _index = null;
    _contentType = 'video/mp4';
    _chunkCache.clear();
    if (s != null) {
      await s.close(force: true);
    }
  }

  /// Returns the decrypted plaintext for chunk [chunkIndex], using the cache
  /// when available. Cache is a simple LRU: on hit, the entry is moved to
  /// the end (most-recently-used); on insert past [_maxCachedChunks], the
  /// oldest entry is evicted.
  ///
  /// Decryption runs inside [Isolate.run] so AES-256-GCM never blocks the
  /// main isolate — this is the fix for the "slow playback / UI stall on
  /// seek" bug where synchronous decryption was freezing the event loop.
  Future<Uint8List> _decryptChunkCached(
    RandomAccessFile raf,
    int chunkIndex,
    ChunkEntry chunk,
  ) async {
    final cached = _chunkCache.remove(chunkIndex);
    if (cached != null) {
      _chunkCache[chunkIndex] = cached; // re-insert = mark as most-recent
      return cached;
    }

    await raf.setPosition(chunk.encryptedOffset);
    final ivBytes = await raf.read(EncryptionService.ivLength);
    if (ivBytes.length < EncryptionService.ivLength) {
      throw ArgumentError('Truncated IV');
    }
    final lenBytes = await raf.read(4);
    if (lenBytes.length < 4) throw ArgumentError('Truncated length');
    final length =
        ByteData.sublistView(Uint8List.fromList(lenBytes)).getInt32(0);
    final cipherBytes = await raf.read(length);
    if (cipherBytes.length < length) {
      throw ArgumentError('Truncated ciphertext');
    }

    // Capture values needed inside the isolate before crossing the boundary.
    final keyBase64 = _keyBase64!;
    final ivSnapshot = Uint8List.fromList(ivBytes);
    final cipherSnapshot = Uint8List.fromList(cipherBytes);

    // Run AES-256-GCM decryption off the main isolate so it never blocks
    // the UI or the HTTP event loop. Each call spawns a short-lived isolate;
    // the LRU cache above keeps this from being called more than necessary.
    final decrypted = await Isolate.run(() {
      final key = Key.fromBase64(keyBase64);
      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      return Uint8List.fromList(
        encrypter.decryptBytes(
          Encrypted(cipherSnapshot),
          iv: IV(ivSnapshot),
        ),
      );
    });

    if (_chunkCache.length >= _maxCachedChunks) {
      _chunkCache.remove(_chunkCache.keys.first); // evict oldest
    }
    _chunkCache[chunkIndex] = decrypted;
    return decrypted;
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final pathSegments = req.uri.pathSegments;
    if (pathSegments.length < 2 || pathSegments[0] != 'stream' || pathSegments[1] != _token) {
      req.response.statusCode = HttpStatus.forbidden;
      req.response.write('Forbidden');
      await req.response.close();
      return;
    }

    if (_encryptedFile == null || _index == null || _keyBase64 == null) {
      req.response.statusCode = HttpStatus.notFound;
      req.response.write('Not found');
      await req.response.close();
      return;
    }

    final index = _index!;
    final total = index.totalPlaintextSize;

    // Parse Range header
    final rangeHeader = req.headers.value(HttpHeaders.rangeHeader);
    final hasRangeHeader = rangeHeader != null;
    int start = 0;
    int end = total - 1;
    if (rangeHeader != null) {
      final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
      if (m != null) {
        start = int.parse(m.group(1)!);
        final endStr = m.group(2)!;
        if (endStr.isNotEmpty) end = int.parse(endStr);
      }
    }

    if (start < 0 || start >= total) {
      req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await req.response.close();
      return;
    }
    if (end >= total) end = total - 1;

    // Find overlapping chunks
    final chunks = index.chunks;
    final plaintextStarts = <int>[]; // plaintext start offsets
    int acc = 0;
    for (final c in chunks) {
      plaintextStarts.add(acc);
      acc += c.plaintextLength;
    }

    // find first chunk index
    int first = 0;
    while (first < chunks.length && plaintextStarts[first] + chunks[first].plaintextLength - 1 < start) {
      first++;
    }
    if (first >= chunks.length) {
      req.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      await req.response.close();
      return;
    }

    // Respond appropriately based on whether the client actually asked for
    // a range. Returning 206 unconditionally — even for a plain request
    // with no Range header — is a protocol violation that confuses mpv's
    // underlying ffmpeg/avio demuxer about seekability. In practice this
    // is exactly what causes "audio plays but no video": the demuxer gives
    // up on properly indexing/decoding the video track over a connection
    // it doesn't trust, while audio decoding tolerates the confusion.
    // So: no Range header -> 200 OK, full Content-Length, no Content-Range.
    //     Range header present -> 206 Partial Content, with Content-Range.
    if (hasRangeHeader) {
      req.response.statusCode = HttpStatus.partialContent;
      req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$total');
    } else {
      req.response.statusCode = HttpStatus.ok;
    }
    req.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    req.response.headers.set(HttpHeaders.contentLengthHeader, '${end - start + 1}');
    req.response.headers.set(HttpHeaders.contentTypeHeader, _contentType);
    // Dart's HttpResponse buffers writes internally by default
    // (bufferOutput == true) and only actually pushes them to the socket
    // once the buffer fills or the response is flushed/closed. For a
    // progressive media stream that defeats the point of writing
    // chunk-by-chunk below — bytes can sit in this buffer instead of
    // reaching mpv promptly, which reads as "slow" even though decryption
    // itself is fast. Disable it and flush explicitly after each chunk.
    req.response.bufferOutput = false;

    // media_kit/mpv frequently abandons a connection mid-stream when the
    // user seeks (it opens a fresh request with a new Range instead). If we
    // don't detect that, this loop keeps decrypting and writing to a dead
    // socket all the way to the end of the requested range — for a
    // no-Range request that's the whole file. Every seek then leaves behind
    // one of these "zombie" loops, all doing synchronous AES-GCM decryption
    // on the same isolate; a few seeks in a row is enough to visibly stall
    // the UI, and left running long enough (or piled up further) it's a
    // plausible route to an OOM crash from the unbounded write buffer. This
    // flag lets the loop bail out as soon as the client is gone.
    var aborted = false;
    unawaited(req.response.done.catchError((Object _, StackTrace _) {
      aborted = true;
      return null;
    }));

    final raf = await _encryptedFile!.open();
    try {
      int i = first;
      while (i < chunks.length) {
        if (aborted) break;

        final chunk = chunks[i];
        final chunkPlainStart = plaintextStarts[i];
        if (chunkPlainStart > end) break;

        final decrypted = await _decryptChunkCached(raf, i, chunk);
        if (aborted) break;

        // Slice this chunk down to only the bytes that fall within
        // [start, end] — the first and last overlapping chunks are usually
        // only partially needed.
        final chunkPlainEnd = chunkPlainStart + chunk.plaintextLength - 1;
        final sliceStartInChunk = start > chunkPlainStart ? start - chunkPlainStart : 0;
        final sliceEndInChunk =
            end < chunkPlainEnd ? end - chunkPlainStart : chunk.plaintextLength - 1;

        if (sliceStartInChunk <= sliceEndInChunk) {
          try {
            req.response.add(decrypted.sublist(sliceStartInChunk, sliceEndInChunk + 1));
            // Push this chunk to the socket now instead of letting several
            // chunks silently queue up. flush() also awaits actual I/O,
            // which yields to the event loop for us — no need for an
            // arbitrary extra delay between chunks.
            await req.response.flush();
          } catch (_) {
            // Socket already gone — stop immediately rather than continuing
            // to decrypt for a client that isn't listening anymore.
            break;
          }
        }

        // Yield to the event loop between chunks so a large range (e.g. a
        // client that requests the whole file with no Range header) doesn't
        // hog the isolate for its entire duration and freeze the UI.
        // (flush() above already does this by awaiting real I/O, so no
        // extra artificial delay is needed here.)

        i++;
      }
    } finally {
      await raf.close();
    }

    if (!aborted) {
      try {
        await req.response.close();
      } catch (_) {
        // Client already disconnected between the last write and close.
      }
    }
  }
}
