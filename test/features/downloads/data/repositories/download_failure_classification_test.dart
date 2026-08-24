// Regression test for DownloadExecutionService.classifyDownloadFailure,
// added alongside DownloadFailedEvent (Section 15/P8.13 telemetry —
// see CHANGELOG.md "[Unreleased]"). Covers the classification cases the
// doc comment on classifyDownloadFailure claims, so a future change to
// the ENOSPC-detection heuristic can't silently regress without a test
// failing.
import 'dart:async';
import 'dart:io';

import 'package:app/features/downloads/data/repositories/download_execution_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DownloadExecutionService.classifyDownloadFailure', () {
    test('classifies a FileSystemException whose message says "No space '
        'left on device" as storage_full', () {
      const error = FileSystemException(
        'Failed to write',
        '/tmp/foo.enc',
        OSError('No space left on device', 28),
      );
      expect(
        DownloadExecutionService.classifyDownloadFailure(error),
        'storage_full',
      );
    });

    test('classifies a FileSystemException by bare OSError.errorCode 28 '
        'even if the message text differs (e.g. localized OS message)',
        () {
      const error = FileSystemException(
        'Failed to write',
        '/tmp/foo.enc',
        OSError('Disco lleno', 28), // Spanish OS locale, same errno
      );
      expect(
        DownloadExecutionService.classifyDownloadFailure(error),
        'storage_full',
      );
    });

    test('classifies an unrelated FileSystemException as filesystem, not '
        'storage_full', () {
      const error = FileSystemException(
        'Permission denied',
        '/tmp/foo.enc',
        OSError('Permission denied', 13),
      );
      expect(
        DownloadExecutionService.classifyDownloadFailure(error),
        'filesystem',
      );
    });

    test('classifies a SocketException as network', () {
      const error = SocketException('Connection reset by peer');
      expect(
        DownloadExecutionService.classifyDownloadFailure(error),
        'network',
      );
    });

    test('classifies a TimeoutException as network', () {
      final error = TimeoutException('timed out');
      expect(
        DownloadExecutionService.classifyDownloadFailure(error),
        'network',
      );
    });

    test('classifies anything else as unknown', () {
      final error = Exception('something unexpected'); // check-ignore
      expect(
        DownloadExecutionService.classifyDownloadFailure(error),
        'unknown',
      );
    });
  });
}
