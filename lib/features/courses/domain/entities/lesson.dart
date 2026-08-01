import 'package:freezed_annotation/freezed_annotation.dart';
import 'lesson_progress.dart';

part 'lesson.freezed.dart';
part 'lesson.g.dart';

/// Domain entity for a lesson row.
///
/// v11 changes:
///   • `youtube_url` REMOVED — video data now lives exclusively in
///     `lesson_contents` table, gated by enrollment-based RLS.
///   • `is_preview` ADDED — marks a lesson as freely accessible without
///     enrollment (used by the `lc_enrolled_or_preview` RLS policy).
///   • `course_id` ADDED — denormalized column present in the seed data;
///     needed by `get_lesson_content` RPC and sidebar navigation.
@freezed
abstract class Lesson with _$Lesson {
  const factory Lesson({
    required String id,
    @JsonKey(name: 'section_id') required String sectionId,
    // Denormalized from sections→courses join (v11 seed has this column)
    @JsonKey(name: 'course_id') String? courseId,
    @JsonKey(name: 'tenant_id') String? tenantId,
    required String title,
    @JsonKey(name: 'order_index') @Default(0) int orderIndex,
    @JsonKey(name: 'is_published') @Default(true) bool isPublished,
    // v11: free sample lesson — accessible without enrollment
    @JsonKey(name: 'is_preview') @Default(false) bool isPreview,
    @JsonKey(name: 'duration_sec') int? durationSec,

    /// v12: Populated by get_course_lessons_with_access RPC
    @JsonKey(name: 'has_access') @Default(false) bool hasAccess,

    @JsonKey(name: 'created_at') DateTime? createdAt,

    @JsonKey(name: 'updated_at') DateTime? updatedAt,

    // Virtual join: current user's progress rows (RLS-filtered)
    @JsonKey(name: 'user_progress') List<LessonProgress>? userProgress,
  }) = _Lesson;

  factory Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);

  /// Skeleton dummy data
  factory Lesson.skeleton({int order = 0}) => Lesson(
        id: 'skeleton-$order',
        sectionId: 'skeleton',
        title: 'Loading Lesson Content $order...',
        orderIndex: order,
        durationSec: 300,
      );
}
