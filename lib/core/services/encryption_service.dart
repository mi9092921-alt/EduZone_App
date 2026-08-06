import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for authenticated AES-256-GCM encryption/decryption of downloaded files.
///
/// Each download gets a unique encryption key stored securely in flutter_secure_storage.
/// The file format stores a random IV and an authentication tag so that tampering is
/// detectable before decryption completes.
class EncryptionService {
  static const _keyPrefix = 'enc_key_';
  static const ivLength = 12;
  static const gcmTagLength = 16; // AES-GCM tag length appended to ciphertext

  final FlutterSecureStorage? _secureStorage;

  // Allow passing null in tests where secure storage isn't needed.
  EncryptionService([this._secureStorage]);

  /// Generates a new random 256-bit (32-byte) encryption key.
  String generateEncryptionKey() {
    final key = Key.fromSecureRandom(32);
    return key.base64;
  }

  /// Stores an encryption key securely for a specific download.
  Future<void> storeKey(String downloadId, String key) async {
    if (_secureStorage == null) throw StateError('Secure storage not available');
    await _secureStorage.write(
      key: '$_keyPrefix$downloadId',
      value: key,
    );
  }

  /// Retrieves an encryption key for a specific download.
  /// Returns null if key doesn't exist.
  Future<String?> retrieveKey(String downloadId) async {
    if (_secureStorage == null) throw StateError('Secure storage not available');
    return await _secureStorage.read(key: '$_keyPrefix$downloadId');
  }

  /// Deletes an encryption key for a specific download.
  Future<void> deleteKey(String downloadId) async {
    if (_secureStorage == null) throw StateError('Secure storage not available');
    await _secureStorage.delete(key: '$_keyPrefix$downloadId');
  }

  /// Encrypts a file using AES-256-GCM.
  ///
  /// The encrypted payload stores the IV and authentication tag in a compact format
  /// so tampering during storage or transfer becomes detectable.
  Future<void> encryptFile(
    File source,
    File destination,
    String keyBase64,
  ) async {
    await Isolate.run(
      () => _encryptFileOnWorker(source.path, destination.path, keyBase64),
    );
  }

  /// Decrypts a file encrypted with AES-256-GCM.
  Future<void> decryptFile(
    File encrypted,
    File destination,
    String keyBase64,
  ) async {
    await Isolate.run(
      () => _decryptFileOnWorker(encrypted.path, destination.path, keyBase64),
    );
  }

  /// Calculates SHA-256 checksum of a file for integrity verification.
  Future<String> calculateChecksum(File file) async {
    return Isolate.run(() async {
      final stream = file.openRead();
      final hash = await crypto.sha256.bind(stream).first;
      return hash.toString();
    });
  }

  /// Builds an AES-GCM encrypter for the provided base64 key.
  Encrypter buildEncrypter(String keyBase64) {
    final key = Key.fromBase64(keyBase64);
    return Encrypter(AES(key, mode: AESMode.gcm));
  }

  /// Encrypts a small data buffer (for metadata or small files).
  ///
  /// **Fix (previously): this generated a random [IV] internally but never
  /// returned it, while [decryptBytes] requires that exact IV as a
  /// parameter — meaning there was no correct way to pair a call to this
  /// method with a later [decryptBytes] call. It now returns both the
  /// ciphertext and the IV that was used, so callers can persist/pass the
  /// IV alongside the ciphertext (e.g. store both, or send both over the
  /// wire) and decrypt correctly later.**
  ///
  /// For large files, use [encryptFile] instead.
  ({Encrypted data, IV iv}) encryptBytes(Uint8List data, String keyBase64) {
    final iv = IV.fromSecureRandom(EncryptionService.ivLength);
    final encrypter = buildEncrypter(keyBase64);
    final encryptedData = encrypter.encryptBytes(data, iv: iv);
    return (data: encryptedData, iv: iv);
  }

  /// Decrypts a small data buffer.
  ///
  /// [iv] must be the exact IV returned alongside the ciphertext by
  /// [encryptBytes] for this data — AES-GCM decryption (and tamper
  /// detection via the authentication tag) will fail otherwise.
  ///
  /// For large files, use [decryptFile] instead.
  Uint8List decryptBytes(Encrypted encrypted, String keyBase64, IV iv) {
    final encrypter = buildEncrypter(keyBase64);
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return Uint8List.fromList(decrypted);
  }

  /// Decrypts a small data buffer using an already-built [Encrypter].
  Uint8List decryptBytesWithEncrypter(
    Encrypter encrypter,
    Encrypted encrypted,
    IV iv,
  ) {
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return Uint8List.fromList(decrypted);
  }
}

