// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course_enrollment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CourseEnrollment {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'course_id') String get courseId;@JsonKey(name: 'tenant_id') String get tenantId; String get status;@JsonKey(name: 'enrolled_at') DateTime? get enrolledAt;@JsonKey(name: 'expires_at') DateTime? get expiresAt;@JsonKey(name: 'completed_at') DateTime? get completedAt;// Progress Tracking
@JsonKey(name: 'progress_pct') double get progressPct;@JsonKey(name: 'completed_lessons') int get completedLessons;@JsonKey(name: 'total_lessons') int get totalLessons;@JsonKey(name: 'last_watched_at') DateTime? get lastWatchedAt;@JsonKey(name: 'enrolled_by') String? get enrolledBy;@JsonKey(name: 'revoked_at') DateTime? get revokedAt;@JsonKey(name: 'revoked_by') String? get revokedBy;@JsonKey(name: 'revoke_reason') String? get revokeReason;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;// Virtual fields joined by PostgREST
 Course? get course;@JsonKey(name: 'progress_avg') double? get progressAvg;
/// Create a copy of CourseEnrollment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CourseEnrollmentCopyWith<CourseEnrollment> get copyWith => _$CourseEnrollmentCopyWithImpl<CourseEnrollment>(this as CourseEnrollment, _$identity);

  /// Serializes this CourseEnrollment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CourseEnrollment&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.status, status) || other.status == status)&&(identical(other.enrolledAt, enrolledAt) || other.enrolledAt == enrolledAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.progressPct, progressPct) || other.progressPct == progressPct)&&(identical(other.completedLessons, completedLessons) || other.completedLessons == completedLessons)&&(identical(other.totalLessons, totalLessons) || other.totalLessons == totalLessons)&&(identical(other.lastWatchedAt, lastWatchedAt) || other.lastWatchedAt == lastWatchedAt)&&(identical(other.enrolledBy, enrolledBy) || other.enrolledBy == enrolledBy)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.revokedBy, revokedBy) || other.revokedBy == revokedBy)&&(identical(other.revokeReason, revokeReason) || other.revokeReason == revokeReason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.course, course) || other.course == course)&&(identical(other.progressAvg, progressAvg) || other.progressAvg == progressAvg));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,courseId,tenantId,status,enrolledAt,expiresAt,completedAt,progressPct,completedLessons,totalLessons,lastWatchedAt,enrolledBy,revokedAt,revokedBy,revokeReason,createdAt,updatedAt,course,progressAvg]);

@override
String toString() {
  return 'CourseEnrollment(id: $id, userId: $userId, courseId: $courseId, tenantId: $tenantId, status: $status, enrolledAt: $enrolledAt, expiresAt: $expiresAt, completedAt: $completedAt, progressPct: $progressPct, completedLessons: $completedLessons, totalLessons: $totalLessons, lastWatchedAt: $lastWatchedAt, enrolledBy: $enrolledBy, revokedAt: $revokedAt, revokedBy: $revokedBy, revokeReason: $revokeReason, createdAt: $createdAt, updatedAt: $updatedAt, course: $course, progressAvg: $progressAvg)';
}


}

/// @nodoc
abstract mixin class $CourseEnrollmentCopyWith<$Res>  {
  factory $CourseEnrollmentCopyWith(CourseEnrollment value, $Res Function(CourseEnrollment) _then) = _$CourseEnrollmentCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'course_id') String courseId,@JsonKey(name: 'tenant_id') String tenantId, String status,@JsonKey(name: 'enrolled_at') DateTime? enrolledAt,@JsonKey(name: 'expires_at') DateTime? expiresAt,@JsonKey(name: 'completed_at') DateTime? completedAt,@JsonKey(name: 'progress_pct') double progressPct,@JsonKey(name: 'completed_lessons') int completedLessons,@JsonKey(name: 'total_lessons') int totalLessons,@JsonKey(name: 'last_watched_at') DateTime? lastWatchedAt,@JsonKey(name: 'enrolled_by') String? enrolledBy,@JsonKey(name: 'revoked_at') DateTime? revokedAt,@JsonKey(name: 'revoked_by') String? revokedBy,@JsonKey(name: 'revoke_reason') String? revokeReason,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt, Course? course,@JsonKey(name: 'progress_avg') double? progressAvg
});


