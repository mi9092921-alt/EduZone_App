// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'downloaded_lesson.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DownloadedLesson {

 String get id; String get lessonId; String get courseId; String get courseTitle; String get title; String get localPath; String get encryptedPath;/// Path to the encrypted audio file; null for muxed (single-file) downloads.
 String? get audioPath; String get videoUrl;/// URL of the separate audio track; null for muxed formats.
 String? get audioUrl; VideoQuality get quality; int get fileSize; DownloadStatus get status; double get progress; DateTime get downloadedAt; DateTime get expiresAt; String? get checksum; DateTime? get lastAccessedAt;
/// Create a copy of DownloadedLesson
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadedLessonCopyWith<DownloadedLesson> get copyWith => _$DownloadedLessonCopyWithImpl<DownloadedLesson>(this as DownloadedLesson, _$identity);

  /// Serializes this DownloadedLesson to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadedLesson&&(identical(other.id, id) || other.id == id)&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.courseTitle, courseTitle) || other.courseTitle == courseTitle)&&(identical(other.title, title) || other.title == title)&&(identical(other.localPath, localPath) || other.localPath == localPath)&&(identical(other.encryptedPath, encryptedPath) || other.encryptedPath == encryptedPath)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.checksum, checksum) || other.checksum == checksum)&&(identical(other.lastAccessedAt, lastAccessedAt) || other.lastAccessedAt == lastAccessedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lessonId,courseId,courseTitle,title,localPath,encryptedPath,audioPath,videoUrl,audioUrl,quality,fileSize,status,progress,downloadedAt,expiresAt,checksum,lastAccessedAt);

@override
String toString() {
  return 'DownloadedLesson(id: $id, lessonId: $lessonId, courseId: $courseId, courseTitle: $courseTitle, title: $title, localPath: $localPath, encryptedPath: $encryptedPath, audioPath: $audioPath, videoUrl: $videoUrl, audioUrl: $audioUrl, quality: $quality, fileSize: $fileSize, status: $status, progress: $progress, downloadedAt: $downloadedAt, expiresAt: $expiresAt, checksum: $checksum, lastAccessedAt: $lastAccessedAt)';
}


}

