// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lesson_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LessonProgress {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'course_id') String get courseId;@JsonKey(name: 'lesson_id') String? get lessonId;@JsonKey(name: 'tenant_id') String get tenantId; bool get completed;@JsonKey(name: 'completed_at') DateTime? get completedAt;@JsonKey(name: 'progress_pct') double get progressPct;@JsonKey(name: 'watch_time_sec') int get watchTimeSec;@JsonKey(name: 'last_watched') DateTime? get lastWatched;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;
/// Create a copy of LessonProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LessonProgressCopyWith<LessonProgress> get copyWith => _$LessonProgressCopyWithImpl<LessonProgress>(this as LessonProgress, _$identity);

  /// Serializes this LessonProgress to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LessonProgress&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.progressPct, progressPct) || other.progressPct == progressPct)&&(identical(other.watchTimeSec, watchTimeSec) || other.watchTimeSec == watchTimeSec)&&(identical(other.lastWatched, lastWatched) || other.lastWatched == lastWatched)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,courseId,lessonId,tenantId,completed,completedAt,progressPct,watchTimeSec,lastWatched,createdAt,updatedAt);

@override
String toString() {
  return 'LessonProgress(id: $id, userId: $userId, courseId: $courseId, lessonId: $lessonId, tenantId: $tenantId, completed: $completed, completedAt: $completedAt, progressPct: $progressPct, watchTimeSec: $watchTimeSec, lastWatched: $lastWatched, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $LessonProgressCopyWith<$Res>  {
  factory $LessonProgressCopyWith(LessonProgress value, $Res Function(LessonProgress) _then) = _$LessonProgressCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'course_id') String courseId,@JsonKey(name: 'lesson_id') String? lessonId,@JsonKey(name: 'tenant_id') String tenantId, bool completed,@JsonKey(name: 'completed_at') DateTime? completedAt,@JsonKey(name: 'progress_pct') double progressPct,@JsonKey(name: 'watch_time_sec') int watchTimeSec,@JsonKey(name: 'last_watched') DateTime? lastWatched,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class _$LessonProgressCopyWithImpl<$Res>
    implements $LessonProgressCopyWith<$Res> {
  _$LessonProgressCopyWithImpl(this._self, this._then);

  final LessonProgress _self;
  final $Res Function(LessonProgress) _then;

/// Create a copy of LessonProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? courseId = null,Object? lessonId = freezed,Object? tenantId = null,Object? completed = null,Object? completedAt = freezed,Object? progressPct = null,Object? watchTimeSec = null,Object? lastWatched = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,lessonId: freezed == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String?,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,progressPct: null == progressPct ? _self.progressPct : progressPct // ignore: cast_nullable_to_non_nullable
as double,watchTimeSec: null == watchTimeSec ? _self.watchTimeSec : watchTimeSec // ignore: cast_nullable_to_non_nullable
as int,lastWatched: freezed == lastWatched ? _self.lastWatched : lastWatched // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [LessonProgress].
extension LessonProgressPatterns on LessonProgress {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LessonProgress value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LessonProgress() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LessonProgress value)  $default,){
final _that = this;
switch (_that) {
case _LessonProgress():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LessonProgress value)?  $default,){
final _that = this;
switch (_that) {
case _LessonProgress() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'lesson_id')  String? lessonId, @JsonKey(name: 'tenant_id')  String tenantId,  bool completed, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'watch_time_sec')  int watchTimeSec, @JsonKey(name: 'last_watched')  DateTime? lastWatched, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LessonProgress() when $default != null:
return $default(_that.id,_that.userId,_that.courseId,_that.lessonId,_that.tenantId,_that.completed,_that.completedAt,_that.progressPct,_that.watchTimeSec,_that.lastWatched,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'lesson_id')  String? lessonId, @JsonKey(name: 'tenant_id')  String tenantId,  bool completed, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'watch_time_sec')  int watchTimeSec, @JsonKey(name: 'last_watched')  DateTime? lastWatched, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _LessonProgress():
return $default(_that.id,_that.userId,_that.courseId,_that.lessonId,_that.tenantId,_that.completed,_that.completedAt,_that.progressPct,_that.watchTimeSec,_that.lastWatched,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'lesson_id')  String? lessonId, @JsonKey(name: 'tenant_id')  String tenantId,  bool completed, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'watch_time_sec')  int watchTimeSec, @JsonKey(name: 'last_watched')  DateTime? lastWatched, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _LessonProgress() when $default != null:
return $default(_that.id,_that.userId,_that.courseId,_that.lessonId,_that.tenantId,_that.completed,_that.completedAt,_that.progressPct,_that.watchTimeSec,_that.lastWatched,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LessonProgress implements LessonProgress {
  const _LessonProgress({required this.id, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'course_id') required this.courseId, @JsonKey(name: 'lesson_id') this.lessonId, @JsonKey(name: 'tenant_id') required this.tenantId, this.completed = false, @JsonKey(name: 'completed_at') this.completedAt, @JsonKey(name: 'progress_pct') this.progressPct = 0.0, @JsonKey(name: 'watch_time_sec') this.watchTimeSec = 0, @JsonKey(name: 'last_watched') this.lastWatched, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt});
  factory _LessonProgress.fromJson(Map<String, dynamic> json) => _$LessonProgressFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'course_id') final  String courseId;
