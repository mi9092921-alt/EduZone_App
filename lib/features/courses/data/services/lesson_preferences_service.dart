import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

class LessonPreferencesService {
  Future<String?> getLastWatchedLesson(String courseId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
      StorageKeys.lastWatchedLesson(int.tryParse(courseId) ?? 0),
    );
  }

  Future<void> saveLastWatchedLesson(String courseId, String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.lastWatchedLesson(int.tryParse(courseId) ?? 0),
      lessonId,
    );
  }
}