/// @nodoc
abstract mixin class $DownloadedLessonCopyWith<$Res>  {
  factory $DownloadedLessonCopyWith(DownloadedLesson value, $Res Function(DownloadedLesson) _then) = _$DownloadedLessonCopyWithImpl;
@useResult
$Res call({
 String id, String lessonId, String courseId, String courseTitle, String title, String localPath, String encryptedPath, String? audioPath, String videoUrl, String? audioUrl, VideoQuality quality, int fileSize, DownloadStatus status, double progress, DateTime downloadedAt, DateTime expiresAt, String? checksum, DateTime? lastAccessedAt
});




}
/// @nodoc
class _$DownloadedLessonCopyWithImpl<$Res>
    implements $DownloadedLessonCopyWith<$Res> {
  _$DownloadedLessonCopyWithImpl(this._self, this._then);

  final DownloadedLesson _self;
  final $Res Function(DownloadedLesson) _then;

/// Create a copy of DownloadedLesson
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lessonId = null,Object? courseId = null,Object? courseTitle = null,Object? title = null,Object? localPath = null,Object? encryptedPath = null,Object? audioPath = freezed,Object? videoUrl = null,Object? audioUrl = freezed,Object? quality = null,Object? fileSize = null,Object? status = null,Object? progress = null,Object? downloadedAt = null,Object? expiresAt = null,Object? checksum = freezed,Object? lastAccessedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lessonId: null == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,courseTitle: null == courseTitle ? _self.courseTitle : courseTitle // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,localPath: null == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String,encryptedPath: null == encryptedPath ? _self.encryptedPath : encryptedPath // ignore: cast_nullable_to_non_nullable
as String,audioPath: freezed == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String?,videoUrl: null == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as VideoQuality,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DownloadStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,downloadedAt: null == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,checksum: freezed == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String?,lastAccessedAt: freezed == lastAccessedAt ? _self.lastAccessedAt : lastAccessedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [DownloadedLesson].
extension DownloadedLessonPatterns on DownloadedLesson {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadedLesson value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadedLesson() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadedLesson value)  $default,){
final _that = this;
switch (_that) {
case _DownloadedLesson():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadedLesson value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadedLesson() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String lessonId,  String courseId,  String courseTitle,  String title,  String localPath,  String encryptedPath,  String? audioPath,  String videoUrl,  String? audioUrl,  VideoQuality quality,  int fileSize,  DownloadStatus status,  double progress,  DateTime downloadedAt,  DateTime expiresAt,  String? checksum,  DateTime? lastAccessedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadedLesson() when $default != null:
return $default(_that.id,_that.lessonId,_that.courseId,_that.courseTitle,_that.title,_that.localPath,_that.encryptedPath,_that.audioPath,_that.videoUrl,_that.audioUrl,_that.quality,_that.fileSize,_that.status,_that.progress,_that.downloadedAt,_that.expiresAt,_that.checksum,_that.lastAccessedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String lessonId,  String courseId,  String courseTitle,  String title,  String localPath,  String encryptedPath,  String? audioPath,  String videoUrl,  String? audioUrl,  VideoQuality quality,  int fileSize,  DownloadStatus status,  double progress,  DateTime downloadedAt,  DateTime expiresAt,  String? checksum,  DateTime? lastAccessedAt)  $default,) {final _that = this;
switch (_that) {
case _DownloadedLesson():
return $default(_that.id,_that.lessonId,_that.courseId,_that.courseTitle,_that.title,_that.localPath,_that.encryptedPath,_that.audioPath,_that.videoUrl,_that.audioUrl,_that.quality,_that.fileSize,_that.status,_that.progress,_that.downloadedAt,_that.expiresAt,_that.checksum,_that.lastAccessedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String lessonId,  String courseId,  String courseTitle,  String title,  String localPath,  String encryptedPath,  String? audioPath,  String videoUrl,  String? audioUrl,  VideoQuality quality,  int fileSize,  DownloadStatus status,  double progress,  DateTime downloadedAt,  DateTime expiresAt,  String? checksum,  DateTime? lastAccessedAt)?  $default,) {final _that = this;
switch (_that) {
case _DownloadedLesson() when $default != null:
return $default(_that.id,_that.lessonId,_that.courseId,_that.courseTitle,_that.title,_that.localPath,_that.encryptedPath,_that.audioPath,_that.videoUrl,_that.audioUrl,_that.quality,_that.fileSize,_that.status,_that.progress,_that.downloadedAt,_that.expiresAt,_that.checksum,_that.lastAccessedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DownloadedLesson implements DownloadedLesson {
  const _DownloadedLesson({required this.id, required this.lessonId, required this.courseId, this.courseTitle = '', required this.title, required this.localPath, required this.encryptedPath, this.audioPath, required this.videoUrl, this.audioUrl, required this.quality, required this.fileSize, required this.status, this.progress = 0.0, required this.downloadedAt, required this.expiresAt, this.checksum, this.lastAccessedAt});
  factory _DownloadedLesson.fromJson(Map<String, dynamic> json) => _$DownloadedLessonFromJson(json);

@override final  String id;
@override final  String lessonId;
@override final  String courseId;
@override@JsonKey() final  String courseTitle;
@override final  String title;
@override final  String localPath;
@override final  String encryptedPath;
/// Path to the encrypted audio file; null for muxed (single-file) downloads.
@override final  String? audioPath;
@override final  String videoUrl;
/// URL of the separate audio track; null for muxed formats.
@override final  String? audioUrl;
@override final  VideoQuality quality;
@override final  int fileSize;
@override final  DownloadStatus status;
@override@JsonKey() final  double progress;
@override final  DateTime downloadedAt;
@override final  DateTime expiresAt;
@override final  String? checksum;
@override final  DateTime? lastAccessedAt;

/// Create a copy of DownloadedLesson
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadedLessonCopyWith<_DownloadedLesson> get copyWith => __$DownloadedLessonCopyWithImpl<_DownloadedLesson>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DownloadedLessonToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadedLesson&&(identical(other.id, id) || other.id == id)&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.courseTitle, courseTitle) || other.courseTitle == courseTitle)&&(identical(other.title, title) || other.title == title)&&(identical(other.localPath, localPath) || other.localPath == localPath)&&(identical(other.encryptedPath, encryptedPath) || other.encryptedPath == encryptedPath)&&(identical(other.audioPath, audioPath) || other.audioPath == audioPath)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.audioUrl, audioUrl) || other.audioUrl == audioUrl)&&(identical(other.quality, quality) || other.quality == quality)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.checksum, checksum) || other.checksum == checksum)&&(identical(other.lastAccessedAt, lastAccessedAt) || other.lastAccessedAt == lastAccessedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lessonId,courseId,courseTitle,title,localPath,encryptedPath,audioPath,videoUrl,audioUrl,quality,fileSize,status,progress,downloadedAt,expiresAt,checksum,lastAccessedAt);

