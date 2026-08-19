import 'dart:io';
import 'package:app/core/services/storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('accepts an explicit documents directory path', () {
    final service = StorageService(documentsDirectoryPath: 'tmp-dir');
    expect(service, isA<StorageService>());
  });

  test('upgrade from version 4 to 5 creates bookmarks and preserves downloads', () async {
    final tempDir = Directory.systemTemp.createTempSync('eduzone_test_db');
    final dbPath = p.join(tempDir.path, 'eduzone_downloads.db');

    // 1. Manually open and create database at Version 4
    final dbV4 = await openDatabase(
      dbPath,
      version: 4,
      onCreate: (db, version) async {
        // Create table as it was in version 4 (copied from old StorageService._onCreate)
        await db.execute('''
          CREATE TABLE downloaded_lessons (
            id TEXT PRIMARY KEY,
            lesson_id TEXT NOT NULL,
            course_id TEXT NOT NULL,
            course_title TEXT NOT NULL DEFAULT '',
            title TEXT NOT NULL,
            local_path TEXT NOT NULL,
            encrypted_path TEXT NOT NULL,
            audio_path TEXT,
            video_url TEXT NOT NULL,
            audio_url TEXT,
            quality TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            download_status TEXT NOT NULL,
            progress REAL DEFAULT 0.0,
            downloaded_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            checksum TEXT,
            last_accessed_at INTEGER
          )
        ''');
      },
    );

    // 2. Insert dummy downloads at Version 4
    await dbV4.insert('downloaded_lessons', {
      'id': 'dl_1',
      'lesson_id': 'lesson_100',
      'course_id': 'course_200',
      'course_title': 'Test Course',
      'title': 'Test Lesson',
      'local_path': '/path/to/local',
      'encrypted_path': '/path/to/enc',
      'video_url': 'http://test.url',
      'quality': 'high',
      'file_size': 1024,
      'download_status': 'completed',
      'downloaded_at': 123456789,
      'expires_at': 987654321,
    });

    await dbV4.close();

    // 3. Open using updated StorageService (which triggers _onUpgrade to 5)
    final service = StorageService(documentsDirectoryPath: tempDir.path);
    final dbV5 = await service.database;

    // 4. Assert version 4 data is preserved
    final downloads = await dbV5.query('downloaded_lessons');
    expect(downloads.length, equals(1));
    expect(downloads.first['id'], equals('dl_1'));
    expect(downloads.first['lesson_id'], equals('lesson_100'));

    // 5. Assert bookmarks table is created
    final tables = await dbV5.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='bookmarks'",
    );
    expect(tables.length, equals(1));

    // 6. Test bookmarks operations on upgraded DB
    await service.bookmarkCourse('user_abc', 'course_xyz');
    final bookmarks = await service.getBookmarkedCourseIds('user_abc');
    expect(bookmarks, contains('course_xyz'));

    // 7. Cleanup
    await service.close();
    tempDir.deleteSync(recursive: true);
  });

  test('upgrade to version 7 adds user_id/device_id and preserves data', () async {
    final tempDir = Directory.systemTemp.createTempSync('eduzone_test_db_v7');
    final dbPath = p.join(tempDir.path, 'eduzone_downloads.db');

    // 1. Manually create the database at version 6 (schema as it existed
    // immediately before the P6 offline-security hardening pass).
    final dbV6 = await openDatabase(
      dbPath,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloaded_lessons (
            id TEXT PRIMARY KEY,
            lesson_id TEXT NOT NULL,
            course_id TEXT NOT NULL,
            course_title TEXT NOT NULL DEFAULT '',
            title TEXT NOT NULL,
            local_path TEXT NOT NULL,
            encrypted_path TEXT NOT NULL,
            audio_path TEXT,
            video_url TEXT NOT NULL,
            audio_url TEXT,
            quality TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            download_status TEXT NOT NULL,
            progress REAL DEFAULT 0.0,
            downloaded_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            checksum TEXT,
            last_accessed_at INTEGER,
            source_url TEXT,
            link_validated_at INTEGER
          )
        ''');
      },
    );

    // 2. Insert a pre-migration (legacy, unbound) download row.
    await dbV6.insert('downloaded_lessons', {
      'id': 'legacy_dl',
      'lesson_id': 'lesson_1',
      'course_id': 'course_1',
      'course_title': 'Legacy Course',
      'title': 'Legacy Lesson',
      'local_path': '/path/to/local',
      'encrypted_path': '/path/to/enc',
      'video_url': 'http://test.url',
      'quality': 'high',
      'file_size': 1024,
      'download_status': 'completed',
      'downloaded_at': 123456789,
      'expires_at': DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch,
    });
    await dbV6.close();

    // 3. Open with the current StorageService — triggers _onUpgrade(6, 7).
    final service = StorageService(documentsDirectoryPath: tempDir.path);
    final db = await service.database;

    // 4. Legacy row is preserved, with the new columns present and null.
    final rows = await db.query('downloaded_lessons');
    expect(rows.length, equals(1));
    expect(rows.first['id'], equals('legacy_dl'));
    expect(rows.first.containsKey('user_id'), isTrue);
    expect(rows.first['user_id'], isNull);
    expect(rows.first.containsKey('device_id'), isTrue);
    expect(rows.first['device_id'], isNull);

    // 5. A legacy (unbound) row is visible to every account when scoping
    // by owner — it hasn't been "adopted" yet (that happens lazily in
    // OfflinePolicyEngine, not here).
    final scoped = await service.getDownloadedLessons(ownerUserId: 'user_a');
    expect(scoped.map((r) => r['id']), contains('legacy_dl'));

    // 6. A row explicitly bound to a different account is excluded from a
    // scoped query...
    await db.update(
      'downloaded_lessons',
      {'user_id': 'user_b'},
      where: 'id = ?',
      whereArgs: ['legacy_dl'],
    );
    final scopedAfterBind =
        await service.getDownloadedLessons(ownerUserId: 'user_a');
    expect(scopedAfterBind.map((r) => r['id']), isNot(contains('legacy_dl')));

    // ...but still shows up for its actual owner...
    final ownerView =
        await service.getDownloadedLessons(ownerUserId: 'user_b');
    expect(ownerView.map((r) => r['id']), contains('legacy_dl'));

    // ...and is returned by getDownloadsOwnedByOthers() for account-switch
    // purge purposes (OfflineAccountGuard).
    final others = await service.getDownloadsOwnedByOthers('user_a');
    expect(others.map((r) => r['id']), contains('legacy_dl'));
    final othersFromOwnerPerspective =
        await service.getDownloadsOwnedByOthers('user_b');
    expect(
      othersFromOwnerPerspective.map((r) => r['id']),
      isNot(contains('legacy_dl')),
    );

    // 7. Cleanup
    await service.close();
    tempDir.deleteSync(recursive: true);
  });

  group('metadata tamper-evidence (P6.22/P6.23 security_signature)', () {
    late MockFlutterSecureStorage secureStorage;
    late Map<String, String> keyStore;
    late Directory tempDir;
    late StorageService service;

    setUp(() {
      keyStore = {};
      secureStorage = MockFlutterSecureStorage();
      when(() => secureStorage.read(key: any(named: 'key'))).thenAnswer(
        (invocation) async =>
            keyStore[invocation.namedArguments[#key] as String],
      );
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        keyStore[invocation.namedArguments[#key] as String] =
            invocation.namedArguments[#value] as String;
      });

      tempDir = Directory.systemTemp.createTempSync('eduzone_test_db_sig');
      service = StorageService(
        documentsDirectoryPath: tempDir.path,
        secureStorage: secureStorage,
      );
    });

    tearDown(() async {
      await service.close();
      tempDir.deleteSync(recursive: true);
    });

    Future<void> insertRow(
      StorageService svc, {
      String id = 'dl_signed',
      String status = 'completed',
      String? userId = 'user_a',
      String? deviceId = 'device_a',
    }) {
      return svc.insertDownload({
        'id': id,
        'lesson_id': 'lesson_1',
        'course_id': 'course_1',
        'course_title': 'Course',
        'title': 'Lesson',
        'local_path': '/local',
        'encrypted_path': '/enc',
        'video_url': 'http://test',
        'quality': 'high',
        'file_size': 1,
        'download_status': status,
        'downloaded_at': 1,
        'expires_at': DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
        'user_id': userId,
        'device_id': deviceId,
      });
    }

    test('a freshly inserted row is signed and verifies as intact', () async {
      await insertRow(service);
      expect(await service.verifyDownloadSignature('dl_signed'), isTrue);

      final db = await service.database;
      final rows = await db.query('downloaded_lessons');
      expect(rows.first['security_signature'], isNotNull);
    });

    test('updateDownloadStatus re-signs so verification still passes',
        () async {
      await insertRow(service);
      await service.updateDownloadStatus('dl_signed', 'failed');

      expect(await service.verifyDownloadSignature('dl_signed'), isTrue);
    });

    test('updateDownload re-signs so verification still passes', () async {
      await insertRow(service);
      await service.updateDownload('dl_signed', {'user_id': 'user_b'});

      expect(await service.verifyDownloadSignature('dl_signed'), isTrue);
    });

    test(
      'a row edited directly via SQL, bypassing this class, fails verification',
      () async {
        await insertRow(service);

        // Simulate exactly the T4 threat this feature exists for: someone
        // with raw access to the SQLite file (e.g. a SQLite browser on a
        // rooted device) editing expires_at directly, without going
        // through updateDownload/updateDownloadStatus.
        final db = await service.database;
        await db.update(
          'downloaded_lessons',
          {
            'expires_at': DateTime.now()
                .add(const Duration(days: 3650))
                .millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: ['dl_signed'],
        );

        expect(await service.verifyDownloadSignature('dl_signed'), isFalse);
      },
    );

    test(
      'a row edited to change ownership directly via SQL fails verification',
      () async {
        await insertRow(service);

        final db = await service.database;
        await db.update(
          'downloaded_lessons',
          {'user_id': 'user_b'},
          where: 'id = ?',
          whereArgs: ['dl_signed'],
        );

        expect(await service.verifyDownloadSignature('dl_signed'), isFalse);
      },
    );

    test(
        'metadata tamper-evidence (P6.22/P6.23 security_signature) a pre-v8 row with no stored signature fails closed (denied, not adopted)',
        () async {
      final db = await service.database;
      await db.insert('downloaded_lessons', {
        'id': 'dl_legacy',
        'lesson_id': 'lesson_1',
        'course_id': 'course_1',
        'course_title': 'Course',
        'title': 'Lesson',
        'local_path': '/local',
        'encrypted_path': '/enc',
        'video_url': 'http://test',
        'quality': 'high',
        'file_size': 1,
        'download_status': 'completed',
        'downloaded_at': 1,
        'expires_at': DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
      });

      expect(await service.verifyDownloadSignature('dl_legacy'), isFalse);
    });

    test('a nonexistent row fails closed',
        () async {
      expect(await service.verifyDownloadSignature('does_not_exist'), isFalse);
    });

    test(
      'without secure storage, signing is skipped and verification fails closed',
      () async {
        final unsignedDir =
            Directory.systemTemp.createTempSync('eduzone_test_db_unsigned');
        final unsignedService =
            StorageService(documentsDirectoryPath: unsignedDir.path);

        await insertRow(unsignedService);
        expect(
          await unsignedService.verifyDownloadSignature('dl_signed'),
          isFalse,
        );

        final db = await unsignedService.database;
        final rows = await db.query('downloaded_lessons');
        expect(rows.first['security_signature'], isNull);

        await unsignedService.close();
        unsignedDir.deleteSync(recursive: true);
      },
    );

    test('creates and persists download session and chunk manifest', () async {
      final tempDir = Directory.systemTemp.createTempSync('eduzone_manifest');
      final service = StorageService(documentsDirectoryPath: tempDir.path);
      final now = DateTime.now().millisecondsSinceEpoch;

      await service.insertDownloadSession({
        'download_id': 'session-1',
        'lesson_id': 'lesson-1',
        'course_id': 'course-1',
        'content_version': 'v1',
        'quality': '720p',
        'track_type': 'video',
        'total_bytes': 1024,
        'chunk_size': 512,
        'total_chunks': 2,
        'completed_bytes': 0,
        'status': 'downloading',
        'created_at': now,
        'updated_at': now,
        'source_identity': 'lesson-1:v1:720p:video',
        'entitlement_id': 'entitlement-1',
        'encryption_version': 1,
        'container_version': 1,
      });
      await service.upsertDownloadChunk({
        'download_id': 'session-1',
        'chunk_index': 0,
        'plaintext_start': 0,
        'plaintext_length': 512,
        'encrypted_offset': 18,
        'encrypted_length': 528,
        'state': 'pending',
        'downloaded_bytes': 0,
        'attempts': 1,
        'updated_at': now,
        'committed_at': now,
      });

      expect(
        (await service.getDownloadSession('session-1'))?['status'],
        equals('downloading'),
      );
      final chunks = await service.getDownloadChunks('session-1');
      expect(chunks, hasLength(1));
      expect(chunks.single['state'], equals('pending'));

      await service.commitDownloadChunk(
        downloadId: 'session-1',
        chunkIndex: 0,
        completedBytes: 512,
        checksum: 'chunk-checksum',
      );
      expect(
        (await service.getDownloadChunks('session-1')).single['state'],
        equals('verified'),
      );
      await service.commitDownloadChunk(
        downloadId: 'session-1',
        chunkIndex: 0,
        completedBytes: 512,
        checksum: 'chunk-checksum',
      );
      final committedSession = await service.getDownloadSession('session-1');
      expect(committedSession?['completed_bytes'], equals(512));

      await service.close();
      tempDir.deleteSync(recursive: true);
    });
  });
}
