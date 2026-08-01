// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lesson.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Lesson {

 String get id;@JsonKey(name: 'section_id') String get sectionId;// Denormalized from sections→courses join (v11 seed has this column)
@JsonKey(name: 'course_id') String? get courseId;@JsonKey(name: 'tenant_id') String? get tenantId; String get title;@JsonKey(name: 'order_index') int get orderIndex;@JsonKey(name: 'is_published') bool get isPublished;// v11: free sample lesson — accessible without enrollment
@JsonKey(name: 'is_preview') bool get isPreview;@JsonKey(name: 'duration_sec') int? get durationSec;/// v12: Populated by get_course_lessons_with_access RPC
@JsonKey(name: 'has_access') bool get hasAccess;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;// Virtual join: current user's progress rows (RLS-filtered)
@JsonKey(name: 'user_progress') List<LessonProgress>? get userProgress;
/// Create a copy of Lesson
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LessonCopyWith<Lesson> get copyWith => _$LessonCopyWithImpl<Lesson>(this as Lesson, _$identity);

  /// Serializes this Lesson to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Lesson&&(identical(other.id, id) || other.id == id)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.title, title) || other.title == title)&&(identical(other.orderIndex, orderIndex) || other.orderIndex == orderIndex)&&(identical(other.isPublished, isPublished) || other.isPublished == isPublished)&&(identical(other.isPreview, isPreview) || other.isPreview == isPreview)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.hasAccess, hasAccess) || other.hasAccess == hasAccess)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.userProgress, userProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sectionId,courseId,tenantId,title,orderIndex,isPublished,isPreview,durationSec,hasAccess,createdAt,updatedAt,const DeepCollectionEquality().hash(userProgress));

@override
String toString() {
  return 'Lesson(id: $id, sectionId: $sectionId, courseId: $courseId, tenantId: $tenantId, title: $title, orderIndex: $orderIndex, isPublished: $isPublished, isPreview: $isPreview, durationSec: $durationSec, hasAccess: $hasAccess, createdAt: $createdAt, updatedAt: $updatedAt, userProgress: $userProgress)';
}


}

/// @nodoc
abstract mixin class $LessonCopyWith<$Res>  {
  factory $LessonCopyWith(Lesson value, $Res Function(Lesson) _then) = _$LessonCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'section_id') String sectionId,@JsonKey(name: 'course_id') String? courseId,@JsonKey(name: 'tenant_id') String? tenantId, String title,@JsonKey(name: 'order_index') int orderIndex,@JsonKey(name: 'is_published') bool isPublished,@JsonKey(name: 'is_preview') bool isPreview,@JsonKey(name: 'duration_sec') int? durationSec,@JsonKey(name: 'has_access') bool hasAccess,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'user_progress') List<LessonProgress>? userProgress
});




}
/// @nodoc
class _$LessonCopyWithImpl<$Res>
    implements $LessonCopyWith<$Res> {
  _$LessonCopyWithImpl(this._self, this._then);

  final Lesson _self;
  final $Res Function(Lesson) _then;

/// Create a copy of Lesson
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sectionId = null,Object? courseId = freezed,Object? tenantId = freezed,Object? title = null,Object? orderIndex = null,Object? isPublished = null,Object? isPreview = null,Object? durationSec = freezed,Object? hasAccess = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? userProgress = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sectionId: null == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String,courseId: freezed == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String?,tenantId: freezed == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,orderIndex: null == orderIndex ? _self.orderIndex : orderIndex // ignore: cast_nullable_to_non_nullable
as int,isPublished: null == isPublished ? _self.isPublished : isPublished // ignore: cast_nullable_to_non_nullable
as bool,isPreview: null == isPreview ? _self.isPreview : isPreview // ignore: cast_nullable_to_non_nullable
as bool,durationSec: freezed == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as int?,hasAccess: null == hasAccess ? _self.hasAccess : hasAccess // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,userProgress: freezed == userProgress ? _self.userProgress : userProgress // ignore: cast_nullable_to_non_nullable
as List<LessonProgress>?,
  ));
}

}


