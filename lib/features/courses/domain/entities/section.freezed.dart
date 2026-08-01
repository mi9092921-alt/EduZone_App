// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Section {

 String get id;@JsonKey(name: 'course_id') String get courseId;@JsonKey(name: 'tenant_id') String get tenantId; String get title; String? get description;@JsonKey(name: 'order_index') int get orderIndex;@JsonKey(name: 'is_published') bool get isPublished;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;// Joined aggregate
 List<Lesson>? get lessons;
/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SectionCopyWith<Section> get copyWith => _$SectionCopyWithImpl<Section>(this as Section, _$identity);

  /// Serializes this Section to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Section&&(identical(other.id, id) || other.id == id)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.orderIndex, orderIndex) || other.orderIndex == orderIndex)&&(identical(other.isPublished, isPublished) || other.isPublished == isPublished)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.lessons, lessons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,courseId,tenantId,title,description,orderIndex,isPublished,createdAt,updatedAt,const DeepCollectionEquality().hash(lessons));

@override
String toString() {
  return 'Section(id: $id, courseId: $courseId, tenantId: $tenantId, title: $title, description: $description, orderIndex: $orderIndex, isPublished: $isPublished, createdAt: $createdAt, updatedAt: $updatedAt, lessons: $lessons)';
}


}

/// @nodoc
abstract mixin class $SectionCopyWith<$Res>  {
  factory $SectionCopyWith(Section value, $Res Function(Section) _then) = _$SectionCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'course_id') String courseId,@JsonKey(name: 'tenant_id') String tenantId, String title, String? description,@JsonKey(name: 'order_index') int orderIndex,@JsonKey(name: 'is_published') bool isPublished,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt, List<Lesson>? lessons
});




}
/// @nodoc
class _$SectionCopyWithImpl<$Res>
    implements $SectionCopyWith<$Res> {
  _$SectionCopyWithImpl(this._self, this._then);

  final Section _self;
  final $Res Function(Section) _then;

/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? courseId = null,Object? tenantId = null,Object? title = null,Object? description = freezed,Object? orderIndex = null,Object? isPublished = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? lessons = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,orderIndex: null == orderIndex ? _self.orderIndex : orderIndex // ignore: cast_nullable_to_non_nullable
as int,isPublished: null == isPublished ? _self.isPublished : isPublished // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lessons: freezed == lessons ? _self.lessons : lessons // ignore: cast_nullable_to_non_nullable
as List<Lesson>?,
  ));
}

}


/// Adds pattern-matching-related methods to [Section].
extension SectionPatterns on Section {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Section value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Section() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Section value)  $default,){
final _that = this;
switch (_that) {
case _Section():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Section value)?  $default,){
final _that = this;
switch (_that) {
case _Section() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'tenant_id')  String tenantId,  String title,  String? description, @JsonKey(name: 'order_index')  int orderIndex, @JsonKey(name: 'is_published')  bool isPublished, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt,  List<Lesson>? lessons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Section() when $default != null:
return $default(_that.id,_that.courseId,_that.tenantId,_that.title,_that.description,_that.orderIndex,_that.isPublished,_that.createdAt,_that.updatedAt,_that.lessons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'tenant_id')  String tenantId,  String title,  String? description, @JsonKey(name: 'order_index')  int orderIndex, @JsonKey(name: 'is_published')  bool isPublished, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt,  List<Lesson>? lessons)  $default,) {final _that = this;
switch (_that) {
case _Section():
return $default(_that.id,_that.courseId,_that.tenantId,_that.title,_that.description,_that.orderIndex,_that.isPublished,_that.createdAt,_that.updatedAt,_that.lessons);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'course_id')  String courseId, @JsonKey(name: 'tenant_id')  String tenantId,  String title,  String? description, @JsonKey(name: 'order_index')  int orderIndex, @JsonKey(name: 'is_published')  bool isPublished, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt,  List<Lesson>? lessons)?  $default,) {final _that = this;
switch (_that) {
case _Section() when $default != null:
return $default(_that.id,_that.courseId,_that.tenantId,_that.title,_that.description,_that.orderIndex,_that.isPublished,_that.createdAt,_that.updatedAt,_that.lessons);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Section implements Section {
  const _Section({required this.id, @JsonKey(name: 'course_id') required this.courseId, @JsonKey(name: 'tenant_id') required this.tenantId, required this.title, this.description, @JsonKey(name: 'order_index') this.orderIndex = 0, @JsonKey(name: 'is_published') this.isPublished = false, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, final  List<Lesson>? lessons}): _lessons = lessons;
  factory _Section.fromJson(Map<String, dynamic> json) => _$SectionFromJson(json);

@override final  String id;
@override@JsonKey(name: 'course_id') final  String courseId;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override final  String title;
@override final  String? description;
@override@JsonKey(name: 'order_index') final  int orderIndex;
@override@JsonKey(name: 'is_published') final  bool isPublished;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;
// Joined aggregate
 final  List<Lesson>? _lessons;
// Joined aggregate
@override List<Lesson>? get lessons {
  final value = _lessons;
  if (value == null) return null;
  if (_lessons is EqualUnmodifiableListView) return _lessons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SectionCopyWith<_Section> get copyWith => __$SectionCopyWithImpl<_Section>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Section&&(identical(other.id, id) || other.id == id)&&(identical(other.courseId, courseId) || other.courseId == courseId)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.orderIndex, orderIndex) || other.orderIndex == orderIndex)&&(identical(other.isPublished, isPublished) || other.isPublished == isPublished)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._lessons, _lessons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,courseId,tenantId,title,description,orderIndex,isPublished,createdAt,updatedAt,const DeepCollectionEquality().hash(_lessons));

@override
String toString() {
  return 'Section(id: $id, courseId: $courseId, tenantId: $tenantId, title: $title, description: $description, orderIndex: $orderIndex, isPublished: $isPublished, createdAt: $createdAt, updatedAt: $updatedAt, lessons: $lessons)';
}


}

/// @nodoc
abstract mixin class _$SectionCopyWith<$Res> implements $SectionCopyWith<$Res> {
  factory _$SectionCopyWith(_Section value, $Res Function(_Section) _then) = __$SectionCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'course_id') String courseId,@JsonKey(name: 'tenant_id') String tenantId, String title, String? description,@JsonKey(name: 'order_index') int orderIndex,@JsonKey(name: 'is_published') bool isPublished,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt, List<Lesson>? lessons
});




}
/// @nodoc
class __$SectionCopyWithImpl<$Res>
    implements _$SectionCopyWith<$Res> {
  __$SectionCopyWithImpl(this._self, this._then);

  final _Section _self;
  final $Res Function(_Section) _then;

/// Create a copy of Section
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? courseId = null,Object? tenantId = null,Object? title = null,Object? description = freezed,Object? orderIndex = null,Object? isPublished = null,Object? createdAt = freezed,Object? updatedAt = freezed,Object? lessons = freezed,}) {
  return _then(_Section(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,courseId: null == courseId ? _self.courseId : courseId // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,orderIndex: null == orderIndex ? _self.orderIndex : orderIndex // ignore: cast_nullable_to_non_nullable
as int,isPublished: null == isPublished ? _self.isPublished : isPublished // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lessons: freezed == lessons ? _self._lessons : lessons // ignore: cast_nullable_to_non_nullable
as List<Lesson>?,
  ));
}


}

// dart format on
