import 'package:equatable/equatable.dart';

/// A lightweight, `home`-feature-owned projection of a todo item, used for
/// the "Today's Tasks" dashboard section.
///
/// Deliberately not the `todo` feature's `TodoItem` entity — see
/// [HomeCourseSummary] (in `home_course_summary.dart`) for the full
/// rationale. `home`'s presentation layer maps this back into a full
/// `TodoItem` only at the point where it needs to reuse `todo`'s
/// `TodoPreviewTile` widget (a presentation-to-presentation reuse, which is
/// the normal and low-risk form of coupling for a dashboard/aggregator
/// feature — unlike domain-to-domain coupling, which this fix removes).
class HomeTodoSummary extends Equatable {
  final String id;
  final String userId;
  final String tenantId;
  final String title;
  final DateTime? dueAt;
  final bool isCompleted;
  final int priority;

  const HomeTodoSummary({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.title,
    this.dueAt,
    this.isCompleted = false,
    this.priority = 0,
  });

  @override
  List<Object?> get props =>
      [id, userId, tenantId, title, dueAt, isCompleted, priority];
}
