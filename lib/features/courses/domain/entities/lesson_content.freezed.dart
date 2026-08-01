// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lesson_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LessonContent {

@JsonKey(name: 'lessonId') String get lessonId;@JsonKey(name: 'courseId') String get courseId;@JsonKey(name: 'isPreview') bool get isPreview;/// Opaque video identifier — maps to videoPath in v13 RPC.
@JsonKey(name: 'videoPath') String? get videoUrl;/// 'youtube' | 'storage' | 'vimeo'
 String get provider;/// Total duration in seconds.
@JsonKey(name: 'durationSec') int? get duration;@JsonKey(name: 'captionsPath') String? get captionsUrl;// Optional fields not returned by direct RPC but used in UI
 String? get title;@JsonKey(name: 'has_access') bool get hasAccess;@JsonKey(name: 'preview_url') String? get previewUrl;
/// Create a copy of LessonContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LessonContentCopyWith<LessonContent> get copyWith => _$LessonContentCopyWithImpl<LessonContent>(this as LessonContent, _$identity);

  /// Serializes this LessonContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LessonContent&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.isPreview, isPreview) || other.isPreview == isPreview)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.captionsUrl, captionsUrl) || other.captionsUrl == captionsUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.hasAccess, hasAccess) || other.hasAccess == hasAccess)&&(identical(other.previewUrl, previewUrl) || other.previewUrl == previewUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lessonId,courseId,isPreview,videoUrl,provider,duration,captionsUrl,title,hasAccess,previewUrl);

@override
String toString() {
  return 'LessonContent(lessonId: $lessonId, courseId: $courseId, isPreview: $isPreview, videoUrl: $videoUrl, provider: $provider, duration: $duration, captionsUrl: $captionsUrl, title: $title, hasAccess: $hasAccess, previewUrl: $previewUrl)';
}


}