@override
String toString() {
  return 'DownloadedLesson(id: $id, lessonId: $lessonId, courseId: $courseId, courseTitle: $courseTitle, title: $title, localPath: $localPath, encryptedPath: $encryptedPath, audioPath: $audioPath, videoUrl: $videoUrl, audioUrl: $audioUrl, quality: $quality, fileSize: $fileSize, status: $status, progress: $progress, downloadedAt: $downloadedAt, expiresAt: $expiresAt, checksum: $checksum, lastAccessedAt: $lastAccessedAt)';
}


}

/// @nodoc
abstract mixin class _$DownloadedLessonCopyWith<$Res> implements $DownloadedLessonCopyWith<$Res> {
  factory _$DownloadedLessonCopyWith(_DownloadedLesson value, $Res Function(_DownloadedLesson) _then) = __$DownloadedLessonCopyWithImpl;
@override @useResult
$Res call({
 String id, String lessonId, String courseId, String courseTitle, String title, String localPath, String encryptedPath, String? audioPath, String videoUrl, String? audioUrl, VideoQuality quality, int fileSize, DownloadStatus status, double progress, DateTime downloadedAt, DateTime expiresAt, String? checksum, DateTime? lastAccessedAt
});




}
/// @nodoc
class __$DownloadedLessonCopyWithImpl<$Res>
    implements _$DownloadedLessonCopyWith<$Res> {
  __$DownloadedLessonCopyWithImpl(this._self, this._then);

  final _DownloadedLesson _self;
  final $Res Function(_DownloadedLesson) _then;

/// Create a copy of DownloadedLesson
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lessonId = null,Object? courseId = null,Object? courseTitle = null,Object? title = null,Object? localPath = null,Object? encryptedPath = null,Object? audioPath = freezed,Object? videoUrl = null,Object? audioUrl = freezed,Object? quality = null,Object? fileSize = null,Object? status = null,Object? progress = null,Object? downloadedAt = null,Object? expiresAt = null,Object? checksum = freezed,Object? lastAccessedAt = freezed,}) {
  return _then(_DownloadedLesson(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lessonId: null == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,courseTitle: null == courseTitle ? _self.courseTitle : courseTitle // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,localPath: null == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String,encryptedPath: null == encryptedPath ? _self.encryptedPath : encryptedPath // ignore: cast_nullable_to_non_nullable
as String,audioPath: freezed == audioPath ? _self.audioPath : audioPath // ignore: cast_nullable_to_non_nullable
as String?,videoUrl: null == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String,audioUrl: freezed == audioUrl ? _self.audioUrl : audioUrl // ignore: cast_nullable_to_non_nullable
as String?,quality: null == quality ? _self.quality : quality // ignore: cast_nullable_to_non_nullable
as VideoQuality,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DownloadStatus,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,downloadedAt: null == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,checksum: freezed == checksum ? _self.checksum : checksum // ignore: cast_nullable_to_non_nullable
as String?,lastAccessedAt: freezed == lastAccessedAt ? _self.lastAccessedAt : lastAccessedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
