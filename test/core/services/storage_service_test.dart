import 'dart:io';
import 'package:app/core/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
}