/// Adds pattern-matching-related methods to [Lesson].
extension LessonPatterns on Lesson {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Lesson value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Lesson() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Lesson value)  $default,){
final _that = this;
switch (_that) {
case _Lesson():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Lesson value)?  $default,){
final _that = this;
switch (_that) {
case _Lesson() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'section_id')  String sectionId, @JsonKey(name: 'course_id')  String? courseId, @JsonKey(name: 'tenant_id')  String? tenantId,  String title, @JsonKey(name: 'order_index')  int orderIndex, @JsonKey(name: 'is_published')  bool isPublished, @JsonKey(name: 'is_preview')  bool isPreview, @JsonKey(name: 'duration_sec')  int? durationSec, @JsonKey(name: 'has_access')  bool hasAccess, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'user_progress')  List<LessonProgress>? userProgress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Lesson() when $default != null:
return $default(_that.id,_that.sectionId,_that.courseId,_that.tenantId,_that.title,_that.orderIndex,_that.isPublished,_that.isPreview,_that.durationSec,_that.hasAccess,_that.createdAt,_that.updatedAt,_that.userProgress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'section_id')  String sectionId, @JsonKey(name: 'course_id')  String? courseId, @JsonKey(name: 'tenant_id')  String? tenantId,  String title, @JsonKey(name: 'order_index')  int orderIndex, @JsonKey(name: 'is_published')  bool isPublished, @JsonKey(name: 'is_preview')  bool isPreview, @JsonKey(name: 'duration_sec')  int? durationSec, @JsonKey(name: 'has_access')  bool hasAccess, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'user_progress')  List<LessonProgress>? userProgress)  $default,) {final _that = this;
switch (_that) {
case _Lesson():
return $default(_that.id,_that.sectionId,_that.courseId,_that.tenantId,_that.title,_that.orderIndex,_that.isPublished,_that.isPreview,_that.durationSec,_that.hasAccess,_that.createdAt,_that.updatedAt,_that.userProgress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'section_id')  String sectionId, @JsonKey(name: 'course_id')  String? courseId, @JsonKey(name: 'tenant_id')  String? tenantId,  String title, @JsonKey(name: 'order_index')  int orderIndex, @JsonKey(name: 'is_published')  bool isPublished, @JsonKey(name: 'is_preview')  bool isPreview, @JsonKey(name: 'duration_sec')  int? durationSec, @JsonKey(name: 'has_access')  bool hasAccess, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'user_progress')  List<LessonProgress>? userProgress)?  $default,) {final _that = this;
switch (_that) {
case _Lesson() when $default != null:
return $default(_that.id,_that.sectionId,_that.courseId,_that.tenantId,_that.title,_that.orderIndex,_that.isPublished,_that.isPreview,_that.durationSec,_that.hasAccess,_that.createdAt,_that.updatedAt,_that.userProgress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Lesson implements Lesson {
  const _Lesson({required this.id, @JsonKey(name: 'section_id') required this.sectionId, @JsonKey(name: 'course_id') this.courseId, @JsonKey(name: 'tenant_id') this.tenantId, required this.title, @JsonKey(name: 'order_index') this.orderIndex = 0, @JsonKey(name: 'is_published') this.isPublished = true, @JsonKey(name: 'is_preview') this.isPreview = false, @JsonKey(name: 'duration_sec') this.durationSec, @JsonKey(name: 'has_access') this.hasAccess = false, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, @JsonKey(name: 'user_progress') final  List<LessonProgress>? userProgress}): _userProgress = userProgress;
  factory _Lesson.fromJson(Map<String, dynamic> json) => _$LessonFromJson(json);

@override final  String id;
@override@JsonKey(name: 'section_id') final  String sectionId;
// Denormalized from sections→courses join (v11 seed has this column)
@override@JsonKey(name: 'course_id') final  String? courseId;
@override@JsonKey(name: 'tenant_id') final  String? tenantId;
@override final  String title;
@override@JsonKey(name: 'order_index') final  int orderIndex;
@override@JsonKey(name: 'is_published') final  bool isPublished;
// v11: free sample lesson — accessible without enrollment
@override@JsonKey(name: 'is_preview') final  bool isPreview;
@override@JsonKey(name: 'duration_sec') final  int? durationSec;
/// v12: Populated by get_course_lessons_with_access RPC
@override@JsonKey(name: 'has_access') final  bool hasAccess;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;
// Virtual join: current user's progress rows (RLS-filtered)
 final  List<LessonProgress>? _userProgress;
// Virtual join: current user's progress rows (RLS-filtered)
@override@JsonKey(name: 'user_progress') List<LessonProgress>? get userProgress {
  final value = _userProgress;
  if (value == null) return null;
  if (_userProgress is EqualUnmodifiableListView) return _userProgress;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of Lesson
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LessonCopyWith<_Lesson> get copyWith => __$LessonCopyWithImpl<_Lesson>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LessonToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Lesson&&(identical(other.id, id) || other.id == id)&&(identical(other.sectionId, sectionId) || other.sectionId == sectionId)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.title, title) || other.title == title)&&(identical(other.orderIndex, orderIndex) || other.orderIndex == orderIndex)&&(identical(other.isPublished, isPublished) || other.isPublished == isPublished)&&(identical(other.isPreview, isPreview) || other.isPreview == isPreview)&&(identical(other.durationSec, durationSec) || other.durationSec == durationSec)&&(identical(other.hasAccess, hasAccess) || other.hasAccess == hasAccess)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._userProgress, _userProgress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sectionId,courseId,tenantId,title,orderIndex,isPublished,isPreview,durationSec,hasAccess,createdAt,updatedAt,const DeepCollectionEquality().hash(_userProgress));

@override
String toString() {
  return 'Lesson(id: $id, sectionId: $sectionId, courseId: $courseId, tenantId: $tenantId, title: $title, orderIndex: $orderIndex, isPublished: $isPublished, isPreview: $isPreview, durationSec: $durationSec, hasAccess: $hasAccess, createdAt: $createdAt, updatedAt: $updatedAt, userProgress: $userProgress)';
}


}

/// @nodoc
abstract mixin class _$LessonCopyWith<$Res> implements $LessonCopyWith<$Res> {
  factory _$LessonCopyWith(_Lesson value, $Res Function(_Lesson) _then) = __$LessonCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'section_id') String sectionId,@JsonKey(name: 'course_id') String? courseId,@JsonKey(name: 'tenant_id') String? tenantId, String title,@JsonKey(name: 'order_index') int orderIndex,@JsonKey(name: 'is_published') bool isPublished,@JsonKey(name: 'is_preview') bool isPreview,@JsonKey(name: 'duration_sec') int? durationSec,@JsonKey(name: 'has_access') bool hasAccess,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'user_progress') List<LessonProgress>? userProgress
});




}
/// @nodoc
class __$LessonCopyWithImpl<$Res>
    implements _$LessonCopyWith<$Res> {
  __$LessonCopyWithImpl(this._self, this._then);

  final _Lesson _self;
  final $Res Function(_Lesson) _then;

/// Create a copy of Lesson
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sectionId = null,Object? courseId = freezed,Object? tenantId = freezed,Object? title = null,Object? orderIndex = null,Object? isPublished = null,Object? isPreview = null,Object? durationSec = freezed,Object? hasAccess = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? userProgress = freezed,}) {
  return _then(_Lesson(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sectionId: null == sectionId ? _self.sectionId : sectionId // ignore: cast_nullable_to_non_nullable
as String,courseId: freezed == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String?,tenantId: freezed == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,orderIndex: null == orderIndex ? _self.orderIndex : orderIndex // ignore: cast_nullable_to_non_nullable
as int,isPublished: null == isPublished ? _self.isPublished : isPublished // ignore: cast_nullable_to_non_nullable
as bool,isPreview: null == isPreview ? _self.isPreview : isPreview // ignore: cast_nullable_to_non_nullable
as bool,durationSec: freezed == durationSec ? _self.durationSec : durationSec // ignore: cast_nullable_to_non_nullable
as int?,hasAccess: null == hasAccess ? _self.hasAccess : hasAccess // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,userProgress: freezed == userProgress ? _self._userProgress : userProgress // ignore: cast_nullable_to_non_nullable
as List<LessonProgress>?,
  ));
}


}

// dart format on
