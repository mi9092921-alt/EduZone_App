import 'package:equatable/equatable.dart';

/// A lightweight, `home`-feature-owned projection of course data needed for
/// the "Continue Learning" dashboard section.
///
/// This is deliberately **not** the `courses` feature's `Course` entity.
/// Before this fix, `home`'s domain layer (`HomeRepository`,
/// `HomeRepositoryImpl`) imported `Course` directly from
/// `features/courses/domain/entities/`, which meant `home`'s domain layer —
/// the part of the codebase that should be the most stable and
/// feature-independent — was coupled to another feature's domain layer.
///
/// [HomeRepositoryImpl] is responsible for mapping the richer `Course`
/// entity (or raw Supabase rows, via [HomeRemoteDataSource]) into this
/// summary. `home`'s domain and presentation layers never need to see the
/// full `Course` entity, only these six fields.
class HomeCourseSummary extends Equatable {
  final String id;
  final String title;
  final String? thumbnailUrl;
  final String level;
  final int totalLessons;
  final int? completedLessons;
  final double? progressPct;

  const HomeCourseSummary({
    required this.id,
    required this.title,
    required this.level,
    required this.totalLessons,
    this.thumbnailUrl,
    this.completedLessons,
    this.progressPct,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        thumbnailUrl,
        level,
        totalLessons,
        completedLessons,
        progressPct,
      ];
}
