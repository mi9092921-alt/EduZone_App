/// Cross-feature facade for `features/home`.
///
/// `video_player` invalidates Home's resume-lessons / recent-courses
/// providers when a lesson completes, so the "Continue Learning" sections
/// never show stale progress after leaving the player. See
/// `auth_shared.dart` for the full rationale.
library;

export '../../features/home/application/providers/home_provider.dart';
