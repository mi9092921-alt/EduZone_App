// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Course {

 String get id;@JsonKey(name: 'tenant_id') String get tenantId; String get title; String? get description; String get status;@JsonKey(name: 'thumbnail_url') String? get thumbnailUrl; String? get slug;@JsonKey(name: 'teacher_id') String? get teacherId; String? get category; String get level; double get price;@JsonKey(name: 'is_free') bool get isFree;@JsonKey(name: 'is_featured') bool get isFeatured;@JsonKey(name: 'is_discoverable') bool get isDiscoverable;@JsonKey(name: 'region_id') String? get regionId;@JsonKey(name: 'created_at') DateTime? get createdAt;@JsonKey(name: 'updated_at') DateTime? get updatedAt;@JsonKey(name: 'total_lessons') int? get totalLessons; double? get rating;@JsonKey(name: 'students_count') int? get studentsCount;@JsonKey(name: 'instructor_name') String? get instructorName;@JsonKey(name: 'instructor_avatar') String? get instructorAvatar; List<String>? get prerequisites;@JsonKey(name: 'learning_objectives') List<String>? get learningObjectives; String? get language;// Virtual fields joined by PostgREST or RPCs
 List<Section>? get sections;@JsonKey(name: 'progress_pct') double? get progressPct;@JsonKey(name: 'completed_lessons') int? get completedLessons;
/// Create a copy of Course
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CourseCopyWith<Course> get copyWith => _$CourseCopyWithImpl<Course>(this as Course, _$identity);

  /// Serializes this Course to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Course&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.teacherId, teacherId) || other.teacherId == teacherId)&&(identical(other.category, category) || other.category == category)&&(identical(other.level, level) || other.level == level)&&(identical(other.price, price) || other.price == price)&&(identical(other.isFree, isFree) || other.isFree == isFree)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.isDiscoverable, isDiscoverable) || other.isDiscoverable == isDiscoverable)&&(identical(other.regionId, regionId) || other.regionId == regionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.totalLessons, totalLessons) || other.totalLessons == totalLessons)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.studentsCount, studentsCount) || other.studentsCount == studentsCount)&&(identical(other.instructorName, instructorName) || other.instructorName == instructorName)&&(identical(other.instructorAvatar, instructorAvatar) || other.instructorAvatar == instructorAvatar)&&const DeepCollectionEquality().equals(other.prerequisites, prerequisites)&&const DeepCollectionEquality().equals(other.learningObjectives, learningObjectives)&&(identical(other.language, language) || other.language == language)&&const DeepCollectionEquality().equals(other.sections, sections)&&(identical(other.progressPct, progressPct) || other.progressPct == progressPct)&&(identical(other.completedLessons, completedLessons) || other.completedLessons == completedLessons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,title,description,status,thumbnailUrl,slug,teacherId,category,level,price,isFree,isFeatured,isDiscoverable,regionId,createdAt,updatedAt,totalLessons,rating,studentsCount,instructorName,instructorAvatar,const DeepCollectionEquality().hash(prerequisites),const DeepCollectionEquality().hash(learningObjectives),language,const DeepCollectionEquality().hash(sections),progressPct,completedLessons]);

@override
String toString() {
  return 'Course(id: $id, tenantId: $tenantId, title: $title, description: $description, status: $status, thumbnailUrl: $thumbnailUrl, slug: $slug, teacherId: $teacherId, category: $category, level: $level, price: $price, isFree: $isFree, isFeatured: $isFeatured, isDiscoverable: $isDiscoverable, regionId: $regionId, createdAt: $createdAt, updatedAt: $updatedAt, totalLessons: $totalLessons, rating: $rating, studentsCount: $studentsCount, instructorName: $instructorName, instructorAvatar: $instructorAvatar, prerequisites: $prerequisites, learningObjectives: $learningObjectives, language: $language, sections: $sections, progressPct: $progressPct, completedLessons: $completedLessons)';
}


}

