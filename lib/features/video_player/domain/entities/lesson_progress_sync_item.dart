class LessonProgressSyncItem {
  final String courseId;
  final String lessonId;
  final bool completed;
  final double progressPct;
  final int? watchTimeSec;

  const LessonProgressSyncItem({
    required this.courseId,
    required this.lessonId,
    required this.completed,
    required this.progressPct,
    this.watchTimeSec,
  });

  String get key => '$courseId:$lessonId';

  LessonProgressSyncItem merge(LessonProgressSyncItem next) {
    return LessonProgressSyncItem(
      courseId: courseId,
      lessonId: lessonId,
      completed: completed || next.completed,
      progressPct: next.progressPct > progressPct ? next.progressPct : progressPct,
      watchTimeSec: next.watchTimeSec ?? watchTimeSec,
    );
  }
}
