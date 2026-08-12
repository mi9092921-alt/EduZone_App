/// Cross-feature facade for `features/courses`.
///
/// `video_player` needs the enrolled course/lesson data (title, sections,
/// progress) that `courses` owns, to drive the player UI and report
/// progress back. See `auth_shared.dart` for the full rationale.
library;

export '../../features/courses/application/providers/courses_provider.dart';
