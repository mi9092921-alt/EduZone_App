import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' show Key;
import 'package:flutter/foundation.dart' hide Key;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  static const _databaseVersion = 9;

  static const _tableDownloadedLessons = 'downloaded_lessons';
  static const _tableBookmarks = 'bookmarks';

  /// Secure-storage key for the device-bound HMAC key used to sign
  /// security-critical download metadata (P6.22/P6.23). Never the AES
  /// download-decryption keys — those stay entirely inside
  /// `EncryptionService`, this is a separate key with a separate purpose.
  static const _hmacKeySecureStorageKey = 'offline_metadata_hmac_key';

  final String? _documentsDirectoryPath;

  /// Nullable and passed in explicitly (never auto-constructed here),
  /// mirroring `EncryptionService`'s exact convention: pass null in tests
  /// or contexts where secure storage isn't available, and every signing
  /// method below degrades to "skip signing" rather than throwing. This
  /// keeps every existing `StorageService()` construction site (including
  /// every existing test) working unchanged; production call sites pass a
  /// real `FlutterSecureStorage()` explicitly — see `storage_provider.dart`.
  final FlutterSecureStorage? _secureStorage;

  String? _cachedHmacKey;

  Database? _database;

  StorageService({String? documentsDirectoryPath, FlutterSecureStorage? secureStorage})
      : _documentsDirectoryPath = documentsDirectoryPath,
        _secureStorage = secureStorage;

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
        device_id TEXT,
        security_signature TEXT,
        entitlement_id TEXT,
        server_status TEXT,
        server_issued_at INTEGER,
        server_expires_at INTEGER,
        server_revoked_at INTEGER,
        content_version TEXT,
        audio_checksum TEXT
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

    if (oldVersion < 8) {
      // P6.22/P6.23 ("Metadata Authenticity"): every write to
      // id/user_id/device_id/expires_at/download_status made through this
      // class (insertDownload/updateDownloadStatus/updateDownload — every
      // write site in the app funnels through exactly these three
      // methods) is now signed with a device-bound HMAC key that never
      // touches SQLite. `OfflinePolicyEngine.authorize` recomputes and
      // compares this signature before trusting any of those fields, so
      // an `UPDATE downloaded_lessons SET expires_at = ...` issued outside
      // this app (e.g. a SQLite browser on a rooted device) produces a row
      // whose stored fields no longer match its signature and is denied
      // playback — see OfflinePlaybackDenialReason.tampered.
      //
      // Same migration policy as v7: existing rows get
      // security_signature = NULL rather than being retroactively denied.
      // A NULL signature is treated as "not yet signed" (allowed) by
      // StorageService.verifyDownloadSignature, and gets a real signature
      // automatically the next time anything legitimately updates that
      // row (including the v7 legacy user/device adoption path in
      // OfflinePolicyEngine, which already writes on first play).
      await db.execute('''
        ALTER TABLE $_tableDownloadedLessons ADD COLUMN security_signature TEXT
      ''');
    }

    if (oldVersion < 9) {
      await db.execute('ALTER TABLE $_tableDownloadedLessons ADD COLUMN entitlement_id TEXT');
      await db.execute('ALTER TABLE $_tableDownloadedLessons ADD COLUMN server_status TEXT');
      await db.execute('ALTER TABLE $_tableDownloadedLessons ADD COLUMN server_issued_at INTEGER');
      await db.execute('ALTER TABLE $_tableDownloadedLessons ADD COLUMN server_expires_at INTEGER');
      await db.execute('ALTER TABLE $_tableDownloadedLessons ADD COLUMN server_revoked_at INTEGER');
      await db.execute('ALTER TABLE $_tableDownloadedLessons ADD COLUMN content_version TEXT');
      await db.execute('ALTER TABLE $_tableDownloadedLessons ADD COLUMN audio_checksum TEXT');
      // Existing local downloads have no server-issued entitlement and must
      // therefore not cross the production offline authorization boundary.
      // They remain visible so the user can delete/re-download them.
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
    final id = download['id'] as String;
    final signature = await _sign(id, download);
    await db.insert(
      _tableDownloadedLessons,
      signature == null ? download : {...download, 'security_signature': signature},
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
  ///
  /// SECTION-12 FIX: this previously matched on `lesson_id` alone with no
  /// account scoping, unlike every other lookup in this class
  /// (`getDownloadedLessons`, `getDownloadsOwnedByOthers`). Its only caller
  /// (`DownloadRepositoryImpl.startDownload`'s "already downloaded" guard)
  /// treats a non-null result as "this lesson is already downloaded, deny
  /// starting a new download" without re-checking ownership afterward —
  /// unlike `OfflinePolicyEngine.authorize`, which always re-verifies
  /// ownership before allowing playback. `OfflineAccountGuard` purges a
  /// previous account's downloads on next login, but that purge is
  /// best-effort (P6.20 doc comment: "a missed purge on one login is
  /// retried on the next one") — so a leftover row from a different
  /// account signed in earlier on this device could still exist here at
  /// the moment this guard runs, and would incorrectly block the *current*
  /// account from downloading a lesson they are actually entitled to.
  /// Scoping to [ownerUserId] the same way [getDownloadedLessons] already
  /// does (excluding rows bound to a different account, but still matching
  /// legacy `user_id IS NULL` rows so they're correctly adopted rather than
  /// duplicated) closes that gap.
  Future<Map<String, dynamic>?> getDownloadByLessonId(
    String lessonId, {
    String? ownerUserId,
  }) async {
    final db = await database;
    final results = ownerUserId == null
        ? await db.query(
            _tableDownloadedLessons,
            where: 'lesson_id = ?',
            whereArgs: [lessonId],
            limit: 1,
          )
        : await db.query(
            _tableDownloadedLessons,
            where: 'lesson_id = ? AND (user_id IS NULL OR user_id = ?)',
            whereArgs: [lessonId, ownerUserId],
            limit: 1,
          );
    return results.isNotEmpty ? results.first : null;
  }

  /// Gets a download by its ID.
  Future<Map<String, dynamic>?> getDownloadById(
    String id, {
    String? ownerUserId,
  }) async {
    final db = await database;
    final results = ownerUserId == null
        ? await db.query(
            _tableDownloadedLessons,
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          )
        : await db.query(
            _tableDownloadedLessons,
            where: 'id = ? AND user_id = ?',
            whereArgs: [id, ownerUserId],
            limit: 1,
          );
    return results.isNotEmpty ? results.first : null;
  }

  /// Updates the download status.
  Future<void> updateDownloadStatus(String id, String status) async {
    final db = await database;
    final changes = {'download_status': status};
    final signature = await _signAfterMerge(db, id, changes);
    await db.update(
      _tableDownloadedLessons,
      signature == null ? changes : {...changes, 'security_signature': signature},
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
    final signature = await _signAfterMerge(db, id, updates);
    await db.update(
      _tableDownloadedLessons,
      signature == null ? updates : {...updates, 'security_signature': signature},
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

  // ── Metadata tamper-evidence (P6.22/P6.23) ────────────────────────────
  //
  // `security_signature` is an HMAC-SHA256 over the authorization and
  // integrity metadata used by OfflinePolicyEngine: ownership, status,
  // expiry, entitlement identity, content version, file paths and hashes.
  // The HMAC key
  // lives only in secure storage (Keystore/Keychain-backed), never in
  // SQLite next to the data it protects — so editing the SQLite file
  // directly (the exact T4 threat this whole file's callers exist to
  // defend against) can change those field values, but can't produce a
  // matching signature without also compromising secure storage.
  //
  // This raises the bar against local metadata tampering; it is
  // explicitly NOT a server-issued license (P6.4) — the key is
  // device-generated and device-held, not server-controlled, so it can't
  // detect or prevent a *legitimate*-looking modification made through
  // this app's own code by someone who has fully compromised the device
  // (they could, in principle, extract the HMAC key too). See
  // OfflinePolicyEngine's doc comment and SECURITY.md for the full
  // honesty-required boundary statement.

  /// Lazily generates (once per device install) and caches the HMAC key.
  /// A missing/unavailable secure storage is a security failure, not a reason
  /// to silently disable metadata authenticity.
  Future<String?> _getHmacKey() async {
    final secureStorage = _secureStorage;
    if (secureStorage == null) return null;
    final cached = _cachedHmacKey;
    if (cached != null) return cached;

    try {
      var key = await secureStorage.read(key: _hmacKeySecureStorageKey);
      if (key == null) {
        key = Key.fromSecureRandom(32).base64;
        await secureStorage.write(key: _hmacKeySecureStorageKey, value: key);
      }
      _cachedHmacKey = key;
      return key;
    } catch (e) {
      debugPrint('[StorageService] HMAC key unavailable: ${e.runtimeType}');
      return null;
    }
  }

  /// Canonical, order-independent string built from exactly the fields
  /// OfflinePolicyEngine's authorization decision depends on. [values] may
  /// be a full row or just the fields being changed merged over the
  /// current row (see [_signAfterMerge]) — either way, missing fields are
  /// treated as empty rather than throwing, so a partial map never crashes
  /// signing.
  String _canonicalPayload(String id, Map<String, dynamic> values) {
    final userId = values['user_id'] as String? ?? '';
    final deviceId = values['device_id'] as String? ?? '';
    final expiresAt = values['expires_at']?.toString() ?? '';
    final status = values['download_status'] as String? ?? '';
    final entitlementId = values['entitlement_id']?.toString() ?? '';
    final serverStatus = values['server_status']?.toString() ?? '';
    final serverExpiresAt = values['server_expires_at']?.toString() ?? '';
    final contentVersion = values['content_version']?.toString() ?? '';
    final encryptedPath = values['encrypted_path']?.toString() ?? '';
    final audioPath = values['audio_path']?.toString() ?? '';
    final checksum = values['checksum']?.toString() ?? '';
    final audioChecksum = values['audio_checksum']?.toString() ?? '';
    return '$id|$userId|$deviceId|$expiresAt|$status|$entitlementId|$serverStatus|'
        '$serverExpiresAt|$contentVersion|$encryptedPath|$audioPath|$checksum|$audioChecksum';
  }

  /// Returns the HMAC-SHA256 signature for [values], or null if signing
  /// isn't available on this instance (see [_getHmacKey]).
  Future<String?> _sign(String id, Map<String, dynamic> values) async {
    final key = await _getHmacKey();
    if (key == null) return null;
    final hmac = crypto.Hmac(crypto.sha256, utf8.encode(key));
    return hmac.convert(utf8.encode(_canonicalPayload(id, values))).toString();
  }

  /// Reads the current row for [id] (if any), merges [changes] on top of
  /// it, and signs the result. Returns null when the row doesn't exist yet
  /// (nothing to merge against — `insertDownload` handles the create case
  /// separately) or when signing isn't available. Centralizing this here,
  /// rather than in each of the three write methods, is what makes every
  /// write path across the app (repository, execution service, link
  /// refresher, crash recovery, policy-engine adoption) signed by
  /// construction instead of needing every call site to remember to do it.
  Future<String?> _signAfterMerge(
    DatabaseExecutor db,
    String id,
    Map<String, dynamic> changes,
  ) async {
    final current = await db.query(
      _tableDownloadedLessons,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (current.isEmpty) return null;
    final merged = {...current.first, ...changes};
    return _sign(id, merged);
  }

  /// Re-verifies [id]'s stored `security_signature` against its current
  /// field values. Returns:
  ///  - `true` only when a signature exists, this instance can recompute
  ///    it, and it matches the row's current fields.
  ///  - `false` when the row is missing, unsigned, or the signature cannot
  ///    be recomputed. The offline playback gate therefore fails closed.
  ///
  /// The comparison below is constant-time over the two (fixed-length,
  /// hex-encoded SHA-256) signature strings: it XORs every byte pair and
  /// accumulates the result with `|=` instead of returning as soon as a
  /// mismatch is found, so recognizing a forged signature doesn't take
  /// measurably less time than recognizing a valid one. A prior version of
  /// this method attempted the same goal by re-hashing both sides with
  /// `expected` itself as the HMAC key and then comparing the two hashes
  /// with plain `==` — which doesn't actually buy anything: Dart's String
  /// `==` still short-circuits on the first differing character, so that
  /// final comparison remained exactly as timing-variable as comparing
  /// `expected`/`storedSignature` directly, just with two extra hashes
  /// computed first.
  Future<bool> verifyDownloadSignature(String id) async {
    final db = await database;
    final rows = await db.query(
      _tableDownloadedLessons,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final row = rows.first;
    final storedSignature = row['security_signature'] as String?;
    if (storedSignature == null || storedSignature.isEmpty) return false;

    final expected = await _sign(id, row);
    if (expected == null) return false;
    if (expected.length != storedSignature.length) return false;

    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected.codeUnitAt(i) ^ storedSignature.codeUnitAt(i);
    }
    return diff == 0;
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
  Future<List<Map<String, dynamic>>> getDownloadsByStatus(
    String status, {
    String? ownerUserId,
  }) async {
    final db = await database;
    return ownerUserId == null
        ? await db.query(
            _tableDownloadedLessons,
            where: 'download_status = ?',
            whereArgs: [status],
            orderBy: 'downloaded_at DESC',
          )
        : await db.query(
            _tableDownloadedLessons,
            where: 'download_status = ? AND user_id = ?',
            whereArgs: [status, ownerUserId],
            orderBy: 'downloaded_at DESC',
          );
  }

  /// Gets all downloads for a specific course.
  Future<List<Map<String, dynamic>>> getDownloadsByCourse(
    String courseId, {
    String? ownerUserId,
  }) async {
    final db = await database;
    return ownerUserId == null
        ? await db.query(
            _tableDownloadedLessons,
            where: 'course_id = ?',
            whereArgs: [courseId],
            orderBy: 'downloaded_at DESC',
          )
        : await db.query(
            _tableDownloadedLessons,
            where: 'course_id = ? AND user_id = ?',
            whereArgs: [courseId, ownerUserId],
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
  Future<List<Map<String, dynamic>>> getExpiredDownloads({
    String? ownerUserId,
  }) async {
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
        ${ownerUserId == null ? '' : 'AND user_id = ?'}
      ''',
      ownerUserId == null ? [now, orphanThreshold] : [now, orphanThreshold, ownerUserId],
    );
  }

  /// Gets the total storage used by all downloads.
  ///
  /// SQLite's SUM() aggregate may return [double] even for INTEGER columns when
  /// the summed values were stored via sqflite's num codec. Using `as int?`
  /// directly would throw a [TypeError]; cast via [num] instead.
  Future<int> getTotalStorageUsed({String? ownerUserId}) async {
    final db = await database;
    final result = ownerUserId == null
        ? await db.rawQuery(
            'SELECT SUM(file_size) as total FROM $_tableDownloadedLessons WHERE download_status = ?',
            ['completed'],
          )
        : await db.rawQuery(
            'SELECT SUM(file_size) as total FROM $_tableDownloadedLessons '
            'WHERE download_status = ? AND user_id = ?',
            ['completed', ownerUserId],
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