/// Recovers the real container extension (e.g. `mp4`, `webm`, `mkv`, `m4a`)
/// that was embedded in the file name when the download was created (see
/// `DownloadLocalDataSource.createFilePath` / `createAudioFilePath`).
///
/// Downloads created **before** this fix used the old naming scheme
/// (`<lessonId>_<quality>.enc`, with no container info at all). For those,
/// there is nothing to recover, so [fallback] is returned — this keeps old
/// downloads behaving exactly as before (no regression), while new
/// downloads get the correct container identified.
///
/// Expected new naming scheme: `<lessonId>_<quality>.<ext>.enc`
/// (e.g. `lesson123_720p.webm.enc`), so the segment right before the
/// trailing `.enc` is the real container extension.
String detectContainerExt(String encryptedPath, {String fallback = 'mp4'}) {
  final fileName = encryptedPath.split(RegExp(r'[\\/]')).last;
  const encSuffix = '.enc';
  if (!fileName.endsWith(encSuffix)) return fallback;

  final withoutEnc = fileName.substring(0, fileName.length - encSuffix.length);
  final lastDot = withoutEnc.lastIndexOf('.');
  if (lastDot == -1) return fallback; // old-style file name, no ext segment.

  final ext = withoutEnc.substring(lastDot + 1).toLowerCase();
  // Guard against pathological cases (e.g. an empty segment).
  if (ext.isEmpty) return fallback;
  return ext;
}

/// Maps a container extension to the MIME type that should be sent as
/// `Content-Type` when streaming it, so the demuxer on the player side
/// (mpv/ffmpeg via media_kit) gets an accurate hint instead of a hardcoded
/// `video/mp4` regardless of the file's actual container.
String mimeTypeForContainerExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'webm':
      return 'video/webm';
    case 'mkv':
      return 'video/x-matroska';
    case 'mp4':
    case 'm4v':
      return 'video/mp4';
    case 'ts':
      return 'video/mp2t';
    case 'm4a':
      return 'audio/mp4';
    case 'opus':
      return 'audio/opus';
    case 'weba':
      return 'audio/webm';
    default:
      // Unknown/unlisted extension: fall back to the previous behavior
      // rather than guessing, so nothing new breaks silently.
      return 'video/mp4';
  }
}

/// Represents a single encrypted chunk's index entry.
class ChunkEntry {
  final int encryptedOffset; // offset from start of file AFTER header where IV begins
  final int encryptedLength; // length of ciphertext bytes (tag included)
  final int plaintextLength;

  ChunkEntry({
    required this.encryptedOffset,
    required this.encryptedLength,
    required this.plaintextLength,
  });

  Map<String, dynamic> toJson() => {
        'encryptedOffset': encryptedOffset,
        'encryptedLength': encryptedLength,
        'plaintextLength': plaintextLength,
      };

  static ChunkEntry fromJson(Map<String, dynamic> j) => ChunkEntry(
        encryptedOffset: j['encryptedOffset'] as int,
        encryptedLength: j['encryptedLength'] as int,
        plaintextLength: j['plaintextLength'] as int,
      );
}

/// Index for a chunked .edz file.
class ChunkIndex {
  final int version;
  final int totalPlaintextSize;
  final List<ChunkEntry> chunks;