/// @nodoc
abstract mixin class $LessonContentCopyWith<$Res>  {
  factory $LessonContentCopyWith(LessonContent value, $Res Function(LessonContent) _then) = _$LessonContentCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'lessonId') String lessonId,@JsonKey(name: 'courseId') String courseId,@JsonKey(name: 'isPreview') bool isPreview,@JsonKey(name: 'videoPath') String? videoUrl, String provider,@JsonKey(name: 'durationSec') int? duration,@JsonKey(name: 'captionsPath') String? captionsUrl, String? title,@JsonKey(name: 'has_access') bool hasAccess,@JsonKey(name: 'preview_url') String? previewUrl
});




}
/// @nodoc
class _$LessonContentCopyWithImpl<$Res>
    implements $LessonContentCopyWith<$Res> {
  _$LessonContentCopyWithImpl(this._self, this._then);

  final LessonContent _self;
  final $Res Function(LessonContent) _then;

/// Create a copy of LessonContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lessonId = null,Object? courseId = null,Object? isPreview = null,Object? videoUrl = freezed,Object? provider = null,Object? duration = freezed,Object? captionsUrl = freezed,Object? title = freezed,Object? hasAccess = null,Object? previewUrl = freezed,}) {
  return _then(_self.copyWith(
lessonId: null == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,isPreview: null == isPreview ? _self.isPreview : isPreview // ignore: cast_nullable_to_non_nullable
as bool,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int?,captionsUrl: freezed == captionsUrl ? _self.captionsUrl : captionsUrl // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,hasAccess: null == hasAccess ? _self.hasAccess : hasAccess // ignore: cast_nullable_to_non_nullable
as bool,previewUrl: freezed == previewUrl ? _self.previewUrl : previewUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LessonContent].
extension LessonContentPatterns on LessonContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LessonContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LessonContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LessonContent value)  $default,){
final _that = this;
switch (_that) {
case _LessonContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LessonContent value)?  $default,){
final _that = this;
switch (_that) {
case _LessonContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'lessonId')  String lessonId, @JsonKey(name: 'courseId')  String courseId, @JsonKey(name: 'isPreview')  bool isPreview, @JsonKey(name: 'videoPath')  String? videoUrl,  String provider, @JsonKey(name: 'durationSec')  int? duration, @JsonKey(name: 'captionsPath')  String? captionsUrl,  String? title, @JsonKey(name: 'has_access')  bool hasAccess, @JsonKey(name: 'preview_url')  String? previewUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LessonContent() when $default != null:
return $default(_that.lessonId,_that.courseId,_that.isPreview,_that.videoUrl,_that.provider,_that.duration,_that.captionsUrl,_that.title,_that.hasAccess,_that.previewUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'lessonId')  String lessonId, @JsonKey(name: 'courseId')  String courseId, @JsonKey(name: 'isPreview')  bool isPreview, @JsonKey(name: 'videoPath')  String? videoUrl,  String provider, @JsonKey(name: 'durationSec')  int? duration, @JsonKey(name: 'captionsPath')  String? captionsUrl,  String? title, @JsonKey(name: 'has_access')  bool hasAccess, @JsonKey(name: 'preview_url')  String? previewUrl)  $default,) {final _that = this;
switch (_that) {
case _LessonContent():
return $default(_that.lessonId,_that.courseId,_that.isPreview,_that.videoUrl,_that.provider,_that.duration,_that.captionsUrl,_that.title,_that.hasAccess,_that.previewUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'lessonId')  String lessonId, @JsonKey(name: 'courseId')  String courseId, @JsonKey(name: 'isPreview')  bool isPreview, @JsonKey(name: 'videoPath')  String? videoUrl,  String provider, @JsonKey(name: 'durationSec')  int? duration, @JsonKey(name: 'captionsPath')  String? captionsUrl,  String? title, @JsonKey(name: 'has_access')  bool hasAccess, @JsonKey(name: 'preview_url')  String? previewUrl)?  $default,) {final _that = this;
switch (_that) {
case _LessonContent() when $default != null:
return $default(_that.lessonId,_that.courseId,_that.isPreview,_that.videoUrl,_that.provider,_that.duration,_that.captionsUrl,_that.title,_that.hasAccess,_that.previewUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LessonContent implements LessonContent {
  const _LessonContent({@JsonKey(name: 'lessonId') required this.lessonId, @JsonKey(name: 'courseId') required this.courseId, @JsonKey(name: 'isPreview') this.isPreview = false, @JsonKey(name: 'videoPath') this.videoUrl, this.provider = 'youtube', @JsonKey(name: 'durationSec') this.duration, @JsonKey(name: 'captionsPath') this.captionsUrl, this.title, @JsonKey(name: 'has_access') this.hasAccess = false, @JsonKey(name: 'preview_url') this.previewUrl});
  factory _LessonContent.fromJson(Map<String, dynamic> json) => _$LessonContentFromJson(json);

@override@JsonKey(name: 'lessonId') final  String lessonId;
@override@JsonKey(name: 'courseId') final  String courseId;
@override@JsonKey(name: 'isPreview') final  bool isPreview;
/// Opaque video identifier — maps to videoPath in v13 RPC.
@override@JsonKey(name: 'videoPath') final  String? videoUrl;
/// 'youtube' | 'storage' | 'vimeo'
@override@JsonKey() final  String provider;
/// Total duration in seconds.
@override@JsonKey(name: 'durationSec') final  int? duration;
@override@JsonKey(name: 'captionsPath') final  String? captionsUrl;
// Optional fields not returned by direct RPC but used in UI
@override final  String? title;
@override@JsonKey(name: 'has_access') final  bool hasAccess;
@override@JsonKey(name: 'preview_url') final  String? previewUrl;

/// Create a copy of LessonContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LessonContentCopyWith<_LessonContent> get copyWith => __$LessonContentCopyWithImpl<_LessonContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LessonContentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LessonContent&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.isPreview, isPreview) || other.isPreview == isPreview)&&(identical(other.videoUrl, videoUrl) || other.videoUrl == videoUrl)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.captionsUrl, captionsUrl) || other.captionsUrl == captionsUrl)&&(identical(other.title, title) || other.title == title)&&(identical(other.hasAccess, hasAccess) || other.hasAccess == hasAccess)&&(identical(other.previewUrl, previewUrl) || other.previewUrl == previewUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lessonId,courseId,isPreview,videoUrl,provider,duration,captionsUrl,title,hasAccess,previewUrl);

@override
String toString() {
  return 'LessonContent(lessonId: $lessonId, courseId: $courseId, isPreview: $isPreview, videoUrl: $videoUrl, provider: $provider, duration: $duration, captionsUrl: $captionsUrl, title: $title, hasAccess: $hasAccess, previewUrl: $previewUrl)';
}


}

/// @nodoc
abstract mixin class _$LessonContentCopyWith<$Res> implements $LessonContentCopyWith<$Res> {
  factory _$LessonContentCopyWith(_LessonContent value, $Res Function(_LessonContent) _then) = __$LessonContentCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'lessonId') String lessonId,@JsonKey(name: 'courseId') String courseId,@JsonKey(name: 'isPreview') bool isPreview,@JsonKey(name: 'videoPath') String? videoUrl, String provider,@JsonKey(name: 'durationSec') int? duration,@JsonKey(name: 'captionsPath') String? captionsUrl, String? title,@JsonKey(name: 'has_access') bool hasAccess,@JsonKey(name: 'preview_url') String? previewUrl
});




}
/// @nodoc
class __$LessonContentCopyWithImpl<$Res>
    implements _$LessonContentCopyWith<$Res> {
  __$LessonContentCopyWithImpl(this._self, this._then);

  final _LessonContent _self;
  final $Res Function(_LessonContent) _then;

/// Create a copy of LessonContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lessonId = null,Object? courseId = null,Object? isPreview = null,Object? videoUrl = freezed,Object? provider = null,Object? duration = freezed,Object? captionsUrl = freezed,Object? title = freezed,Object? hasAccess = null,Object? previewUrl = freezed,}) {
  return _then(_LessonContent(
lessonId: null == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,isPreview: null == isPreview ? _self.isPreview : isPreview // ignore: cast_nullable_to_non_nullable
as bool,videoUrl: freezed == videoUrl ? _self.videoUrl : videoUrl // ignore: cast_nullable_to_non_nullable
as String?,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as int?,captionsUrl: freezed == captionsUrl ? _self.captionsUrl : captionsUrl // ignore: cast_nullable_to_non_nullable
as String?,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,hasAccess: null == hasAccess ? _self.hasAccess : hasAccess // ignore: cast_nullable_to_non_nullable
as bool,previewUrl: freezed == previewUrl ? _self.previewUrl : previewUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
