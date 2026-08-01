import 'package:freezed_annotation/freezed_annotation.dart';

part 'course_ui_model.freezed.dart';
part 'course_ui_model.g.dart';

/// A pure data model for representing a course in the UI layer.
/// Decoupled from the domain entity for maximum flexibility and performance.
@freezed
abstract class CourseUIModel with _$CourseUIModel {
  const factory CourseUIModel({
    required String id,
    required String title,
    String? description,
    required String thumbnailUrl,
    required String instructorName,
    String? category,
    String? level,
    String? duration,
    int? totalLessons,
    double? rating,
    int? studentsCount,
    String? price,
    @Default(false) bool isFeatured,
    @Default(false) bool isFree,
    String? status,
    double? progress,
  }) = _CourseUIModel;

  factory CourseUIModel.fromJson(Map<String, dynamic> json) =>
      _$CourseUIModelFromJson(json);
}
