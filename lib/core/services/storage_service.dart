import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Local database service for managing downloaded lessons metadata
/// and user bookmarks.
///
/// Uses SQLite to store download information including:
/// - Lesson and course IDs
/// - File paths (encrypted and decrypted)
/// - Download status and progress
/// - Expiration dates
/// - File sizes and checksums
class StorageService {
  static const _databaseName = 'eduzone_downloads.db';
  static const _databaseVersion = 7;

  static const _tableDownloadedLessons = 'downloaded_lessons';
  static const _tableBookmarks = 'bookmarks';

  final String? _documentsDirectoryPath;

  Database? _database;

  StorageService({String? documentsDirectoryPath})
      : _documentsDirectoryPath = documentsDirectoryPath;

  /// Gets the database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initializes the SQLite database and creates tables.
  Future<Database> _initDatabase() async {
    final documentsDirectory = _documentsDirectoryPath == null
        ? await getApplicationDocumentsDirectory()
        : Directory(_documentsDirectoryPath);
    if (!await documentsDirectory.exists()) {
      await documentsDirectory.create(recursive: true);
    }

    final path = join(documentsDirectory.path, _databaseName);
    debugPrint('[StorageService] DB path: $path');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates the database tables on first initialization.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableDownloadedLessons (
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
        link_validated_at INTEGER,
        user_id TEXT,
        device_id TEXT
      )
    ''');

    // Create indexes for common queries
    await db.execute('''
      CREATE INDEX idx_downloads_lesson ON $_tableDownloadedLessons(lesson_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_downloads_course ON $_tableDownloadedLessons(course_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_downloads_status ON $_tableDownloadedLessons(download_status)
    ''');
    await db.execute('''
      CREATE INDEX idx_downloads_expires ON $_tableDownloadedLessons(expires_at)
    ''');
    await db.execute('''
      CREATE INDEX idx_downloads_user ON $_tableDownloadedLessons(user_id)
    ''');

    // Bookmarks table — device-local, scoped per user
    await db.execute('''
      CREATE TABLE $_tableBookmarks (
        user_id TEXT NOT NULL,
        course_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY (user_id, course_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_bookmarks_user ON $_tableBookmarks(user_id)
    ''');
  }

  /// Handles database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add video_url column for resume functionality
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN video_url TEXT NOT NULL DEFAULT ''
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN course_title TEXT NOT NULL DEFAULT ''
      ''');
    }

    if (oldVersion < 4) {
      // Add dual-track audio columns (null = muxed single-file download)
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN audio_path TEXT
      ''');
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN audio_url TEXT
      ''');
    }

    if (oldVersion < 5) {
      // Add bookmarks table — device-local, scoped per user
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableBookmarks (
          user_id TEXT NOT NULL,
          course_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (user_id, course_id)
        )
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_bookmarks_user
          ON $_tableBookmarks(user_id)
      ''');
    }

    if (oldVersion < 6) {
      // source_url: original URL passed to startDownload() — used to re-fetch
      //   a fresh server link (<6h TTL) when resuming after a long pause.
      // link_validated_at: epoch-ms of the last successful validateCourseAccess
      //   call — drives the "stale after 5h" check in resumeDownload().
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN source_url TEXT
      ''');
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN link_validated_at INTEGER
      ''');
    }

    if (oldVersion < 7) {
      // Offline/download security hardening (see
      // EduZone_Offline_Download_Security_Trusted_Playback_Architecture.md
      // P6.19/P6.20): bind each download to the account and device that
      // created it, so a different account logging in on this device can
      // never see or play back another account's offline content, and a
      // download copied to a different device can't silently play there
      // either.
      //
      // Migration policy for rows that already exist at this point (created
      // before this column existed): they are left with user_id/device_id
      // = NULL rather than retroactively invalidated. `OfflinePolicyEngine`
      // adopts each one to the current account/device the first time it is
      // played after this upgrade — see offline_policy_engine.dart. This
      // avoids breaking playback of content a real user already
      // legitimately downloaded on this same install, while still closing
      // the gap for every download made from this point on.
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN user_id TEXT
      ''');
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN device_id TEXT
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_downloads_user
          ON $_tableDownloadedLessons(user_id)
      ''');
    }

    // Preventive data-integrity sweep: any 'completed' row that is missing
    // critical numeric fields would cause a silent TypeError in _mapToEntity
    // (swallowed by the catch block), making it invisible in the downloads
    // screen. Re-classify such rows as 'failed' so they are visible and can
    // be cleaned up rather than silently disappearing.
    await db.rawUpdate('''
      UPDATE $_tableDownloadedLessons
      SET download_status = 'failed'
      WHERE download_status = 'completed'
        AND (file_size IS NULL OR downloaded_at IS NULL OR expires_at IS NULL)
    ''');
    debugPrint('[StorageService] onUpgrade $oldVersion→$newVersion complete');
  }

  /// Inserts a new download record.
  Future<void> insertDownload(Map<String, dynamic> download) async {
    final db = await database;
    await db.insert(
      _tableDownloadedLessons,
      download,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Gets all downloaded lessons (all statuses — for internal/debug use).
  Future<List<Map<String, dynamic>>> getAllDownloadedLessons() async {
    final db = await database;
    return await db.query(
      _tableDownloadedLessons,
      orderBy: 'downloaded_at DESC',
    );
  }

  /// Gets all downloaded lessons for display in the Downloads screen.
  ///
  /// Returns ALL statuses (pending, downloading, paused, completed, failed)
  /// so that the UI can render the appropriate state for each download.
  /// The repository layer handles mapping errors gracefully by skipping
  /// corrupt records instead of crashing the entire list.
  ///
  /// When [ownerUserId] is provided, rows bound to a *different* account
  /// (`user_id` set and not equal to [ownerUserId]) are excluded — this is
  /// a privacy/UX measure (P6.20) so a second account on the same device
  /// never even sees another account's download tiles, on top of (not
  /// instead of) the playback-time authorization enforced separately by
  /// `OfflinePolicyEngine`. Legacy rows with `user_id IS NULL` are always
  /// included; see the v7 migration note above.
  Future<List<Map<String, dynamic>>> getDownloadedLessons({
    String? ownerUserId,
  }) async {
    final db = await database;
    final rows = ownerUserId == null
        ? await db.query(
            _tableDownloadedLessons,
            orderBy: 'downloaded_at DESC',
          )
        : await db.query(
            _tableDownloadedLessons,
            where: 'user_id IS NULL OR user_id = ?',
            whereArgs: [ownerUserId],
            orderBy: 'downloaded_at DESC',
          );
    debugPrint('[StorageService] getDownloadedLessons: count=${rows.length}');
    return rows;
  }

  /// Returns every download row bound (`user_id` set) to an account other
  /// than [currentUserId]. Used by `OfflineAccountGuard` right after login
  /// to purge any offline content left behind by a previous account on this
  /// device (P6.20). Rows with `user_id IS NULL` (legacy/unbound) are never
  /// returned here — those are adopted lazily by `OfflinePolicyEngine`
  /// instead of being treated as "someone else's".
  Future<List<Map<String, dynamic>>> getDownloadsOwnedByOthers(
    String currentUserId,
  ) async {
    final db = await database;
    return await db.query(
      _tableDownloadedLessons,
      where: 'user_id IS NOT NULL AND user_id != ?',
      whereArgs: [currentUserId],
    );
  }

  /// Gets a download by lesson ID.
  Future<Map<String, dynamic>?> getDownloadByLessonId(String lessonId) async {
    final db = await database;
    final results = await db.query(
      _tableDownloadedLessons,
      where: 'lesson_id = ?',
      whereArgs: [lessonId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Gets a download by its ID.
  Future<Map<String, dynamic>?> getDownloadById(String id) async {
    final db = await database;
    final results = await db.query(
      _tableDownloadedLessons,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Updates the download status.
  Future<void> updateDownloadStatus(String id, String status) async {
    final db = await database;
    await db.update(
      _tableDownloadedLessons,
      {'download_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates the download progress.
  Future<void> updateProgress(String id, double progress) async {
    final db = await database;
    await db.update(
      _tableDownloadedLessons,
      {'progress': progress},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates multiple fields of a download.
  Future<void> updateDownload(String id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update(
      _tableDownloadedLessons,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Updates the last accessed timestamp.
  Future<void> updateLastAccessed(String id) async {
    final db = await database;
    await db.update(
      _tableDownloadedLessons,
      {'last_accessed_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a download record.
  Future<void> deleteDownload(String id) async {
    final db = await database;
    await db.delete(
      _tableDownloadedLessons,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Gets all downloads with a specific status.
  Future<List<Map<String, dynamic>>> getDownloadsByStatus(String status) async {
    final db = await database;
    return await db.query(
      _tableDownloadedLessons,
      where: 'download_status = ?',
      whereArgs: [status],
      orderBy: 'downloaded_at DESC',
    );
  }

  /// Gets all downloads for a specific course.
  Future<List<Map<String, dynamic>>> getDownloadsByCourse(String courseId) async {
    final db = await database;
    return await db.query(
      _tableDownloadedLessons,
      where: 'course_id = ?',
      whereArgs: [courseId],
      orderBy: 'downloaded_at DESC',
    );
  }

  /// Gets expired downloads (expires_at < current time) **or** records that
  /// are stuck in a non-recoverable terminal state (failed / pending) older
  /// than 24 hours.
  ///
  /// Previously this method only looked at [expires_at], so completed records
  /// expiring in the future were never cleaned up, and failed/pending orphans
  /// were never included at all — making the Cleanup button a no-op.
  Future<List<Map<String, dynamic>>> getExpiredDownloads() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    // Orphan threshold: failed or pending records older than 24 h
    final orphanThreshold =
        DateTime.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
    return await db.rawQuery(
      '''
      SELECT * FROM $_tableDownloadedLessons
      WHERE expires_at < ?
         OR (download_status IN ('failed', 'pending')
             AND downloaded_at < ?)
      ''',
      [now, orphanThreshold],
    );
  }

  /// Gets the total storage used by all downloads.
  ///
  /// SQLite's SUM() aggregate may return [double] even for INTEGER columns when
  /// the summed values were stored via sqflite's num codec. Using `as int?`
  /// directly would throw a [TypeError]; cast via [num] instead.
  Future<int> getTotalStorageUsed() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(file_size) as total FROM $_tableDownloadedLessons WHERE download_status = ?',
      ['completed'],
    );
    final total = result.first['total'];
    if (total == null) return 0;
    if (total is int) return total;
    if (total is num) return total.toInt();
    return 0;
  }

  /// Gets the count of downloads by status.
  Future<Map<String, int>> getDownloadsCountByStatus() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT download_status, COUNT(*) as count 
      FROM $_tableDownloadedLessons 
      GROUP BY download_status
    ''');
    
