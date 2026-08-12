import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/l10n/arb/app_localizations.dart';
import 'section.dart';

part 'course.freezed.dart';
part 'course.g.dart';

@freezed
abstract class Course with _$Course {
  const factory Course({
    required String id,
    @JsonKey(name: 'tenant_id') required String tenantId,
    required String title,
    String? description,
    required String status,
    @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
    String? slug,
    @JsonKey(name: 'teacher_id') String? teacherId,
    String? category,
    @Default('beginner') String level,
    @Default(0) double price,
    @JsonKey(name: 'is_free') @Default(true) bool isFree,
    @JsonKey(name: 'is_featured') @Default(false) bool isFeatured,
    @JsonKey(name: 'is_discoverable') @Default(true) bool isDiscoverable,
    @JsonKey(name: 'region_id') String? regionId,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'total_lessons') int? totalLessons,
    double? rating,
    @JsonKey(name: 'students_count') int? studentsCount,
    @JsonKey(name: 'instructor_name') String? instructorName,
    @JsonKey(name: 'instructor_avatar') String? instructorAvatar,
    List<String>? prerequisites,
    @JsonKey(name: 'learning_objectives') List<String>? learningObjectives,
    String? language,
    
    // Virtual fields joined by PostgREST or RPCs
    List<Section>? sections,
    @JsonKey(name: 'progress_pct') double? progressPct,
    @JsonKey(name: 'completed_lessons') int? completedLessons,
  }) = _Course;


  factory Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);

  /// Skeleton dummy data
  factory Course.skeleton() => Course(
        id: 'skeleton',
        tenantId: 'skeleton',
        title: 'Loading Course Title...', // check-ignore
        description: 'This is a placeholder description for the course loading state. ' * 5,
        status: 'published',
        category: 'CATEGORY',
        level: 'BEGINNER',
        learningObjectives: ['Loading point 1...', 'Loading point 2...'],
        prerequisites: ['Loading requirement 1...'],
        sections: List.generate(3, (i) => Section.skeleton(order: i)),
      );
}

extension CoursePresentation on Course {
  String get ratingLabel =>
      rating != null ? rating!.toStringAsFixed(1) : '—';

  String get studentsLabel {
    if (studentsCount == null) return '';
    if (studentsCount! >= 1000) {
      return '${(studentsCount! / 1000).toStringAsFixed(1)}k';
    }
    return studentsCount.toString();
  }

  String levelLocalized(AppLocalizations l10n) {
    return switch (level.toLowerCase()) {
      'beginner' => l10n.levelBeginner,
      'intermediate' => l10n.levelIntermediate,
      'advanced' => l10n.levelAdvanced,
      _ => level.toUpperCase(),
    };
  }

  int get computedTotalLessons =>
      sections?.fold(0, (acc, s) => acc! + (s.lessons?.length ?? 0)) ?? 0;

  int get totalDurationMinutes {
    final totalSec = sections?.fold<int>(
          0,
          (acc, s) =>
              acc +
              (s.lessons?.fold<int>(0, (lacc, l) => lacc + (l.durationSec ?? 0)) ??
                  0),
        ) ??
        0;
    return (totalSec / 60).round();
  }

  bool get isNew {
    if (createdAt == null) return false;
    final diff = DateTime.now().difference(createdAt!);
    return diff.inDays <= 14;
  }
}
