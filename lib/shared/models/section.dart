import 'package:freezed_annotation/freezed_annotation.dart';
import 'lesson.dart';

part 'section.freezed.dart';
part 'section.g.dart';

/// Domain entity for a course section.
///
/// v11 changes:
///   • `video_url` REMOVED — sections do not hold video data; video
///     content lives in `lesson_contents` per lesson.
///   • `duration` REMOVED — section-level duration column dropped.
@freezed
abstract class Section with _$Section {
  const factory Section({
    required String id,
    @JsonKey(name: 'course_id') required String courseId,
    @JsonKey(name: 'tenant_id') required String tenantId,
    required String title,
    String? description,
    @JsonKey(name: 'order_index') @Default(0) int orderIndex,
    @JsonKey(name: 'is_published') @Default(false) bool isPublished,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,

    // Joined aggregate
    List<Lesson>? lessons,
  }) = _Section;

  factory Section.fromJson(Map<String, dynamic> json) => _$SectionFromJson(json);

  /// Skeleton dummy data
  factory Section.skeleton({int order = 0}) => Section(
        id: 'skeleton-$order',
        courseId: 'skeleton',
        tenantId: 'skeleton',
        title: 'Section $order: Loading...', // check-ignore
        orderIndex: order,
        lessons: List.generate(4, (i) => Lesson.skeleton(order: i)),
      );
}