$CourseCopyWith<$Res>? get course;

}
/// @nodoc
class _$CourseEnrollmentCopyWithImpl<$Res>
    implements $CourseEnrollmentCopyWith<$Res> {
  _$CourseEnrollmentCopyWithImpl(this._self, this._then);

  final CourseEnrollment _self;
  final $Res Function(CourseEnrollment) _then;

/// Create a copy of CourseEnrollment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? courseId = null,Object? tenantId = null,Object? status = null,Object? enrolledAt = freezed,Object? expiresAt = freezed,Object? completedAt = freezed,Object? progressPct = null,Object? completedLessons = null,Object? totalLessons = null,Object? lastWatchedAt = freezed,Object? enrolledBy = freezed,Object? revokedAt = freezed,Object? revokedBy = freezed,Object? revokeReason = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? course = freezed,Object? progressAvg = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,enrolledAt: freezed == enrolledAt ? _self.enrolledAt : enrolledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,progressPct: null == progressPct ? _self.progressPct : progressPct // ignore: cast_nullable_to_non_nullable
as double,completedLessons: null == completedLessons ? _self.completedLessons : completedLessons // ignore: cast_nullable_to_non_nullable
as int,totalLessons: null == totalLessons ? _self.totalLessons : totalLessons // ignore: cast_nullable_to_non_nullable
as int,lastWatchedAt: freezed == lastWatchedAt ? _self.lastWatchedAt : lastWatchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,enrolledBy: freezed == enrolledBy ? _self.enrolledBy : enrolledBy // ignore: cast_nullable_to_non_nullable
as String?,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedBy: freezed == revokedBy ? _self.revokedBy : revokedBy // ignore: cast_nullable_to_non_nullable
as String?,revokeReason: freezed == revokeReason ? _self.revokeReason : revokeReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,course: freezed == course ? _self.course : course // ignore: cast_nullable_to_non_nullable
as Course?,progressAvg: freezed == progressAvg ? _self.progressAvg : progressAvg // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}
/// Create a copy of CourseEnrollment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CourseCopyWith<$Res>? get course {
    if (_self.course == null) {
    return null;
  }

  return $CourseCopyWith<$Res>(_self.course!, (value) {
    return _then(_self.copyWith(course: value));
  });
}
}


/// Adds pattern-matching-related methods to [CourseEnrollment].
extension CourseEnrollmentPatterns on CourseEnrollment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CourseEnrollment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CourseEnrollment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CourseEnrollment value)  $default,){
final _that = this;
switch (_that) {
case _CourseEnrollment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CourseEnrollment value)?  $default,){
final _that = this;
switch (_that) {
case _CourseEnrollment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'tenant_id')  String tenantId,  String status, @JsonKey(name: 'enrolled_at')  DateTime? enrolledAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'completed_lessons')  int completedLessons, @JsonKey(name: 'total_lessons')  int totalLessons, @JsonKey(name: 'last_watched_at')  DateTime? lastWatchedAt, @JsonKey(name: 'enrolled_by')  String? enrolledBy, @JsonKey(name: 'revoked_at')  DateTime? revokedAt, @JsonKey(name: 'revoked_by')  String? revokedBy, @JsonKey(name: 'revoke_reason')  String? revokeReason, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt,  Course? course, @JsonKey(name: 'progress_avg')  double? progressAvg)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CourseEnrollment() when $default != null:
return $default(_that.id,_that.userId,_that.courseId,_that.tenantId,_that.status,_that.enrolledAt,_that.expiresAt,_that.completedAt,_that.progressPct,_that.completedLessons,_that.totalLessons,_that.lastWatchedAt,_that.enrolledBy,_that.revokedAt,_that.revokedBy,_that.revokeReason,_that.createdAt,_that.updatedAt,_that.course,_that.progressAvg);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'tenant_id')  String tenantId,  String status, @JsonKey(name: 'enrolled_at')  DateTime? enrolledAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'completed_lessons')  int completedLessons, @JsonKey(name: 'total_lessons')  int totalLessons, @JsonKey(name: 'last_watched_at')  DateTime? lastWatchedAt, @JsonKey(name: 'enrolled_by')  String? enrolledBy, @JsonKey(name: 'revoked_at')  DateTime? revokedAt, @JsonKey(name: 'revoked_by')  String? revokedBy, @JsonKey(name: 'revoke_reason')  String? revokeReason, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt,  Course? course, @JsonKey(name: 'progress_avg')  double? progressAvg)  $default,) {final _that = this;
switch (_that) {
case _CourseEnrollment():
return $default(_that.id,_that.userId,_that.courseId,_that.tenantId,_that.status,_that.enrolledAt,_that.expiresAt,_that.completedAt,_that.progressPct,_that.completedLessons,_that.totalLessons,_that.lastWatchedAt,_that.enrolledBy,_that.revokedAt,_that.revokedBy,_that.revokeReason,_that.createdAt,_that.updatedAt,_that.course,_that.progressAvg);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'tenant_id')  String tenantId,  String status, @JsonKey(name: 'enrolled_at')  DateTime? enrolledAt, @JsonKey(name: 'expires_at')  DateTime? expiresAt, @JsonKey(name: 'completed_at')  DateTime? completedAt, @JsonKey(name: 'progress_pct')  double progressPct, @JsonKey(name: 'completed_lessons')  int completedLessons, @JsonKey(name: 'total_lessons')  int totalLessons, @JsonKey(name: 'last_watched_at')  DateTime? lastWatchedAt, @JsonKey(name: 'enrolled_by')  String? enrolledBy, @JsonKey(name: 'revoked_at')  DateTime? revokedAt, @JsonKey(name: 'revoked_by')  String? revokedBy, @JsonKey(name: 'revoke_reason')  String? revokeReason, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt,  Course? course, @JsonKey(name: 'progress_avg')  double? progressAvg)?  $default,) {final _that = this;
switch (_that) {
case _CourseEnrollment() when $default != null:
return $default(_that.id,_that.userId,_that.courseId,_that.tenantId,_that.status,_that.enrolledAt,_that.expiresAt,_that.completedAt,_that.progressPct,_that.completedLessons,_that.totalLessons,_that.lastWatchedAt,_that.enrolledBy,_that.revokedAt,_that.revokedBy,_that.revokeReason,_that.createdAt,_that.updatedAt,_that.course,_that.progressAvg);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CourseEnrollment implements CourseEnrollment {
  const _CourseEnrollment({required this.id, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'course_id') required this.courseId, @JsonKey(name: 'tenant_id') required this.tenantId, this.status = 'active', @JsonKey(name: 'enrolled_at') this.enrolledAt, @JsonKey(name: 'expires_at') this.expiresAt, @JsonKey(name: 'completed_at') this.completedAt, @JsonKey(name: 'progress_pct') this.progressPct = 0, @JsonKey(name: 'completed_lessons') this.completedLessons = 0, @JsonKey(name: 'total_lessons') this.totalLessons = 0, @JsonKey(name: 'last_watched_at') this.lastWatchedAt, @JsonKey(name: 'enrolled_by') this.enrolledBy, @JsonKey(name: 'revoked_at') this.revokedAt, @JsonKey(name: 'revoked_by') this.revokedBy, @JsonKey(name: 'revoke_reason') this.revokeReason, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, this.course, @JsonKey(name: 'progress_avg') this.progressAvg});
  factory _CourseEnrollment.fromJson(Map<String, dynamic> json) => _$CourseEnrollmentFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'course_id') final  String courseId;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'enrolled_at') final  DateTime? enrolledAt;
