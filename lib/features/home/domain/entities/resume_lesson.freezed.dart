// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'resume_lesson.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ResumeLesson {

@JsonKey(name: 'progress_pct') double get progressPct;@JsonKey(name: 'last_watched') DateTime get lastWatched;@JsonKey(name: 'lesson_id') String get lessonId;@JsonKey(name: 'lesson_title') String get lessonTitle;@JsonKey(name: 'duration_sec') int? get durationSec;@JsonKey(name: 'section_title') String get sectionTitle;@JsonKey(name: 'course_id') String get courseId;@JsonKey(name: 'course_title') String get courseTitle;@JsonKey(name: 'thumbnail_url') String? get thumbnailUrl;
/// Create a copy of ResumeLesson
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResumeLessonCopyWith<ResumeLesson> get copyWith => _$ResumeLessonCopyWithImpl<ResumeLesson>(this as ResumeLesson, _$identity);

  /// Serializes this ResumeLesson to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResumeLesson&&(identical(other.progressPct, progressPct) || other.progressPct == progressPct)&&(identical(other.lastWatched, lastWatched) || other.lastWatched == lastWatched)&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.lessonTitle, lessonTitle) || other.lessonTitle == lessonTitle)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.sectionTitle, sectionTitle) || other.sectionTitle == sectionTitle)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.courseTitle, courseTitle) || other.courseTitle == courseTitle)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,progressPct,lastWatched,lessonId,lessonTitle,durationSec,sectionTitle,courseId,courseTitle,thumbnailUrl);

@override
String toString() {
  return 'ResumeLesson(progressPct: $progressPct, lastWatched: $lastWatched, lessonId: $lessonId, lessonTitle: $lessonTitle, durationSec: $durationSec, sectionTitle: $sectionTitle, courseId: $courseId, courseTitle: $courseTitle, thumbnailUrl: $thumbnailUrl)';
}


}

/// @nodoc
abstract mixin class $ResumeLessonCopyWith<$Res>  {
  factory $ResumeLessonCopyWith(ResumeLesson value, $Res Function(ResumeLesson) _then) = _$ResumeLessonCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'progress_pct') double progressPct,@JsonKey(name: 'last_watched') DateTime lastWatched,@JsonKey(name: 'lesson_id') String lessonId,@JsonKey(name: 'lesson_title') String lessonTitle,@JsonKey(name: 'duration_sec') int? durationSec,@JsonKey(name: 'section_title') String sectionTitle,@JsonKey(name: 'course_id') String courseId,@JsonKey(name: 'course_title') String courseTitle,@JsonKey(name: 'thumbnail_url') String? thumbnailUrl
});




}
/// @nodoc
class _$ResumeLessonCopyWithImpl<$Res>
    implements $ResumeLessonCopyWith<$Res> {
  _$ResumeLessonCopyWithImpl(this._self, this._then);

  final ResumeLesson _self;
  final $Res Function(ResumeLesson) _then;

/// Create a copy of ResumeLesson
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? progressPct = null,Object? lastWatched = null,Object? lessonId = null,Object? lessonTitle = null,Object? durationSec = freezed,Object? sectionTitle = null,Object? courseId = null,Object? courseTitle = null,Object? thumbnailUrl = freezed,}) {
  return _then(_self.copyWith(
progressPct: null == progressPct ? _self.progressPct : progressPct // ignore: cast_nullable_to_non_nullable
as double,lastWatched: null == lastWatched ? _self.lastWatched : lastWatched // ignore: cast_nullable_to_non_nullable
as DateTime,lessonId: null == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String,lessonTitle: null == lessonTitle ? _self.lessonTitle : lessonTitle // ignore: cast_nullable_to_non_nullable
as String,durationSec: freezed == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as int?,sectionTitle: null == sectionTitle ? _self.sectionTitle : sectionTitle // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,courseTitle: null == courseTitle ? _self.courseTitle : courseTitle // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ResumeLesson].
extension ResumeLessonPatterns on ResumeLesson {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ResumeLesson value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ResumeLesson() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ResumeLesson value)  $default,){
final _that = this;
switch (_that) {
case _ResumeLesson():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ResumeLesson value)?  $default,){
final _that = this;
switch (_that) {
case _ResumeLesson() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'last_watched')  DateTime lastWatched, @JsonKey(name: 'lesson_id')  String lessonId, @JsonKey(name: 'lesson_title')  String lessonTitle, @JsonKey(name: 'duration_sec')  int? durationSec, @JsonKey(name: 'section_title')  String sectionTitle, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'course_title')  String courseTitle, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ResumeLesson() when $default != null:
return $default(_that.progressPct,_that.lastWatched,_that.lessonId,_that.lessonTitle,_that.durationSec,_that.sectionTitle,_that.courseId,_that.courseTitle,_that.thumbnailUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'last_watched')  DateTime lastWatched, @JsonKey(name: 'lesson_id')  String lessonId, @JsonKey(name: 'lesson_title')  String lessonTitle, @JsonKey(name: 'duration_sec')  int? durationSec, @JsonKey(name: 'section_title')  String sectionTitle, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'course_title')  String courseTitle, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl)  $default,) {final _that = this;
switch (_that) {
case _ResumeLesson():
return $default(_that.progressPct,_that.lastWatched,_that.lessonId,_that.lessonTitle,_that.durationSec,_that.sectionTitle,_that.courseId,_that.courseTitle,_that.thumbnailUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'last_watched')  DateTime lastWatched, @JsonKey(name: 'lesson_id')  String lessonId, @JsonKey(name: 'lesson_title')  String lessonTitle, @JsonKey(name: 'duration_sec')  int? durationSec, @JsonKey(name: 'section_title')  String sectionTitle, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'course_title')  String courseTitle, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl)?  $default,) {final _that = this;
switch (_that) {
case _ResumeLesson() when $default != null:
return $default(_that.progressPct,_that.lastWatched,_that.lessonId,_that.lessonTitle,_that.durationSec,_that.sectionTitle,_that.courseId,_that.courseTitle,_that.thumbnailUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ResumeLesson implements ResumeLesson {
  const _ResumeLesson({@JsonKey(name: 'progress_pct') required this.progressPct, @JsonKey(name: 'last_watched') required this.lastWatched, @JsonKey(name: 'lesson_id') required this.lessonId, @JsonKey(name: 'lesson_title') required this.lessonTitle, @JsonKey(name: 'duration_sec') this.durationSec, @JsonKey(name: 'section_title') required this.sectionTitle, @JsonKey(name: 'course_id') required this.courseId, @JsonKey(name: 'course_title') required this.courseTitle, @JsonKey(name: 'thumbnail_url') this.thumbnailUrl});
  factory _ResumeLesson.fromJson(Map<String, dynamic> json) => _$ResumeLessonFromJson(json);

@override@JsonKey(name: 'progress_pct') final  double progressPct;
@override@JsonKey(name: 'last_watched') final  DateTime lastWatched;
@override@JsonKey(name: 'lesson_id') final  String lessonId;
@override@JsonKey(name: 'lesson_title') final  String lessonTitle;
@override@JsonKey(name: 'duration_sec') final  int? durationSec;
@override@JsonKey(name: 'section_title') final  String sectionTitle;
@override@JsonKey(name: 'course_id') final  String courseId;
@override@JsonKey(name: 'course_title') final  String courseTitle;
@override@JsonKey(name: 'thumbnail_url') final  String? thumbnailUrl;

/// Create a copy of ResumeLesson
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ResumeLessonCopyWith<_ResumeLesson> get copyWith => __$ResumeLessonCopyWithImpl<_ResumeLesson>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ResumeLessonToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ResumeLesson&&(identical(other.progressPct, progressPct) || other.progressPct == progressPct)&&(identical(other.lastWatched, lastWatched) || other.lastWatched == lastWatched)&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.lessonTitle, lessonTitle) || other.lessonTitle == lessonTitle)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.sectionTitle, sectionTitle) || other.sectionTitle == sectionTitle)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.courseTitle, courseTitle) || other.courseTitle == courseTitle)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,progressPct,lastWatched,lessonId,lessonTitle,durationSec,sectionTitle,courseId,courseTitle,thumbnailUrl);

