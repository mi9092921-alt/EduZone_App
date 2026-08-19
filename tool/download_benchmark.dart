import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

const _defaultChunkSize = 512 * 1024;
const _chunksPerBatch = 16;
const _ivLength = 12;
const _gcmTagLength = 16;
final _chunkedHeader = utf8.encode('eduzone-gcm-chunked');

/// Offline benchmark for the encrypted download pipeline.
///
/// This deliberately stays outside `flutter test`: the default run allocates
/// and encrypts 100 MiB, and the larger plan sizes are intended for a real
/// device or a controlled workstation. Network throttling, battery, and
/// process-recreation measurements require an integration/device harness and
/// are not fabricated by this tool.
Future<void> main(List<String> args) async {
  final options = _BenchmarkOptions.parse(args);
  if (options.help) {
    stdout.writeln(_BenchmarkOptions.usage);
    return;
  }

  final sizes = options.allSizes
      ? const [100, 500, 1024]
      : [options.sizeMiB];
  if (options.allSizes) {
    stderr.writeln('All-sizes benchmark: 1624 MiB total payload.');
  }
  final results = <Map<String, Object>>[];

  for (final sizeMiB in sizes) {
    final samples = <_BenchmarkSample>[];
    for (var iteration = 0; iteration < options.iterations; iteration++) {
      stderr.writeln(
        'Benchmarking $sizeMiB MiB '
        '(iteration ${iteration + 1}/${options.iterations}, '
        '${options.workers} workers)...',
      );
      samples.add(
        await _runSample(
          sizeMiB: sizeMiB,
          chunkSize: options.chunkSize,
          workers: options.workers,
        ),
      );
    }

    final durations = samples.map((sample) => sample.durationMs).toList();
    final encryptionTimes = samples.map((sample) => sample.encryptionMs).toList();
    final writeTimes = samples.map((sample) => sample.writeMs).toList();
    final averageDuration = durations.reduce((a, b) => a + b) / durations.length;
    final bytes = sizeMiB * 1024 * 1024;

    results.add({
      'sizeMiB': sizeMiB,
      'chunkKiB': options.chunkSize ~/ 1024,
      'iterations': options.iterations,
      'workers': options.workers,
      'averageMBps': bytes / (averageDuration / 1000) / (1024 * 1024),
      'p50DurationMs': _percentile(durations, 0.50),
      'p95DurationMs': _percentile(durations, 0.95),
      'averageEncryptionMs': _average(encryptionTimes),
      'averageDiskWriteMs': _average(writeTimes),
    });
  }

  stdout.writeln(const JsonEncoder.withIndent('  ').convert({
    'benchmark': 'download-encryption',
    'results': results,
  }));
}

Future<_BenchmarkSample> _runSample({
  required int sizeMiB,
  required int chunkSize,
  required int workers,
}) async {
  final totalBytes = sizeMiB * 1024 * 1024;
  final plan = _planChunkLayout(totalBytes, chunkSize: chunkSize);
  final key = Key.fromSecureRandom(32).base64;
  final output = File(
    '${Directory.systemTemp.path}/eduzone_benchmark_${pid}_${DateTime.now().microsecondsSinceEpoch}.enc',
  );
  final stopwatch = Stopwatch()..start();
  var encryptionMs = 0;
  var writeMs = 0;

  final raf = await output.open(mode: FileMode.writeOnly);
  try {
    final setupStart = stopwatch.elapsedMicroseconds;
    await raf.writeFrom(_chunkedHeader);
    writeMs += (stopwatch.elapsedMicroseconds - setupStart) ~/ 1000;

    final writeLock = _AsyncBenchmarkFileLock(raf);
    var completedChunks = 0;
    var nextProgress = max(1, plan.length ~/ 20);
    void reportProgress(int count) {
      completedChunks += count;
      if (completedChunks >= nextProgress || completedChunks == plan.length) {
        stderr.writeln(
          '  progress: ${(completedChunks * 100 / plan.length).toStringAsFixed(0)}%',
        );
        nextProgress += max(1, plan.length ~/ 20);
      }
    }

    final workerCount = min(workers, plan.length);
    final workerSamples = await Future.wait([
      for (var worker = 0; worker < workerCount; worker++)
        _runWorker(
          plan: plan,
          key: key,
          worker: worker,
          workerCount: workerCount,
          writeLock: writeLock,
          reportProgress: reportProgress,
        ),
    ]);
    for (final sample in workerSamples) {
      encryptionMs += sample.encryptionMs;
      writeMs += sample.writeMs;
    }
  } finally {
    await raf.close();
    await output.delete().catchError((_) => output);
  }

  stopwatch.stop();
  return _BenchmarkSample(
    durationMs: stopwatch.elapsedMilliseconds,
    encryptionMs: encryptionMs,
    writeMs: writeMs,
  );
}

