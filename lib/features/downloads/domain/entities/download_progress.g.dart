// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DownloadProgress _$DownloadProgressFromJson(Map<String, dynamic> json) =>
    _DownloadProgress(
      downloadId: json['downloadId'] as String,
      lessonId: json['lessonId'] as String,
      receivedBytes: (json['receivedBytes'] as num).toInt(),
      totalBytes: (json['totalBytes'] as num).toInt(),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      status: $enumDecode(_$DownloadStatusEnumMap, json['status']),
      downloadSpeed: (json['downloadSpeed'] as num?)?.toInt(),
      estimatedTimeRemaining: (json['estimatedTimeRemaining'] as num?)?.toInt(),
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$DownloadProgressToJson(_DownloadProgress instance) =>
    <String, dynamic>{
      'downloadId': instance.downloadId,
      'lessonId': instance.lessonId,
      'receivedBytes': instance.receivedBytes,
      'totalBytes': instance.totalBytes,
      'progress': instance.progress,
      'status': _$DownloadStatusEnumMap[instance.status]!,
      'downloadSpeed': instance.downloadSpeed,
      'estimatedTimeRemaining': instance.estimatedTimeRemaining,
      'errorMessage': instance.errorMessage,
    };

const _$DownloadStatusEnumMap = {
  DownloadStatus.pending: 'pending',
  DownloadStatus.downloading: 'downloading',
  DownloadStatus.paused: 'paused',
  DownloadStatus.completed: 'completed',
  DownloadStatus.failed: 'failed',
};