/// @nodoc
abstract mixin class $CourseCopyWith<$Res>  {
  factory $CourseCopyWith(Course value, $Res Function(Course) _then) = _$CourseCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId, String title, String? description, String status,@JsonKey(name: 'thumbnail_url') String? thumbnailUrl, String? slug,@JsonKey(name: 'teacher_id') String? teacherId, String? category, String level, double price,@JsonKey(name: 'is_free') bool isFree,@JsonKey(name: 'is_featured') bool isFeatured,@JsonKey(name: 'is_discoverable') bool isDiscoverable,@JsonKey(name: 'region_id') String? regionId,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'total_lessons') int? totalLessons, double? rating,@JsonKey(name: 'students_count') int? studentsCount,@JsonKey(name: 'instructor_name') String? instructorName,@JsonKey(name: 'instructor_avatar') String? instructorAvatar, List<String>? prerequisites,@JsonKey(name: 'learning_objectives') List<String>? learningObjectives, String? language, List<Section>? sections,@JsonKey(name: 'progress_pct') double? progressPct,@JsonKey(name: 'completed_lessons') int? completedLessons
});




}
/// @nodoc
class _$CourseCopyWithImpl<$Res>
    implements $CourseCopyWith<$Res> {
  _$CourseCopyWithImpl(this._self, this._then);

  final Course _self;
  final $Res Function(Course) _then;

/// Create a copy of Course
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? tenantId = null,Object? title = null,Object? description = freezed,Object? status = null,Object? thumbnailUrl = freezed,Object? slug = freezed,Object? teacherId = freezed,Object? category = freezed,Object? level = null,Object? price = null,Object? isFree = null,Object? isFeatured = null,Object? isDiscoverable = null,Object? regionId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? totalLessons = freezed,Object? rating = freezed,Object? studentsCount = freezed,Object? instructorName = freezed,Object? instructorAvatar = freezed,Object? prerequisites = freezed,Object? learningObjectives = freezed,Object? language = freezed,Object? sections = freezed,Object? progressPct = freezed,Object? completedLessons = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,slug: freezed == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String?,teacherId: freezed == teacherId ? _self.teacherId : teacherId // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,isFree: null == isFree ? _self.isFree : isFree // ignore: cast_nullable_to_non_nullable
as bool,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,isDiscoverable: null == isDiscoverable ? _self.isDiscoverable : isDiscoverable // ignore: cast_nullable_to_non_nullable
as bool,regionId: freezed == regionId ? _self.regionId : regionId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,totalLessons: freezed == totalLessons ? _self.totalLessons : totalLessons // ignore: cast_nullable_to_non_nullable
as int?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,studentsCount: freezed == studentsCount ? _self.studentsCount : studentsCount // ignore: cast_nullable_to_non_nullable
as int?,instructorName: freezed == instructorName ? _self.instructorName : instructorName // ignore: cast_nullable_to_non_nullable
as String?,instructorAvatar: freezed == instructorAvatar ? _self.instructorAvatar : instructorAvatar // ignore: cast_nullable_to_non_nullable
as String?,prerequisites: freezed == prerequisites ? _self.prerequisites : prerequisites // ignore: cast_nullable_to_non_nullable
as List<String>?,learningObjectives: freezed == learningObjectives ? _self.learningObjectives : learningObjectives // ignore: cast_nullable_to_non_nullable
as List<String>?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,sections: freezed == sections ? _self.sections : sections // ignore: cast_nullable_to_non_nullable
as List<Section>?,progressPct: freezed == progressPct ? _self.progressPct : progressPct // ignore: cast_nullable_to_non_nullable
as double?,completedLessons: freezed == completedLessons ? _self.completedLessons : completedLessons // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Course].
extension CoursePatterns on Course {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Course value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Course() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Course value)  $default,){
final _that = this;
switch (_that) {
case _Course():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Course value)?  $default,){
final _that = this;
switch (_that) {
case _Course() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String title,  String? description,  String status, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl,  String? slug, @JsonKey(name: 'teacher_id')  String? teacherId,  String? category,  String level,  double price, @JsonKey(name: 'is_free')  bool isFree, @JsonKey(name: 'is_featured')  bool isFeatured, @JsonKey(name: 'is_discoverable')  bool isDiscoverable, @JsonKey(name: 'region_id')  String? regionId, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'total_lessons')  int? totalLessons,  double? rating, @JsonKey(name: 'students_count')  int? studentsCount, @JsonKey(name: 'instructor_name')  String? instructorName, @JsonKey(name: 'instructor_avatar')  String? instructorAvatar,  List<String>? prerequisites, @JsonKey(name: 'learning_objectives')  List<String>? learningObjectives,  String? language,  List<Section>? sections, @JsonKey(name: 'progress_pct')  double? progressPct, @JsonKey(name: 'completed_lessons')  int? completedLessons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Course() when $default != null:
return $default(_that.id,_that.tenantId,_that.title,_that.description,_that.status,_that.thumbnailUrl,_that.slug,_that.teacherId,_that.category,_that.level,_that.price,_that.isFree,_that.isFeatured,_that.isDiscoverable,_that.regionId,_that.createdAt,_that.updatedAt,_that.totalLessons,_that.rating,_that.studentsCount,_that.instructorName,_that.instructorAvatar,_that.prerequisites,_that.learningObjectives,_that.language,_that.sections,_that.progressPct,_that.completedLessons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String title,  String? description,  String status, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl,  String? slug, @JsonKey(name: 'teacher_id')  String? teacherId,  String? category,  String level,  double price, @JsonKey(name: 'is_free')  bool isFree, @JsonKey(name: 'is_featured')  bool isFeatured, @JsonKey(name: 'is_discoverable')  bool isDiscoverable, @JsonKey(name: 'region_id')  String? regionId, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'total_lessons')  int? totalLessons,  double? rating, @JsonKey(name: 'students_count')  int? studentsCount, @JsonKey(name: 'instructor_name')  String? instructorName, @JsonKey(name: 'instructor_avatar')  String? instructorAvatar,  List<String>? prerequisites, @JsonKey(name: 'learning_objectives')  List<String>? learningObjectives,  String? language,  List<Section>? sections, @JsonKey(name: 'progress_pct')  double? progressPct, @JsonKey(name: 'completed_lessons')  int? completedLessons)  $default,) {final _that = this;
switch (_that) {
case _Course():
return $default(_that.id,_that.tenantId,_that.title,_that.description,_that.status,_that.thumbnailUrl,_that.slug,_that.teacherId,_that.category,_that.level,_that.price,_that.isFree,_that.isFeatured,_that.isDiscoverable,_that.regionId,_that.createdAt,_that.updatedAt,_that.totalLessons,_that.rating,_that.studentsCount,_that.instructorName,_that.instructorAvatar,_that.prerequisites,_that.learningObjectives,_that.language,_that.sections,_that.progressPct,_that.completedLessons);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'tenant_id')  String tenantId,  String title,  String? description,  String status, @JsonKey(name: 'thumbnail_url')  String? thumbnailUrl,  String? slug, @JsonKey(name: 'teacher_id')  String? teacherId,  String? category,  String level,  double price, @JsonKey(name: 'is_free')  bool isFree, @JsonKey(name: 'is_featured')  bool isFeatured, @JsonKey(name: 'is_discoverable')  bool isDiscoverable, @JsonKey(name: 'region_id')  String? regionId, @JsonKey(name: 'created_at')  DateTime? createdAt, @JsonKey(name: 'updated_at')  DateTime? updatedAt, @JsonKey(name: 'total_lessons')  int? totalLessons,  double? rating, @JsonKey(name: 'students_count')  int? studentsCount, @JsonKey(name: 'instructor_name')  String? instructorName, @JsonKey(name: 'instructor_avatar')  String? instructorAvatar,  List<String>? prerequisites, @JsonKey(name: 'learning_objectives')  List<String>? learningObjectives,  String? language,  List<Section>? sections, @JsonKey(name: 'progress_pct')  double? progressPct, @JsonKey(name: 'completed_lessons')  int? completedLessons)?  $default,) {final _that = this;
switch (_that) {
case _Course() when $default != null:
return $default(_that.id,_that.tenantId,_that.title,_that.description,_that.status,_that.thumbnailUrl,_that.slug,_that.teacherId,_that.category,_that.level,_that.price,_that.isFree,_that.isFeatured,_that.isDiscoverable,_that.regionId,_that.createdAt,_that.updatedAt,_that.totalLessons,_that.rating,_that.studentsCount,_that.instructorName,_that.instructorAvatar,_that.prerequisites,_that.learningObjectives,_that.language,_that.sections,_that.progressPct,_that.completedLessons);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Course implements Course {
  const _Course({required this.id, @JsonKey(name: 'tenant_id') required this.tenantId, required this.title, this.description, required this.status, @JsonKey(name: 'thumbnail_url') this.thumbnailUrl, this.slug, @JsonKey(name: 'teacher_id') this.teacherId, this.category, this.level = 'beginner', this.price = 0, @JsonKey(name: 'is_free') this.isFree = true, @JsonKey(name: 'is_featured') this.isFeatured = false, @JsonKey(name: 'is_discoverable') this.isDiscoverable = true, @JsonKey(name: 'region_id') this.regionId, @JsonKey(name: 'created_at') this.createdAt, @JsonKey(name: 'updated_at') this.updatedAt, @JsonKey(name: 'total_lessons') this.totalLessons, this.rating, @JsonKey(name: 'students_count') this.studentsCount, @JsonKey(name: 'instructor_name') this.instructorName, @JsonKey(name: 'instructor_avatar') this.instructorAvatar, final  List<String>? prerequisites, @JsonKey(name: 'learning_objectives') final  List<String>? learningObjectives, this.language, final  List<Section>? sections, @JsonKey(name: 'progress_pct') this.progressPct, @JsonKey(name: 'completed_lessons') this.completedLessons}): _prerequisites = prerequisites,_learningObjectives = learningObjectives,_sections = sections;
  factory _Course.fromJson(Map<String, dynamic> json) => _$CourseFromJson(json);

@override final  String id;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override final  String title;
@override final  String? description;
@override final  String status;
@override@JsonKey(name: 'thumbnail_url') final  String? thumbnailUrl;
@override final  String? slug;
@override@JsonKey(name: 'teacher_id') final  String? teacherId;
@override final  String? category;
@override@JsonKey() final  String level;
@override@JsonKey() final  double price;
@override@JsonKey(name: 'is_free') final  bool isFree;
@override@JsonKey(name: 'is_featured') final  bool isFeatured;
@override@JsonKey(name: 'is_discoverable') final  bool isDiscoverable;
@override@JsonKey(name: 'region_id') final  String? regionId;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;
@override@JsonKey(name: 'updated_at') final  DateTime? updatedAt;
@override@JsonKey(name: 'total_lessons') final  int? totalLessons;
@override final  double? rating;
@override@JsonKey(name: 'students_count') final  int? studentsCount;
@override@JsonKey(name: 'instructor_name') final  String? instructorName;
@override@JsonKey(name: 'instructor_avatar') final  String? instructorAvatar;
 final  List<String>? _prerequisites;
@override List<String>? get prerequisites {
  final value = _prerequisites;
  if (value == null) return null;
  if (_prerequisites is EqualUnmodifiableListView) return _prerequisites;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String>? _learningObjectives;
@override@JsonKey(name: 'learning_objectives') List<String>? get learningObjectives {
  final value = _learningObjectives;
  if (value == null) return null;
  if (_learningObjectives is EqualUnmodifiableListView) return _learningObjectives;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? language;
// Virtual fields joined by PostgREST or RPCs
 final  List<Section>? _sections;
// Virtual fields joined by PostgREST or RPCs
@override List<Section>? get sections {
  final value = _sections;
  if (value == null) return null;
  if (_sections is EqualUnmodifiableListView) return _sections;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'progress_pct') final  double? progressPct;
@override@JsonKey(name: 'completed_lessons') final  int? completedLessons;

/// Create a copy of Course
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CourseCopyWith<_Course> get copyWith => __$CourseCopyWithImpl<_Course>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CourseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Course&&(identical(other.id, id) || other.id == id)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.status, status) || other.status == status)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.teacherId, teacherId) || other.teacherId == teacherId)&&(identical(other.category, category) || other.category == category)&&(identical(other.level, level) || other.level == level)&&(identical(other.price, price) || other.price == price)&&(identical(other.isFree, isFree) || other.isFree == isFree)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.isDiscoverable, isDiscoverable) || other.isDiscoverable == isDiscoverable)&&(identical(other.regionId, regionId) || other.regionId == regionId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.totalLessons, totalLessons) || other.totalLessons == totalLessons)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.studentsCount, studentsCount) || other.studentsCount == studentsCount)&&(identical(other.instructorName, instructorName) || other.instructorName == instructorName)&&(identical(other.instructorAvatar, instructorAvatar) || other.instructorAvatar == instructorAvatar)&&const DeepCollectionEquality().equals(other._prerequisites, _prerequisites)&&const DeepCollectionEquality().equals(other._learningObjectives, _learningObjectives)&&(identical(other.language, language) || other.language == language)&&const DeepCollectionEquality().equals(other._sections, _sections)&&(identical(other.progressPct, progressPct) || other.progressPct == progressPct)&&(identical(other.completedLessons, completedLessons) || other.completedLessons == completedLessons));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,tenantId,title,description,status,thumbnailUrl,slug,teacherId,category,level,price,isFree,isFeatured,isDiscoverable,regionId,createdAt,updatedAt,totalLessons,rating,studentsCount,instructorName,instructorAvatar,const DeepCollectionEquality().hash(_prerequisites),const DeepCollectionEquality().hash(_learningObjectives),language,const DeepCollectionEquality().hash(_sections),progressPct,completedLessons]);

