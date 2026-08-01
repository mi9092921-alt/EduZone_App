// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloaded_lesson.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DownloadedLesson _$DownloadedLessonFromJson(Map<String, dynamic> json) =>
    _DownloadedLesson(
      id: json['id'] as String,
      lessonId: json['lessonId'] as String,
      courseId: json['courseId'] as String,
      courseTitle: json['courseTitle'] as String? ?? '',
      title: json['title'] as String,
      localPath: json['localPath'] as String,
      encryptedPath: json['encryptedPath'] as String,
      audioPath: json['audioPath'] as String?,
      videoUrl: json['videoUrl'] as String,
      audioUrl: json['audioUrl'] as String?,
      quality: $enumDecode(_$VideoQualityEnumMap, json['quality']),
      fileSize: (json['fileSize'] as num).toInt(),
      status: $enumDecode(_$DownloadStatusEnumMap, json['status']),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      checksum: json['checksum'] as String?,
      lastAccessedAt: json['lastAccessedAt'] == null
          ? null
          : DateTime.parse(json['lastAccessedAt'] as String),
    );

Map<String, dynamic> _$DownloadedLessonToJson(_DownloadedLesson instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lessonId': instance.lessonId,
      'courseId': instance.courseId,
      'courseTitle': instance.courseTitle,
      'title': instance.title,
      'localPath': instance.localPath,
      'encryptedPath': instance.encryptedPath,
      'audioPath': instance.audioPath,
      'videoUrl': instance.videoUrl,
      'audioUrl': instance.audioUrl,
      'quality': _$VideoQualityEnumMap[instance.quality]!,
      'fileSize': instance.fileSize,
      'status': _$DownloadStatusEnumMap[instance.status]!,
      'progress': instance.progress,
      'downloadedAt': instance.downloadedAt.toIso8601String(),
      'expiresAt': instance.expiresAt.toIso8601String(),
      'checksum': instance.checksum,
      'lastAccessedAt': instance.lastAccessedAt?.toIso8601String(),
    };

const _$VideoQualityEnumMap = {
  VideoQuality.p144: '144p',
  VideoQuality.p240: '240p',
  VideoQuality.p360: '360p',
  VideoQuality.p480: '480p',
  VideoQuality.p720: '720p',
  VideoQuality.p1080: '1080p',
};

const _$DownloadStatusEnumMap = {
  DownloadStatus.pending: 'pending',
  DownloadStatus.downloading: 'downloading',
  DownloadStatus.paused: 'paused',
  DownloadStatus.completed: 'completed',
  DownloadStatus.failed: 'failed',
};