  ChunkIndex({
    required this.version,
    required this.totalPlaintextSize,
    required this.chunks,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'totalPlaintextSize': totalPlaintextSize,
        'chunks': chunks.map((c) => c.toJson()).toList(),
      };

  static ChunkIndex fromJson(Map<String, dynamic> j) => ChunkIndex(
        version: j['version'] as int,
        totalPlaintextSize: j['totalPlaintextSize'] as int,
        chunks: (j['chunks'] as List).map((e) => ChunkEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Plaintext chunk size for AES-256-GCM chunked file encryption. Extracted
/// as a shared constant (previously hardcoded separately inside
/// [_encryptFileOnWorker]) so callers that need to align byte ranges to
/// chunk boundaries — e.g. a parallel encrypted download — use the exact
/// same size without risk of drift.
const int kEncryptionChunkSize = 512 * 1024;

/// The on-disk header written at the start of every chunked-encrypted file.
/// Shared constant so planning code (below) and the actual writer/reader
/// (`_encryptFileOnWorker`, `buildIndexForExistingFile`) can never disagree
/// about its length.
final List<int> chunkedFormatHeaderBytes = utf8.encode('eduzone-gcm-chunked');

/// One planned chunk: where its plaintext lives in the *source* stream, and
/// exactly where its encrypted form will live in the *destination* file.
///
/// Building this plan requires nothing but the total plaintext size — no
/// file access, no data read — because AES-256-GCM ciphertext is always
/// exactly `plaintext.length + EncryptionService.gcmTagLength` bytes (a
/// fixed-size authentication tag, no block padding). That determinism is
/// what makes it safe for multiple parallel download workers to each
/// encrypt their own byte range and write directly into the shared
/// destination file at a precomputed offset, without waiting on each other
/// or coordinating anything beyond "who owns which chunk indices".
class PlannedChunk {
  final int index;
  final int plaintextStart;
  final int plaintextLength;

  /// Absolute byte offset in the destination file where this chunk's
  /// `[IV][length][ciphertext+tag]` record begins. Uses the same
  /// "absolute from file start" convention as the existing
  /// `ChunkEntry.encryptedOffset` (see `_encryptFileOnWorker` /
  /// `EdzLocalProxy`), so files produced by the new pipelined path are
  /// byte-for-byte layout-compatible with the existing playback proxy —
  /// no changes needed there to read them.
  final int encryptedOffset;

  const PlannedChunk({
    required this.index,
    required this.plaintextStart,
    required this.plaintextLength,
    required this.encryptedOffset,
  });

  int get plaintextEnd => plaintextStart + plaintextLength - 1;

  /// Total bytes this chunk's record occupies in the destination file
  /// (IV + length field + ciphertext-with-tag).
  int get recordLength =>
      EncryptionService.ivLength + 4 + plaintextLength + EncryptionService.gcmTagLength;
}

/// Precomputes the full chunk layout for a plaintext stream of
/// [totalPlaintextSize] bytes. Pure function, no I/O — safe to call before
/// a single byte has been downloaded.
List<PlannedChunk> planChunkLayout(
  int totalPlaintextSize, {
  int chunkSize = kEncryptionChunkSize,
}) {
  final plan = <PlannedChunk>[];
  var plainOffset = 0;
  var encOffset = chunkedFormatHeaderBytes.length;
  var index = 0;
  while (plainOffset < totalPlaintextSize) {
    final remaining = totalPlaintextSize - plainOffset;
    final length = remaining < chunkSize ? remaining : chunkSize;
    final chunk = PlannedChunk(
      index: index,
      plaintextStart: plainOffset,
      plaintextLength: length,
      encryptedOffset: encOffset,
    );
    plan.add(chunk);
    encOffset += chunk.recordLength;
    plainOffset += length;
    index++;
  }
  return plan;
}

/// Total size the destination file will occupy once every planned chunk has
/// been written — used to preallocate the file up front so parallel workers
/// can each seek-and-write their own region independently.
int totalEncryptedSizeForPlan(List<PlannedChunk> plan) {
  if (plan.isEmpty) return chunkedFormatHeaderBytes.length;
  final last = plan.last;
  return last.encryptedOffset + last.recordLength;
}

/// Builds the [ChunkIndex] sidecar directly from a chunk plan. Since the
/// plan is fully deterministic (see [PlannedChunk]), this can be produced
/// and written to the `.idx` sidecar even before the corresponding bytes
/// have been downloaded/encrypted — the pipelined download path uses this
/// to write the sidecar once as the final step, rather than accumulating it
/// chunk-by-chunk as `_encryptFileOnWorker` does for the single-isolate
/// whole-file path.
ChunkIndex chunkIndexFromPlan(List<PlannedChunk> plan, int totalPlaintextSize) {
  return ChunkIndex(
    version: 1,
    totalPlaintextSize: totalPlaintextSize,
    chunks: [
      for (final c in plan)
        ChunkEntry(
          encryptedOffset: c.encryptedOffset,
          encryptedLength: c.plaintextLength + EncryptionService.gcmTagLength,
          plaintextLength: c.plaintextLength,
        ),
    ],
  );
}

/// One encrypted chunk record ready to be written to disk: the IV used and
/// the ciphertext with its GCM tag appended (matches the layout
/// `_encryptFileOnWorker` already writes: `[IV][ciphertext+tag]`, prefixed
/// separately with the 4-byte length by the caller).
class EncryptedChunkRecord {
  final Uint8List iv;
  final Uint8List cipherWithTag;
  const EncryptedChunkRecord(this.iv, this.cipherWithTag);
}

/// Encrypts a batch of plaintext chunk buffers with AES-256-GCM in a single
/// [Isolate.run] call.
///
/// Batched (rather than one [Isolate.run] per chunk, which is what
/// [EdzLocalProxy] does on the *read* side) because a download worker may
/// need to encrypt hundreds of chunks for its assigned range — spawning an
/// isolate per chunk there would add up to meaningful overhead. On the read
/// side a single [Isolate.run] per chunk is fine because an LRU cache
/// absorbs repeat reads of the same chunk; on the write side every chunk is
/// unique, so batching is the right trade-off here instead.
///
/// [plaintextChunks] must be in the same order as the chunk indices they
/// correspond to; the returned list preserves that order.
Future<List<EncryptedChunkRecord>> encryptChunkBatch(
  List<Uint8List> plaintextChunks,
  String keyBase64,
) {
  return Isolate.run(() {
    final key = Key.fromBase64(keyBase64);
    final results = <EncryptedChunkRecord>[];
    for (final buffer in plaintextChunks) {
      final iv = IV.fromSecureRandom(EncryptionService.ivLength);
      // A fresh Encrypter per chunk mirrors the existing single-isolate
      // encrypt path (`_encryptFileOnWorker`) and the existing decrypt path
      // (`EdzLocalProxy._decryptChunkCached`) — AES-GCM state must not be
      // reused across calls with different IVs on some backends, so this
      // keeps the same safe pattern already established elsewhere.
      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      final encrypted = encrypter.encryptBytes(buffer, iv: iv);
      results.add(EncryptedChunkRecord(
        Uint8List.fromList(iv.bytes),
        Uint8List.fromList(encrypted.bytes),
      ));
    }
    return results;
  });
}

/// Attempts to build a ChunkIndex by scanning an encrypted file without
/// decrypting the payload. Expects the chunked header 'eduzone-gcm-chunked'.
Future<ChunkIndex> buildIndexForExistingFile(File encryptedFile) async {
  final raf = await encryptedFile.open();
  try {
    final chunkedHeader = utf8.encode('eduzone-gcm-chunked');
    final headerBytes = await raf.read(chunkedHeader.length);
    if (headerBytes.length < chunkedHeader.length ||
        !_bytesEqual(headerBytes.sublist(0, chunkedHeader.length), chunkedHeader)) {
      throw StateError('Encrypted file is not in chunked format');
    }

    int offset = chunkedHeader.length; // offset where next IV begins
    final chunks = <ChunkEntry>[];
    int totalPlaintext = 0;

    while (true) {
      // Read IV
      await raf.setPosition(offset);
      final ivBytes = await raf.read(EncryptionService.ivLength);
      if (ivBytes.isEmpty) break; // EOF
      if (ivBytes.length < EncryptionService.ivLength) {
        throw ArgumentError('Truncated file: missing IV');
      }

      // Read ciphertext length (4 bytes, big-endian)
      final lengthBytes = await raf.read(4);
      if (lengthBytes.length < 4) {
        throw ArgumentError('Truncated file: missing ciphertext length');
      }
      final length = ByteData.sublistView(Uint8List.fromList(lengthBytes)).getInt32(0);

      final encryptedLen = length;
      final plaintextLen = encryptedLen - EncryptionService.gcmTagLength;
      if (plaintextLen < 0) throw ArgumentError('Invalid encrypted length');

      chunks.add(ChunkEntry(
        encryptedOffset: offset,
        encryptedLength: encryptedLen,
        plaintextLength: plaintextLen,
      ));

      totalPlaintext += plaintextLen;

      // Advance offset past IV + length field + ciphertext
      offset += EncryptionService.ivLength + 4 + encryptedLen;
      // Seek to next offset for loop; break if past EOF
      if (offset >= await encryptedFile.length()) break;
    }

    return ChunkIndex(version: 1, totalPlaintextSize: totalPlaintext, chunks: chunks);
  } finally {
    await raf.close();
  }
}

/// Loads an index from {encryptedFile.path}.idx if present, otherwise builds
/// the index by scanning the encrypted file and writes the .idx sidecar.
Future<ChunkIndex> loadOrBuildIndex(File encryptedFile) async {
  final idxFile = File('${encryptedFile.path}.idx');
  if (await idxFile.exists()) {
    final content = await idxFile.readAsString();
    final jsonMap = json.decode(content) as Map<String, dynamic>;
    return ChunkIndex.fromJson(jsonMap);
  }
  final index = await buildIndexForExistingFile(encryptedFile);
  await idxFile.writeAsString(json.encode(index.toJson()), flush: true);
  return index;
}

Future<void> _encryptFileOnWorker(
  String sourcePath,
  String destinationPath,
  String keyBase64,
) async {
  final key = Key.fromBase64(keyBase64);
  final source = File(sourcePath);
  final destination = File(destinationPath);

  final raf = await source.open();
  await destination.parent.create(recursive: true);
  final sink = destination.openWrite();

  try {
    final header = utf8.encode('eduzone-gcm-chunked');
    sink.add(header);

    const chunkSize = 512 * 1024;
    final chunks = <ChunkEntry>[];
    int totalPlaintext = 0;
    int offset = header.length; // running offset where next IV will be written

    while (true) {
      final buffer = await raf.read(chunkSize);
      if (buffer.isEmpty) break;

      final iv = IV.fromSecureRandom(EncryptionService.ivLength);
      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      final encrypted = encrypter.encryptBytes(buffer, iv: iv);

      // Record where this chunk begins (IV offset relative to start AFTER header)
      final encryptedOffset = offset;

      sink.add(iv.bytes);

      final lengthBytes = ByteData(4)..setInt32(0, encrypted.bytes.length);
      sink.add(lengthBytes.buffer.asUint8List());

      sink.add(encrypted.bytes);

      final encryptedLen = encrypted.bytes.length;
      final plaintextLen = buffer.length;
      chunks.add(ChunkEntry(
        encryptedOffset: encryptedOffset,
        encryptedLength: encryptedLen,
        plaintextLength: plaintextLen,
      ));

      totalPlaintext += plaintextLen;
      offset += EncryptionService.ivLength + 4 + encryptedLen;
    }

    // Write sidecar index JSON
    final idx = ChunkIndex(version: 1, totalPlaintextSize: totalPlaintext, chunks: chunks);
    final idxFile = File('${destination.path}.idx');
    await idxFile.writeAsString(json.encode(idx.toJson()), flush: true);
  } finally {
    await raf.close();
    await sink.close();
  }
}

Future<void> _decryptFileOnWorker(
  String encryptedPath,
  String destinationPath,
  String keyBase64,
) async {
  final encrypted = File(encryptedPath);
  final destination = File(destinationPath);
  final key = Key.fromBase64(keyBase64);

  final raf = await encrypted.open();
  try {
    final chunkedHeader = utf8.encode('eduzone-gcm-chunked');
    final oldHeader = utf8.encode('eduzone-gcm');

    final headerBytes = await raf.read(chunkedHeader.length);

    var isChunked = false;
    if (headerBytes.length >= chunkedHeader.length) {
      isChunked = _bytesEqual(
        headerBytes.sublist(0, chunkedHeader.length),
        chunkedHeader,
      );
    }

    if (isChunked) {
      await raf.setPosition(chunkedHeader.length);
      await destination.parent.create(recursive: true);
      final sink = destination.openWrite();
      try {
        while (true) {
          final ivBytes = await raf.read(EncryptionService.ivLength);
          if (ivBytes.isEmpty) break;
          if (ivBytes.length < EncryptionService.ivLength) {
            throw ArgumentError('Truncated file: missing IV');
          }

          final lengthBytes = await raf.read(4);
          if (lengthBytes.length < 4) {
            throw ArgumentError('Truncated file: missing ciphertext length');
          }
          final length = ByteData.sublistView(
            Uint8List.fromList(lengthBytes),
          ).getInt32(0);

          final cipherBytes = await raf.read(length);
          if (cipherBytes.length < length) {
            throw ArgumentError('Truncated file: missing ciphertext data');
          }

          final iv = IV(Uint8List.fromList(ivBytes));
          final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
          final decrypted = encrypter.decryptBytes(
            Encrypted(Uint8List.fromList(cipherBytes)),
            iv: iv,
          );
          sink.add(decrypted);
        }
      } finally {
        await sink.close();
      }
    } else {
      if (headerBytes.length < oldHeader.length ||
          !_bytesEqual(headerBytes.sublist(0, oldHeader.length), oldHeader)) {
        throw ArgumentError('Invalid encrypted file header');
      }

      await raf.setPosition(oldHeader.length);
      final remainingBytes = await raf.read(
        await encrypted.length() - oldHeader.length,
      );
      if (remainingBytes.length < EncryptionService.ivLength + 16) {
        throw ArgumentError('Invalid encrypted file: missing IV or tag');
      }

      final iv = IV(
        Uint8List.fromList(
          remainingBytes.sublist(0, EncryptionService.ivLength),
        ),
      );
      final payload = remainingBytes.sublist(EncryptionService.ivLength);

      final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
      final decrypted = encrypter.decryptBytes(
        Encrypted(Uint8List.fromList(payload)),
        iv: iv,
      );

      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(decrypted, flush: true);
    }
  } finally {
    await raf.close();
  }
}

bool _bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}