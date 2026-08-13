import 'dart:io';

import 'package:app/core/services/encryption_service.dart';
import 'package:app/features/downloads/application/services/offline_account_guard.dart';
import 'package:app/features/downloads/data/datasources/download_local_ds.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDownloadLocalDataSource extends Mock
    implements DownloadLocalDataSource {}

class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  late MockDownloadLocalDataSource localDataSource;
  late MockEncryptionService encryptionService;
  late OfflineAccountGuard guard;
  late Directory tempDir;

  const currentUserId = 'user_current';

  setUp(() {
    localDataSource = MockDownloadLocalDataSource();
    encryptionService = MockEncryptionService();
    guard = OfflineAccountGuard(
      localDataSource: localDataSource,
      encryptionService: encryptionService,
    );
    tempDir = Directory.systemTemp.createTempSync('offline_account_guard_test');

    when(() => encryptionService.deleteKey(any())).thenAnswer((_) async {});
    when(() => localDataSource.deleteDownload(any()))
        .thenAnswer((_) async {});
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('purges every download owned by a different account', () async {
    final encPath = '${tempDir.path}/lesson_a.edz';
    File(encPath).writeAsBytesSync([1]);
    File('$encPath.idx').writeAsBytesSync([1]);
    File('$encPath.tmp').writeAsBytesSync([1]);

    when(() => localDataSource.getDownloadsOwnedByOthers(currentUserId))
        .thenAnswer(
      (_) async => [
        {'id': 'dl_other_1', 'encrypted_path': encPath, 'audio_path': null},
      ],
    );

    final purged = await guard.purgeDownloadsForOtherAccounts(currentUserId);

    expect(purged, equals(1));
    expect(File(encPath).existsSync(), isFalse);
    expect(File('$encPath.idx').existsSync(), isFalse);
    expect(File('$encPath.tmp').existsSync(), isFalse);
    verify(() => encryptionService.deleteKey('dl_other_1')).called(1);
    verify(() => localDataSource.deleteDownload('dl_other_1')).called(1);
  });

  test('does nothing when there are no other accounts on this device',
      () async {
    when(() => localDataSource.getDownloadsOwnedByOthers(currentUserId))
        .thenAnswer((_) async => []);

    final purged = await guard.purgeDownloadsForOtherAccounts(currentUserId);

    expect(purged, equals(0));
    verifyNever(() => encryptionService.deleteKey(any()));
    verifyNever(() => localDataSource.deleteDownload(any()));
  });

  test('a missing file does not stop the key and row from being purged',
      () async {
    when(() => localDataSource.getDownloadsOwnedByOthers(currentUserId))
        .thenAnswer(
      (_) async => [
        {
          'id': 'dl_missing_file',
          'encrypted_path': '${tempDir.path}/does_not_exist.edz',
          'audio_path': null,
        },
      ],
    );

    final purged = await guard.purgeDownloadsForOtherAccounts(currentUserId);

    expect(purged, equals(1));
    verify(() => encryptionService.deleteKey('dl_missing_file')).called(1);
    verify(() => localDataSource.deleteDownload('dl_missing_file')).called(1);
  });

  test('a row that fails to delete is not counted as purged', () async {
    when(() => localDataSource.getDownloadsOwnedByOthers(currentUserId))
        .thenAnswer(
      (_) async => [
        {'id': 'dl_fails', 'encrypted_path': null, 'audio_path': null},
      ],
    );
    when(() => localDataSource.deleteDownload('dl_fails'))
        .thenThrow(Exception('db locked'));

    final purged = await guard.purgeDownloadsForOtherAccounts(currentUserId);

    expect(purged, equals(0));
  });
}