@override@JsonKey(name: 'lesson_id') final  String? lessonId;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override@JsonKey() final  bool completed;
@override@JsonKey(name: 'completed_at') final  DateTime? completedAt;
@override@JsonKey(name: 'progress_pct') final  double progressPct;
@override@JsonKey(name: 'watch_time_sec') final  int watchTimeSec;
@override@JsonKey(name: 'last_watched') final  DateTime? lastWatched;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;

/// Create a copy of LessonProgress
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LessonProgressCopyWith<_LessonProgress> get copyWith => __$LessonProgressCopyWithImpl<_LessonProgress>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LessonProgressToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LessonProgress&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.lessonId, lessonId) || other.lessonId == lessonId)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.progressPct, progressPct) || other.progressPct == progressPct)&&(identical(other.watchTimeSec, watchTimeSec) || other.watchTimeSec == watchTimeSec)&&(identical(other.lastWatched, lastWatched) || other.lastWatched == lastWatched)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,courseId,lessonId,tenantId,completed,completedAt,progressPct,watchTimeSec,lastWatched,createdAt,updatedAt);

@override
String toString() {
  return 'LessonProgress(id: $id, userId: $userId, courseId: $courseId, lessonId: $lessonId, tenantId: $tenantId, completed: $completed, completedAt: $completedAt, progressPct: $progressPct, watchTimeSec: $watchTimeSec, lastWatched: $lastWatched, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$LessonProgressCopyWith<$Res> implements $LessonProgressCopyWith<$Res> {
  factory _$LessonProgressCopyWith(_LessonProgress value, $Res Function(_LessonProgress) _then) = __$LessonProgressCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'course_id') String courseId,@JsonKey(name: 'lesson_id') String? lessonId,@JsonKey(name: 'tenant_id') String tenantId, bool completed,@JsonKey(name: 'completed_at') DateTime? completedAt,@JsonKey(name: 'progress_pct') double progressPct,@JsonKey(name: 'watch_time_sec') int watchTimeSec,@JsonKey(name: 'last_watched') DateTime? lastWatched,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt
});




}
/// @nodoc
class __$LessonProgressCopyWithImpl<$Res>
    implements _$LessonProgressCopyWith<$Res> {
  __$LessonProgressCopyWithImpl(this._self, this._then);

  final _LessonProgress _self;
  final $Res Function(_LessonProgress) _then;

/// Create a copy of LessonProgress
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? courseId = null,Object? lessonId = freezed,Object? tenantId = null,Object? completed = null,Object? completedAt = freezed,Object? progressPct = null,Object? watchTimeSec = null,Object? lastWatched = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_LessonProgress(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,lessonId: freezed == lessonId ? _self.lessonId : lessonId // ignore: cast_nullable_to_non_nullable
as String?,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,progressPct: null == progressPct ? _self.progressPct : progressPct // ignore: cast_nullable_to_non_nullable
as double,watchTimeSec: null == watchTimeSec ? _self.watchTimeSec : watchTimeSec // ignore: cast_nullable_to_non_nullable
as int,lastWatched: freezed == lastWatched ? _self.lastWatched : lastWatched // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