    final counts = <String, int>{};
    for (final row in results) {
      counts[row['download_status'] as String] = row['count'] as int;
    }
    return counts;
  }

  /// Deletes all downloads for a specific course.
  Future<void> deleteDownloadsByCourse(String courseId) async {
    final db = await database;
    await db.delete(
      _tableDownloadedLessons,
      where: 'course_id = ?',
      whereArgs: [courseId],
    );
  }

  /// Clears all download records (use with caution).
  Future<void> clearAllDownloads() async {
    final db = await database;
    await db.delete(_tableDownloadedLessons);
  }

  // ─── Bookmarks ──────────────────────────────────────────────────────────────

  /// Returns all bookmarked course IDs for the given [userId].
  Future<List<String>> getBookmarkedCourseIds(String userId) async {
    final db = await database;
    final rows = await db.query(
      _tableBookmarks,
      columns: ['course_id'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => r['course_id'] as String).toList();
  }

  /// Adds a bookmark for [courseId] under [userId].
  ///
  /// Uses `ConflictAlgorithm.ignore` so duplicate inserts are silently
  /// skipped without throwing.
  Future<void> bookmarkCourse(String userId, String courseId) async {
    final db = await database;
    await db.insert(
      _tableBookmarks,
      {
        'user_id': userId,
        'course_id': courseId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Removes the bookmark for [courseId] under [userId].
  Future<void> unbookmarkCourse(String userId, String courseId) async {
    final db = await database;
    await db.delete(
      _tableBookmarks,
      where: 'user_id = ? AND course_id = ?',
      whereArgs: [userId, courseId],
    );
  }

  /// Closes the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}