@override@JsonKey(name: 'expires_at') final  DateTime? expiresAt;
@override@JsonKey(name: 'completed_at') final  DateTime? completedAt;
// Progress Tracking
@override@JsonKey(name: 'progress_pct') final  double progressPct;
@override@JsonKey(name: 'completed_lessons') final  int completedLessons;
@override@JsonKey(name: 'total_lessons') final  int totalLessons;
@override@JsonKey(name: 'last_watched_at') final  DateTime? lastWatchedAt;
@override@JsonKey(name: 'enrolled_by') final  String? enrolledBy;
@override@JsonKey(name: 'revoked_at') final  DateTime? revokedAt;
@override@JsonKey(name: 'revoked_by') final  String? revokedBy;
@override@JsonKey(name: 'revoke_reason') final  String? revokeReason;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;
// Virtual fields joined by PostgREST
@override final  Course? course;
@override@JsonKey(name: 'progress_avg') final  double? progressAvg;

/// Create a copy of CourseEnrollment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CourseEnrollmentCopyWith<_CourseEnrollment> get copyWith => __$CourseEnrollmentCopyWithImpl<_CourseEnrollment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CourseEnrollmentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CourseEnrollment&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.status, status) || other.status == status)&&(identical(other.enrolledAt, enrolledAt) || other.enrolledAt == enrolledAt)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.progressPct, progressPct) || other.progressPct == progressPct)&&(identical(other.completedLessons, completedLessons) || other.completedLessons == completedLessons)&&(identical(other.totalLessons, totalLessons) || other.totalLessons == totalLessons)&&(identical(other.lastWatchedAt, lastWatchedAt) || other.lastWatchedAt == lastWatchedAt)&&(identical(other.enrolledBy, enrolledBy) || other.enrolledBy == enrolledBy)&&(identical(other.revokedAt, revokedAt) || other.revokedAt == revokedAt)&&(identical(other.revokedBy, revokedBy) || other.revokedBy == revokedBy)&&(identical(other.revokeReason, revokeReason) || other.revokeReason == revokeReason)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.course, course) || other.course == course)&&(identical(other.progressAvg, progressAvg) || other.progressAvg == progressAvg));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,courseId,tenantId,status,enrolledAt,expiresAt,completedAt,progressPct,completedLessons,totalLessons,lastWatchedAt,enrolledBy,revokedAt,revokedBy,revokeReason,createdAt,updatedAt,course,progressAvg]);

