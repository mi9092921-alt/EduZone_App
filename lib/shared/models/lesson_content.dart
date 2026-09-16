import 'package:freezed_annotation/freezed_annotation.dart';

part 'lesson_content.freezed.dart';
part 'lesson_content.g.dart';

/// Represents the secure content payload returned by the
/// `get_lesson_content(lesson_id, client_ip, device_id)` RPC.
///
/// The RPC enforces enrollment-based access control and logs every
/// access attempt in `lesson_access_log` for anti-sharing analysis.
///
/// Security model:
///   • [videoPath] is an opaque key (e.g. YouTube video ID or storage
///     object path) — never a direct, publicly-accessible URL.
///   • For YouTube provider: use the ID to construct the player URL.
///   • For storage provider: exchange [videoPath] for a time-limited
///     signed URL via a Supabase Edge Function.
@freezed
abstract class LessonContent with _$LessonContent {
  const factory LessonContent({
    @JsonKey(name: 'lessonId') required String lessonId,
    @JsonKey(name: 'courseId') required String courseId,
    @JsonKey(name: 'isPreview') @Default(false) bool isPreview,

    /// Opaque video identifier — maps to videoPath in v13 RPC.
    @JsonKey(name: 'videoPath') String? videoUrl,

    /// 'youtube' | 'storage' | 'vimeo'
    @Default('youtube') String provider,

    /// Total duration in seconds.
    @JsonKey(name: 'durationSec') int? duration,

    @JsonKey(name: 'captionsPath') String? captionsUrl,

    // Optional fields not returned by direct RPC but used in UI
    String? title,
    @JsonKey(name: 'has_access') @Default(false) bool hasAccess,
    @JsonKey(name: 'preview_url') String? previewUrl,
  }) = _LessonContent;

  factory LessonContent.fromJson(Map<String, dynamic> json) =>
      _$LessonContentFromJson(json);
}

