// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course_progress_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CourseProgressSummary {

@JsonKey(name: 'courseId') String? get courseId;@JsonKey(name: 'enrolledCount') int get enrolledCount;@JsonKey(name: 'avgProgress') double get avgProgress;@JsonKey(name: 'completedCount') int get completedCount;
/// Create a copy of CourseProgressSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CourseProgressSummaryCopyWith<CourseProgressSummary> get copyWith => _$CourseProgressSummaryCopyWithImpl<CourseProgressSummary>(this as CourseProgressSummary, _$identity);

  /// Serializes this CourseProgressSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CourseProgressSummary&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.enrolledCount, enrolledCount) || other.enrolledCount == enrolledCount)&&(identical(other.avgProgress, avgProgress) || other.avgProgress == avgProgress)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,courseId,enrolledCount,avgProgress,completedCount);

@override
String toString() {
  return 'CourseProgressSummary(courseId: $courseId, enrolledCount: $enrolledCount, avgProgress: $avgProgress, completedCount: $completedCount)';
}


}

/// @nodoc
abstract mixin class $CourseProgressSummaryCopyWith<$Res>  {
  factory $CourseProgressSummaryCopyWith(CourseProgressSummary value, $Res Function(CourseProgressSummary) _then) = _$CourseProgressSummaryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'courseId') String? courseId,@JsonKey(name: 'enrolledCount') int enrolledCount,@JsonKey(name: 'avgProgress') double avgProgress,@JsonKey(name: 'completedCount') int completedCount
});




}
/// @nodoc
class _$CourseProgressSummaryCopyWithImpl<$Res>
    implements $CourseProgressSummaryCopyWith<$Res> {
  _$CourseProgressSummaryCopyWithImpl(this._self, this._then);

  final CourseProgressSummary _self;
  final $Res Function(CourseProgressSummary) _then;

/// Create a copy of CourseProgressSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? courseId = freezed,Object? enrolledCount = null,Object? avgProgress = null,Object? completedCount = null,}) {
  return _then(_self.copyWith(
courseId: freezed == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String?,enrolledCount: null == enrolledCount ? _self.enrolledCount : enrolledCount // ignore: cast_nullable_to_non_nullable
as int,avgProgress: null == avgProgress ? _self.avgProgress : avgProgress // ignore: cast_nullable_to_non_nullable
as double,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CourseProgressSummary].
extension CourseProgressSummaryPatterns on CourseProgressSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CourseProgressSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CourseProgressSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CourseProgressSummary value)  $default,){
final _that = this;
switch (_that) {
case _CourseProgressSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CourseProgressSummary value)?  $default,){
final _that = this;
switch (_that) {
case _CourseProgressSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'courseId')  String? courseId, @JsonKey(name: 'enrolledCount')  int enrolledCount, @JsonKey(name: 'avgProgress')  double avgProgress, @JsonKey(name: 'completedCount')  int completedCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CourseProgressSummary() when $default != null:
return $default(_that.courseId,_that.enrolledCount,_that.avgProgress,_that.completedCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'courseId')  String? courseId, @JsonKey(name: 'enrolledCount')  int enrolledCount, @JsonKey(name: 'avgProgress')  double avgProgress, @JsonKey(name: 'completedCount')  int completedCount)  $default,) {final _that = this;
switch (_that) {
case _CourseProgressSummary():
return $default(_that.courseId,_that.enrolledCount,_that.avgProgress,_that.completedCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'courseId')  String? courseId, @JsonKey(name: 'enrolledCount')  int enrolledCount, @JsonKey(name: 'avgProgress')  double avgProgress, @JsonKey(name: 'completedCount')  int completedCount)?  $default,) {final _that = this;
switch (_that) {
case _CourseProgressSummary() when $default != null:
return $default(_that.courseId,_that.enrolledCount,_that.avgProgress,_that.completedCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CourseProgressSummary extends CourseProgressSummary {
  const _CourseProgressSummary({@JsonKey(name: 'courseId') this.courseId, @JsonKey(name: 'enrolledCount') this.enrolledCount = 0, @JsonKey(name: 'avgProgress') this.avgProgress = 0.0, @JsonKey(name: 'completedCount') this.completedCount = 0}): super._();
  factory _CourseProgressSummary.fromJson(Map<String, dynamic> json) => _$CourseProgressSummaryFromJson(json);

@override@JsonKey(name: 'courseId') final  String? courseId;
@override@JsonKey(name: 'enrolledCount') final  int enrolledCount;
@override@JsonKey(name: 'avgProgress') final  double avgProgress;
@override@JsonKey(name: 'completedCount') final  int completedCount;

/// Create a copy of CourseProgressSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CourseProgressSummaryCopyWith<_CourseProgressSummary> get copyWith => __$CourseProgressSummaryCopyWithImpl<_CourseProgressSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CourseProgressSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CourseProgressSummary&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.enrolledCount, enrolledCount) || other.enrolledCount == enrolledCount)&&(identical(other.avgProgress, avgProgress) || other.avgProgress == avgProgress)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,courseId,enrolledCount,avgProgress,completedCount);

@override
String toString() {
  return 'CourseProgressSummary(courseId: $courseId, enrolledCount: $enrolledCount, avgProgress: $avgProgress, completedCount: $completedCount)';
}


}

/// @nodoc
abstract mixin class _$CourseProgressSummaryCopyWith<$Res> implements $CourseProgressSummaryCopyWith<$Res> {
  factory _$CourseProgressSummaryCopyWith(_CourseProgressSummary value, $Res Function(_CourseProgressSummary) _then) = __$CourseProgressSummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'courseId') String? courseId,@JsonKey(name: 'enrolledCount') int enrolledCount,@JsonKey(name: 'avgProgress') double avgProgress,@JsonKey(name: 'completedCount') int completedCount
});




}
/// @nodoc
class __$CourseProgressSummaryCopyWithImpl<$Res>
    implements _$CourseProgressSummaryCopyWith<$Res> {
  __$CourseProgressSummaryCopyWithImpl(this._self, this._then);

  final _CourseProgressSummary _self;
  final $Res Function(_CourseProgressSummary) _then;

/// Create a copy of CourseProgressSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? courseId = freezed,Object? enrolledCount = null,Object? avgProgress = null,Object? completedCount = null,}) {
  return _then(_CourseProgressSummary(
courseId: freezed == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String?,enrolledCount: null == enrolledCount ? _self.enrolledCount : enrolledCount // ignore: cast_nullable_to_non_nullable
as int,avgProgress: null == avgProgress ? _self.avgProgress : avgProgress // ignore: cast_nullable_to_non_nullable
as double,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
