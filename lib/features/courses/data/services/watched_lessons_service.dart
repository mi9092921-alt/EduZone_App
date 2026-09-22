import 'package:shared_preferences/shared_preferences.dart';

/// Local optimistic "watched" hints for the course outline accordion.
///
/// Keys are ACCOUNT-SCOPED (`watched_lesson_<userId>_<lessonId>`): these
/// flags are written from whatever account is signed in and are only ever
/// read back for that same account. Scoping here is the structural fix for
/// the cross-account leak where User A's watched hints (persisted across an
/// app kill or a passive session revocation, neither of which runs the
/// logout SharedPreferences wipe) were loaded and OR'd into the outline for
/// whichever account signed in next (Phase 9). A null/empty owner must
/// never touch disk — the callers fall back to server truth only.
class WatchedLessonsService {
  static const String _keyPrefix = 'watched_lesson_';

  static String _key(String ownerId, String lessonId) =>
      '$_keyPrefix${ownerId}_$lessonId';

  static Future<bool> isLessonWatched(String ownerId, String lessonId) async {
    if (ownerId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(ownerId, lessonId)) ?? false;
  }

  static Future<void> markLessonAsWatched(
    String ownerId,
    String lessonId,
  ) async {
    if (ownerId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(ownerId, lessonId), true);
  }

  static Future<void> clearLessonWatchedStatus(
    String ownerId,
    String lessonId,
  ) async {
    if (ownerId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(ownerId, lessonId), false);
  }

  static Future<void> toggleWatchedStatus(
    String ownerId,
    String lessonId,
    bool isWatched,
  ) async {
    if (ownerId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(ownerId, lessonId), isWatched);
  }
}