@override
String toString() {
  return 'Course(id: $id, tenantId: $tenantId, title: $title, description: $description, status: $status, thumbnailUrl: $thumbnailUrl, slug: $slug, teacherId: $teacherId, category: $category, level: $level, price: $price, isFree: $isFree, isFeatured: $isFeatured, isDiscoverable: $isDiscoverable, regionId: $regionId, createdAt: $createdAt, updatedAt: $updatedAt, totalLessons: $totalLessons, rating: $rating, studentsCount: $studentsCount, instructorName: $instructorName, instructorAvatar: $instructorAvatar, prerequisites: $prerequisites, learningObjectives: $learningObjectives, language: $language, sections: $sections, progressPct: $progressPct, completedLessons: $completedLessons)';
}


}

/// @nodoc
abstract mixin class _$CourseCopyWith<$Res> implements $CourseCopyWith<$Res> {
  factory _$CourseCopyWith(_Course value, $Res Function(_Course) _then) = __$CourseCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'tenant_id') String tenantId, String title, String? description, String status,@JsonKey(name: 'thumbnail_url') String? thumbnailUrl, String? slug,@JsonKey(name: 'teacher_id') String? teacherId, String? category, String level, double price,@JsonKey(name: 'is_free') bool isFree,@JsonKey(name: 'is_featured') bool isFeatured,@JsonKey(name: 'is_discoverable') bool isDiscoverable,@JsonKey(name: 'region_id') String? regionId,@JsonKey(name: 'created_at') DateTime? createdAt,@JsonKey(name: 'updated_at') DateTime? updatedAt,@JsonKey(name: 'total_lessons') int? totalLessons, double? rating,@JsonKey(name: 'students_count') int? studentsCount,@JsonKey(name: 'instructor_name') String? instructorName,@JsonKey(name: 'instructor_avatar') String? instructorAvatar, List<String>? prerequisites,@JsonKey(name: 'learning_objectives') List<String>? learningObjectives, String? language, List<Section>? sections,@JsonKey(name: 'progress_pct') double? progressPct,@JsonKey(name: 'completed_lessons') int? completedLessons
});




}
/// @nodoc
class __$CourseCopyWithImpl<$Res>
    implements _$CourseCopyWith<$Res> {
  __$CourseCopyWithImpl(this._self, this._then);

  final _Course _self;
  final $Res Function(_Course) _then;

/// Create a copy of Course
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? tenantId = null,Object? title = null,Object? description = freezed,Object? status = null,Object? thumbnailUrl = freezed,Object? slug = freezed,Object? teacherId = freezed,Object? category = freezed,Object? level = null,Object? price = null,Object? isFree = null,Object? isFeatured = null,Object? isDiscoverable = null,Object? regionId = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? totalLessons = freezed,Object? rating = freezed,Object? studentsCount = freezed,Object? instructorName = freezed,Object? instructorAvatar = freezed,Object? prerequisites = freezed,Object? learningObjectives = freezed,Object? language = freezed,Object? sections = freezed,Object? progressPct = freezed,Object? completedLessons = freezed,}) {
  return _then(_Course(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,thumbnailUrl: freezed == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,slug: freezed == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String?,teacherId: freezed == teacherId ? _self.teacherId : teacherId // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as double,isFree: null == isFree ? _self.isFree : isFree // ignore: cast_nullable_to_non_nullable
as bool,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,isDiscoverable: null == isDiscoverable ? _self.isDiscoverable : isDiscoverable // ignore: cast_nullable_to_non_nullable
as bool,regionId: freezed == regionId ? _self.regionId : regionId // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,totalLessons: freezed == totalLessons ? _self.totalLessons : totalLessons // ignore: cast_nullable_to_non_nullable
as int?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,studentsCount: freezed == studentsCount ? _self.studentsCount : studentsCount // ignore: cast_nullable_to_non_nullable
as int?,instructorName: freezed == instructorName ? _self.instructorName : instructorName // ignore: cast_nullable_to_non_nullable
as String?,instructorAvatar: freezed == instructorAvatar ? _self.instructorAvatar : instructorAvatar // ignore: cast_nullable_to_non_nullable
as String?,prerequisites: freezed == prerequisites ? _self._prerequisites : prerequisites // ignore: cast_nullable_to_non_nullable
as List<String>?,learningObjectives: freezed == learningObjectives ? _self._learningObjectives : learningObjectives // ignore: cast_nullable_to_non_nullable
as List<String>?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,sections: freezed == sections ? _self._sections : sections // ignore: cast_nullable_to_non_nullable
as List<Section>?,progressPct: freezed == progressPct ? _self.progressPct : progressPct // ignore: cast_nullable_to_non_nullable
as double?,completedLessons: freezed == completedLessons ? _self.completedLessons : completedLessons // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
