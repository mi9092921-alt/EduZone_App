// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_progress_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CourseProgressSummary _$CourseProgressSummaryFromJson(
  Map<String, dynamic> json,
) => _CourseProgressSummary(
  courseId: json['courseId'] as String?,
  enrolledCount: (json['enrolledCount'] as num?)?.toInt() ?? 0,
  avgProgress: (json['avgProgress'] as num?)?.toDouble() ?? 0.0,
  completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CourseProgressSummaryToJson(
  _CourseProgressSummary instance,
) => <String, dynamic>{
  'courseId': instance.courseId,
  'enrolledCount': instance.enrolledCount,
  'avgProgress': instance.avgProgress,
  'completedCount': instance.completedCount,
};