@override
String toString() {
  return 'CourseEnrollment(id: $id, userId: $userId, courseId: $courseId, tenantId: $tenantId, status: $status, enrolledAt: $enrolledAt, expiresAt: $expiresAt, completedAt: $completedAt, progressPct: $progressPct, completedLessons: $completedLessons, totalLessons: $totalLessons, lastWatchedAt: $lastWatchedAt, enrolledBy: $enrolledBy, revokedAt: $revokedAt, revokedBy: $revokedBy, revokeReason: $revokeReason, createdAt: $createdAt, updatedAt: $updatedAt, course: $course, progressAvg: $progressAvg)';
}


}

/// @nodoc
abstract mixin class _$CourseEnrollmentCopyWith<$Res> implements $CourseEnrollmentCopyWith<$Res> {
  factory _$CourseEnrollmentCopyWith(_CourseEnrollment value, $Res Function(_CourseEnrollment) _then) = __$CourseEnrollmentCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'course_id') String courseId,@JsonKey(name: 'tenant_id') String tenantId, String status,@JsonKey(name: 'enrolled_at') DateTime? enrolledAt,@JsonKey(name: 'expires_at') DateTime? expiresAt,@JsonKey(name: 'completed_at') DateTime? completedAt,@JsonKey(name: 'progress_pct') double progressPct,@JsonKey(name: 'completed_lessons') int completedLessons,@JsonKey(name: 'total_lessons') int totalLessons,@JsonKey(name: 'last_watched_at') DateTime? lastWatchedAt,@JsonKey(name: 'enrolled_by') String? enrolledBy,@JsonKey(name: 'revoked_at') DateTime? revokedAt,@JsonKey(name: 'revoked_by') String? revokedBy,@JsonKey(name: 'revoke_reason') String? revokeReason,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt, Course? course,@JsonKey(name: 'progress_avg') double? progressAvg
});


@override $CourseCopyWith<$Res>? get course;

}
/// @nodoc
class __$CourseEnrollmentCopyWithImpl<$Res>
    implements _$CourseEnrollmentCopyWith<$Res> {
  __$CourseEnrollmentCopyWithImpl(this._self, this._then);

  final _CourseEnrollment _self;
  final $Res Function(_CourseEnrollment) _then;

/// Create a copy of CourseEnrollment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? courseId = null,Object? tenantId = null,Object? status = null,Object? enrolledAt = freezed,Object? expiresAt = freezed,Object? completedAt = freezed,Object? progressPct = null,Object? completedLessons = null,Object? totalLessons = null,Object? lastWatchedAt = freezed,Object? enrolledBy = freezed,Object? revokedAt = freezed,Object? revokedBy = freezed,Object? revokeReason = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? course = freezed,Object? progressAvg = freezed,}) {
  return _then(_CourseEnrollment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,enrolledAt: freezed == enrolledAt ? _self.enrolledAt : enrolledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,progressPct: null == progressPct ? _self.progressPct : progressPct // ignore: cast_nullable_to_non_nullable
as double,completedLessons: null == completedLessons ? _self.completedLessons : completedLessons // ignore: cast_nullable_to_non_nullable
as int,totalLessons: null == totalLessons ? _self.totalLessons : totalLessons // ignore: cast_nullable_to_non_nullable
as int,lastWatchedAt: freezed == lastWatchedAt ? _self.lastWatchedAt : lastWatchedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,enrolledBy: freezed == enrolledBy ? _self.enrolledBy : enrolledBy // ignore: cast_nullable_to_non_nullable
as String?,revokedAt: freezed == revokedAt ? _self.revokedAt : revokedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,revokedBy: freezed == revokedBy ? _self.revokedBy : revokedBy // ignore: cast_nullable_to_non_nullable
as String?,revokeReason: freezed == revokeReason ? _self.revokeReason : revokeReason // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,course: freezed == course ? _self.course : course // ignore: cast_nullable_to_non_nullable
as Course?,progressAvg: freezed == progressAvg ? _self.progressAvg : progressAvg // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

/// Create a copy of CourseEnrollment
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CourseCopyWith<$Res>? get course {
    if (_self.course == null) {
    return null;
  }

  return $CourseCopyWith<$Res>(_self.course!, (value) {
    return _then(_self.copyWith(course: value));
  });
}
}

// dart format on
