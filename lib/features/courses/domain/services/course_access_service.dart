enum CourseAccessState { enrolled, notEnrolled }

/// A client-side UI hint only — e.g. deciding whether to show a "Continue
/// learning" vs. "Enroll" button on the course card.
///
/// This is NOT the source of truth for access control. The actual
/// authorization decision (whether the current user may fetch a lesson's
/// video content) is enforced server-side by the `get_lesson_content` RPC,
/// which checks enrollment/preview status against the database directly.
/// [subscriptions] passed in here can be stale (e.g. right after enrolling,
/// before the local cache refreshes), so never use [resolve] to gate
/// access to protected content — only to drive non-security-critical UI.
class CourseAccessService {
  CourseAccessState resolve({
    required String courseId,
    required Set<String> subscriptions,
  }) {
    return subscriptions.contains(courseId)
        ? CourseAccessState.enrolled
        : CourseAccessState.notEnrolled;
  }
}
