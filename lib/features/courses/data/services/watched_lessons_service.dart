import 'package:shared_preferences/shared_preferences.dart';

class WatchedLessonsService {
  static const String _keyPrefix = 'watched_lesson_';

  static Future<bool> isLessonWatched(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix$lessonId') ?? false;
  }

  static Future<void> markLessonAsWatched(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$lessonId', true);
  }

  static Future<void> clearLessonWatchedStatus(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$lessonId', false);
  }

  static Future<void> toggleWatchedStatus(String lessonId, bool isWatched) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$lessonId', isWatched);
  }
}
