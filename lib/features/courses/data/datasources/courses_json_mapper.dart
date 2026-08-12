import 'package:flutter/foundation.dart';

/// Pure, Supabase-free JSON-shaping helpers used by
/// [CoursesRemoteDataSourceImpl] to turn raw PostgREST/RPC response maps
/// into the shape `Course.fromJson`/`CourseEnrollment.fromJson` expect.
///
/// Extracted from `courses_remote_ds_impl.dart` for two reasons:
///
/// 1. **De-duplication.** [applyInstructorFields] was byte-for-byte
///    duplicated across `getCourseOutline`, `getPublicCourses`, and
///    `getCoursesByIds`; [backfillTotalLessons] was duplicated across
///    `getPublicCourses` and `getCoursesByIds` (with only the former
///    having the debug-log block — now a `debugLog` flag instead of a
///    silently-diverging copy).
/// 2. **Testability.** All 5 methods here are pure map-in-map-out
///    transformations with zero Supabase/network dependency — they can be
///    unit-tested directly against plain `Map` fixtures, which was not
///    previously possible without mocking an entire Supabase response.
///
/// Every method mutates [target] in place (matching the original
/// imperative style in the datasource) and returns nothing.
abstract final class CoursesJsonMapper {
  /// Flattens a joined `teacher:users!teacher_id(first_name, last_name,
  /// avatar_url)` map into `target['instructor_name']` /
  /// `target['instructor_avatar']`. No-ops if [teacherJson] is null.
  static void applyInstructorFields({
    required Map<String, dynamic> target,
    required Map? teacherJson,
  }) {
    if (teacherJson == null) return;

    final firstName = teacherJson['first_name'] as String? ?? '';
    final lastName = teacherJson['last_name'] as String? ?? '';
    target['instructor_name'] = '$firstName $lastName'.trim();
    target['instructor_avatar'] = teacherJson['avatar_url'];
  }

  /// Recomputes `target['total_lessons']` from the joined
  /// `sections -> lessons` payload in [rawJson] when the stored counter
  /// is `0` (courses seeded before the patch-16 trigger still carry `0`
  /// instead of the real count, and `0 != null` so the presenter's `??`
  /// fallback never fires).
  ///
  /// When [debugLog] is true (only `getPublicCourses` opts in — matches
  /// the original code, which only had this debug block on that one
  /// call site), logs the before/after counts in debug builds.
  static void backfillTotalLessons({
    required Map<String, dynamic> rawJson,
    required Map<String, dynamic> target,
    bool debugLog = false,
  }) {
    final storedTotal = (rawJson['total_lessons'] as num?)?.toInt() ?? 0;
    if (storedTotal == 0) {
      final sections = rawJson['sections'] as List? ?? const [];
      final computed = sections.fold<int>(0, (acc, s) {
        final lessons = (s as Map)['lessons'] as List? ?? const [];
        return acc + lessons.length;
      });
      target['total_lessons'] = computed;
    }

    if (debugLog && kDebugMode) {
      final id = rawJson['id'];
      final title = rawJson['title'];
      final inMap = target['total_lessons'];
      debugPrint(
        '[Discover] $title ($id) '
        'stored=$storedTotal → injected=$inMap',
      );
    }
  }

  /// Flattens & sorts `target['learning_objectives']` from
  /// `[{objective: "...", order_index: 0}, ...]` to `["...", ...]`,
  /// ordered by `order_index`. No-ops if the field isn't a `List`.
  static void flattenLearningObjectives(Map<String, dynamic> target) {
    final rawObjectives = target['learning_objectives'];
    if (rawObjectives is! List) return;

    final sortedObjs = List<Map<String, dynamic>>.from(
      rawObjectives.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    )..sort(
        (a, b) => ((a['order_index'] as int? ?? 0))
            .compareTo(b['order_index'] as int? ?? 0),
      );

    target['learning_objectives'] = sortedObjs
        .map((o) => o['objective'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Flattens `target['prerequisites']` from
  /// `[{prerequisite_course_id: "...", prerequisite_course: {title: "..."}}]`
  /// to `["Title", ...]`, preferring the joined course title and falling
  /// back to the raw id when the title isn't available. No-ops if the
  /// field isn't a `List`.
  static void flattenPrerequisites(Map<String, dynamic> target) {
    final rawPrereqs = target['prerequisites'];
    if (rawPrereqs is! List) return;

    target['prerequisites'] = rawPrereqs
        .whereType<Map>()
        .map((p) {
          final prereqCourse = p['prerequisite_course'] as Map?;
          if (prereqCourse != null && prereqCourse['title'] is String) {
            return prereqCourse['title'] as String;
          }
          return p['prerequisite_course_id'] as String? ?? '';
        })
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Defensive client-side filter: keeps only `user_progress` rows
  /// belonging to [userId] inside `target['sections'][*]['lessons'][*]`
  /// (the RPC/join can return rows for other users depending on RLS
  /// policy shape; this is a belt-and-suspenders guard, not the primary
  /// access control). When [userId] is null, every lesson's
  /// `user_progress` is cleared to an empty list.
  static void filterUserProgressForCurrentUser(
    Map<String, dynamic> target,
    String? userId,
  ) {
    if (target['sections'] is! List) return;

    for (final section in target['sections'] as List) {
      if (section is! Map || section['lessons'] is! List) continue;

      for (final lesson in section['lessons'] as List) {
        if (lesson is! Map || lesson['user_progress'] is! List) continue;

        final rawProgressList = lesson['user_progress'] as List;
        if (userId == null) {
          rawProgressList.clear();
        } else {
          rawProgressList.retainWhere((p) => p is Map && p['user_id'] == userId);
        }
      }
    }
  }
}
