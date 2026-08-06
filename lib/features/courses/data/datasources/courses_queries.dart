/// Reusable PostgREST `select()` string fragments for the `courses`
/// feature's Supabase queries.
///
/// Extracted from `courses_remote_ds_impl.dart`, where the same two
/// fragments were typed out identically (down to indentation) in 3
/// separate `.select('''...''')` calls each — `teacherJoin` in
/// `getCourseOutline`, `getPublicCourses`, and `getCoursesByIds`;
/// `lightSectionsWithLessons` in `getMyCourses`, `getPublicCourses`, and
/// `getCoursesByIds`. A future column change (e.g. adding `teacher_bio`)
/// previously would have needed to be applied in 3 places by hand; now
/// it's one constant.
abstract final class CoursesQueries {
  /// The `teacher:users!teacher_id(...)` join used everywhere a course's
  /// instructor name/avatar needs to be resolved
  /// (see `CoursesJsonMapper.applyInstructorFields`).
  static const String teacherJoin =
      'teacher:users!teacher_id(first_name, last_name, avatar_url)';

  /// The lightweight `sections -> lessons` join used by list/summary
  /// queries that only need lesson metadata (id, title, preview flag,
  /// duration) — NOT `getCourseOutline`, which needs the full
  /// section/lesson column set plus `user_progress` and has its own
  /// select string.
  static const String lightSectionsWithLessons = '''
    sections(
      id,
      course_id,
      tenant_id,
      title,
      lessons(id, section_id, course_id, title, is_preview, duration_sec)
    )
  ''';
}