@override
String toString() {
  return 'ResumeLesson(progressPct: $progressPct, lastWatched: $lastWatched, lessonId: $lessonId, lessonTitle: $lessonTitle, durationSec: $durationSec, sectionTitle: $sectionTitle, courseId: $courseId, courseTitle: $courseTitle, thumbnailUrl: $thumbnailUrl)';
}


}

/// @nodoc
abstract mixin class _$ResumeLessonCopyWith<$Res> implements $ResumeLessonCopyWith<$Res> {
  factory _$ResumeLessonCopyWith(_ResumeLesson value, $Res Function(_ResumeLesson) _then) = __$ResumeLessonCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'progress_pct') double progressPct,@JsonKey(name: 'last_watched') DateTime lastWatched,@JsonKey(name: 'lesson_id') String lessonId,@JsonKey(name: 'lesson_title') String lessonTitle,@JsonKey(name: 'duration_sec') int? durationSec,@JsonKey(name: 'section_title') String sectionTitle,@JsonKey(name: 'course_id') String courseId,@JsonKey(name: 'course_title') String courseTitle,@JsonKey(name: 'thumbnail_url') String? thumbnailUrl
});




}
/// @nodoc
class __$ResumeLessonCopyWithImpl<$Res>
    implements _$ResumeLessonCopyWith<$Res> {
  __$ResumeLessonCopyWithImpl(this._self, this._then);

  final _ResumeLesson _self;
  final $Res Function(_ResumeLesson) _then;

/// Create a copy of ResumeLesson
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? progressPct = null,Object? lastWatched = null,Object? lessonId = null,Object? lessonTitle = null,Object? durationSec = freezed,Object? sectionTitle = null,Object? courseId = null,Object? courseTitle = null,Object? thumbnailUrl = freezed,}) {
  return _then(_ResumeLesson(
progressPct: null == progressPct ? _self.progressPct : progressPct // ignore: cast_nullable_to_non_nullable
as double,lastWatched: null == lastWatched ? _self.lastWatched : lastWatched // ignore: cast_nullable_to_non_nullable
as DateTime,lessonId: null == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String,lessonTitle: null == lessonTitle ? _self.lessonTitle : lessonTitle // ignore: cast_nullable_to_non_nullable
as String,durationSec: freezed == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as int?,sectionTitle: null == sectionTitle ? _self.sectionTitle : sectionTitle // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,courseTitle: null == courseTitle ? _self.courseTitle : courseTitle // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