Future<_WorkerSample> _runWorker({
  required List<_BenchmarkChunk> plan,
  required String key,
  required int worker,
  required int workerCount,
  required _AsyncBenchmarkFileLock writeLock,
  required void Function(int count) reportProgress,
}) async {
  final random = Random(0xED020 + worker * 7919 + plan.length);
  var encryptionMs = 0;
  var writeMs = 0;

  for (var offset = worker * _chunksPerBatch;
      offset < plan.length;
      offset += workerCount * _chunksPerBatch) {
    final batch = plan.skip(offset).take(_chunksPerBatch).map((chunk) {
      final bytes = Uint8List(chunk.plaintextLength);
      for (var index = 0; index < bytes.length; index++) {
        bytes[index] = random.nextInt(256);
      }
      return bytes;
    }).toList(growable: false);

    final encryptionStart = Stopwatch()..start();
    final encrypted = await _encryptChunkBatch(batch, key);
    encryptionStart.stop();
    encryptionMs += encryptionStart.elapsedMilliseconds;

    final writeStart = Stopwatch()..start();
    await writeLock.synchronized(() async {
      for (var index = 0; index < encrypted.length; index++) {
        final chunk = plan[offset + index];
        final record = encrypted[index];
        final length = ByteData(4)
          ..setInt32(0, record.cipherWithTag.length);
        await writeLock.file.setPosition(chunk.encryptedOffset);
        await writeLock.file.writeFrom(record.iv);
        await writeLock.file.writeFrom(length.buffer.asUint8List());
        await writeLock.file.writeFrom(record.cipherWithTag);
      }
    });
    writeStart.stop();
    writeMs += writeStart.elapsedMilliseconds;
    reportProgress(encrypted.length);
  }

  return _WorkerSample(encryptionMs: encryptionMs, writeMs: writeMs);
}

class _WorkerSample {
  const _WorkerSample({
    required this.encryptionMs,
    required this.writeMs,
  });

  final int encryptionMs;
  final int writeMs;
}

class _AsyncBenchmarkFileLock {
  _AsyncBenchmarkFileLock(this.file);

  final RandomAccessFile file;
  Future<void> _tail = Future<void>.value();

  Future<T> synchronized<T>(Future<T> Function() action) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    await previous;
    try {
      return await action();
    } finally {
      completed.complete();
    }
  }
}

double _average(List<int> values) =>
    values.reduce((a, b) => a + b) / values.length;

int _percentile(List<int> values, double percentile) {
  final sorted = [...values]..sort();
  final index = ((sorted.length - 1) * percentile).round();
  return sorted[index];
}

class _BenchmarkSample {
  const _BenchmarkSample({
    required this.durationMs,
    required this.encryptionMs,
    required this.writeMs,
  });

  final int durationMs;
  final int encryptionMs;
  final int writeMs;
}

class _BenchmarkChunk {
  const _BenchmarkChunk({
    required this.plaintextStart,
    required this.plaintextLength,
    required this.encryptedOffset,
  });

