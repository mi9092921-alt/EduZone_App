import 'package:equatable/equatable.dart';

/// Represents the current progress state for a video/lesson being watched.
///
/// Used by [VideoProgressNotifier] to track local progress
/// before syncing to the `user_progress` table.
class VideoProgress extends Equatable {
  final String courseId;
  final String lessonId;
  final double progressPct;
  final int watchTimeSec;
  final bool isCompleted;

  const VideoProgress({
    required this.courseId,
    required this.lessonId,
    this.progressPct = 0.0,
    this.watchTimeSec = 0,
    this.isCompleted = false,
  });

  VideoProgress copyWith({
    double? progressPct,
    int? watchTimeSec,
    bool? isCompleted,
  }) {
    return VideoProgress(
      courseId: courseId,
      lessonId: lessonId,
      progressPct: progressPct ?? this.progressPct,
      watchTimeSec: watchTimeSec ?? this.watchTimeSec,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [courseId, lessonId, progressPct, watchTimeSec, isCompleted];
}
