import 'dart:io';

import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/application/services/offline_policy_engine.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  late MockDownloadLocalDataSource localDataSource;
  late MockEncryptionService encryptionService;
  late Directory tempDir;
  late String encryptedPath;

  const downloadId = 'dl_1';
  const currentUserId = 'user_current';
  const currentDeviceId = 'device_current';

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() async {
    localDataSource = MockDownloadLocalDataSource();
    encryptionService = MockEncryptionService();
    tempDir = Directory.systemTemp.createTempSync('offline_policy_engine_test');
    encryptedPath = '${tempDir.path}/video.edz';
    File(encryptedPath).writeAsBytesSync([1, 2, 3]);

    when(() => localDataSource.updateDownload(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  OfflinePolicyEngine buildEngine({
    String? userId = currentUserId,
    String device = currentDeviceId,
  }) {
    return OfflinePolicyEngine(
      localDataSource: localDataSource,
      encryptionService: encryptionService,
      currentUserId: () => userId,
      deviceFingerprint: () => device,
    );
  }

  Map<String, dynamic> validRow({
    String status = 'completed',
    int? expiresAt,
    String? userId = currentUserId,
    String? deviceId = currentDeviceId,
    String? path,
  }) {
    return {
      'id': downloadId,
      'download_status': status,
      'expires_at': expiresAt ??
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      'user_id': userId,
      'device_id': deviceId,
      'encrypted_path': path ?? encryptedPath,
    };
  }

  group('OfflinePolicyEngine.authorize — allow path', () {
    test('allows playback when every invariant is satisfied', () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());
      when(() => encryptionService.retrieveKey(downloadId))
          .thenAnswer((_) async => 'a-key');

      await buildEngine().authorize(downloadId);

      verify(() => localDataSource.getDownloadById(downloadId)).called(1);
      // Not a legacy row, so no adoption write should happen.
      verifyNever(() => localDataSource.updateDownload(any(), any()));
    });
  });

  group('OfflinePolicyEngine.authorize — deny paths (P6.41 invariants)', () {
    test('denies when the download is not found', () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => null);

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.downloadNotFound,
          ),
        ),
      );
    });

    test('denies when the download is not completed', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(status: 'downloading'),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.notCompleted,
          ),
        ),
      );
    });

    test('denies when the license/offline window has expired', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(
          expiresAt: DateTime.now()
              .subtract(const Duration(days: 1))
              .millisecondsSinceEpoch,
        ),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.expired,
          ),
        ),
      );
    });

    test('denies when the download belongs to a different account', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(userId: 'someone_else'),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.ownerMismatch,
          ),
        ),
      );
    });

    test('denies when there is no signed-in account but the download is owned',
        () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());

      await expectLater(
        buildEngine(userId: null).authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.ownerMismatch,
          ),
        ),
      );
    });

    test('denies when the download is bound to a different device', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(deviceId: 'someone_elses_device'),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.deviceMismatch,
          ),
        ),
      );
    });

    test('denies when the encrypted file is missing from disk', () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(path: '${tempDir.path}/does_not_exist.edz'),
      );

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.missingFile,
          ),
        ),
      );
    });

    test('denies when the decryption key is missing from secure storage',
        () async {
      when(() => localDataSource.getDownloadById(downloadId))
          .thenAnswer((_) async => validRow());
      when(() => encryptionService.retrieveKey(downloadId))
          .thenAnswer((_) async => null);

      await expectLater(
        buildEngine().authorize(downloadId),
        throwsA(
          isA<OfflinePlaybackDeniedException>().having(
            (e) => e.reason,
            'reason',
            OfflinePlaybackDenialReason.missingKey,
          ),
        ),
      );
    });
  });

  group('OfflinePolicyEngine.authorize — legacy (pre-v7) rows', () {
    test(
      'adopts an unbound legacy row to the current account/device instead of denying it',
      () async {
        when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
          (_) async => validRow(userId: null, deviceId: null),
        );
        when(() => encryptionService.retrieveKey(downloadId))
            .thenAnswer((_) async => 'a-key');

        await buildEngine().authorize(downloadId);

        // Note: a Map literal is not `==`-comparable to another Map literal
        // in Dart, so this deliberately matches on content via `predicate`
        // rather than `updateDownload(downloadId, {...})`, which would
        // silently never match.
        verify(
          () => localDataSource.updateDownload(
            downloadId,
            any(
              that: predicate<Map<String, dynamic>>(
                (m) =>
                    m['user_id'] == currentUserId &&
                    m['device_id'] == currentDeviceId,
              ),
            ),
          ),
        ).called(1);
      },
    );

    test('a failed adoption write still allows this playback attempt',
        () async {
      when(() => localDataSource.getDownloadById(downloadId)).thenAnswer(
        (_) async => validRow(userId: null, deviceId: null),
      );
      when(() => localDataSource.updateDownload(any(), any()))
          .thenThrow(Exception('disk full'));
      when(() => encryptionService.retrieveKey(downloadId))
          .thenAnswer((_) async => 'a-key');

      // Should not throw despite the adoption write failing.
      await buildEngine().authorize(downloadId);
    });
  });

  test('userMessage never includes raw internal details', () {
    for (final reason in OfflinePlaybackDenialReason.values) {
      final message =
          OfflinePlaybackDeniedException(reason, 'downloadId=secret-internal-id')
              .userMessage;
      expect(message.contains('secret-internal-id'), isFalse);
      expect(message.contains('Exception'), isFalse);
      expect(message.isNotEmpty, isTrue);
    }
  });
}