  final int plaintextStart;
  final int plaintextLength;
  final int encryptedOffset;
}

class _EncryptedChunk {
  const _EncryptedChunk(this.iv, this.cipherWithTag);

  final Uint8List iv;
  final Uint8List cipherWithTag;
}

List<_BenchmarkChunk> _planChunkLayout(
  int totalBytes, {
  required int chunkSize,
}) {
  final plan = <_BenchmarkChunk>[];
  var plaintextStart = 0;
  var encryptedOffset = _chunkedHeader.length;
  while (plaintextStart < totalBytes) {
    final length = min(chunkSize, totalBytes - plaintextStart);
    plan.add(_BenchmarkChunk(
      plaintextStart: plaintextStart,
      plaintextLength: length,
      encryptedOffset: encryptedOffset,
    ));
    plaintextStart += length;
    encryptedOffset += _ivLength + 4 + length + _gcmTagLength;
  }
  return plan;
}

Future<List<_EncryptedChunk>> _encryptChunkBatch(
  List<Uint8List> chunks,
  String keyBase64,
) {
  return Isolate.run(() {
    return [for (final chunk in chunks) _encryptOneChunk(chunk, keyBase64)];
  });
}

_EncryptedChunk _encryptOneChunk(Uint8List chunk, String keyBase64) {
  final key = Key.fromBase64(keyBase64);
  final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
  final iv = IV.fromSecureRandom(_ivLength);
  final encrypted = encrypter.encryptBytes(chunk, iv: iv);
  return _EncryptedChunk(
    Uint8List.fromList(iv.bytes),
    Uint8List.fromList(encrypted.bytes),
  );
}

class _BenchmarkOptions {
  const _BenchmarkOptions({
    required this.sizeMiB,
    required this.chunkSize,
    required this.iterations,
    required this.workers,
    required this.allSizes,
    required this.help,
  });

  final int sizeMiB;
  final int chunkSize;
  final int iterations;
  final int workers;
  final bool allSizes;
  final bool help;

  static const usage = '''
Usage: dart run tool/download_benchmark.dart [options]

  --size-mb=N       Benchmark one payload size (default: 100).
  --chunk-kb=N     Plaintext chunk size (default: 512).
  --iterations=N   Repetitions per size (default: 1).
  --workers=N      Concurrent encryption workers (default: 4).
  --all-sizes       Run 100 MiB, 500 MiB, and 1 GiB samples.
  --help            Show this help.
''';

  factory _BenchmarkOptions.parse(List<String> args) {
    var sizeMiB = 100;
    var chunkSize = _defaultChunkSize;
    var iterations = 1;
    var workers = 4;
    var allSizes = false;
    var help = false;

    for (final arg in args) {
      if (arg == '--all-sizes') {
        allSizes = true;
      } else if (arg == '--help' || arg == '-h') {
        help = true;
      } else if (arg.startsWith('--size-mb=')) {
        sizeMiB = int.parse(arg.substring('--size-mb='.length));
      } else if (arg.startsWith('--chunk-kb=')) {
        chunkSize = int.parse(arg.substring('--chunk-kb='.length)) * 1024;
      } else if (arg.startsWith('--iterations=')) {
        iterations = int.parse(arg.substring('--iterations='.length));
      } else if (arg.startsWith('--workers=')) {
        workers = int.parse(arg.substring('--workers='.length));
      } else {
        throw FormatException('Unknown option: $arg');
      }
    }

    if (sizeMiB <= 0 || chunkSize <= 0 || iterations <= 0 || workers <= 0) {
      throw const FormatException(
        'size, chunk size, and iterations must be positive',
      );
    }
    return _BenchmarkOptions(
      sizeMiB: sizeMiB,
      chunkSize: chunkSize,
      iterations: iterations,
      workers: workers,
      allSizes: allSizes,
      help: help,
    );
  }
}
