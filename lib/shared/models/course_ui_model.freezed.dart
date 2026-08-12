// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'course_ui_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CourseUIModel {

 String get id; String get title; String? get description; String get thumbnailUrl; String get instructorName; String? get category; String? get level; String? get duration; int? get totalLessons; double? get rating; int? get studentsCount; String? get price; bool get isFeatured; bool get isFree; String? get status; double? get progress;
/// Create a copy of CourseUIModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CourseUIModelCopyWith<CourseUIModel> get copyWith => _$CourseUIModelCopyWithImpl<CourseUIModel>(this as CourseUIModel, _$identity);

  /// Serializes this CourseUIModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CourseUIModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.instructorName, instructorName) || other.instructorName == instructorName)&&(identical(other.category, category) || other.category == category)&&(identical(other.level, level) || other.level == level)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.totalLessons, totalLessons) || other.totalLessons == totalLessons)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.studentsCount, studentsCount) || other.studentsCount == studentsCount)&&(identical(other.price, price) || other.price == price)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.isFree, isFree) || other.isFree == isFree)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,thumbnailUrl,instructorName,category,level,duration,totalLessons,rating,studentsCount,price,isFeatured,isFree,status,progress);

@override
String toString() {
  return 'CourseUIModel(id: $id, title: $title, description: $description, thumbnailUrl: $thumbnailUrl, instructorName: $instructorName, category: $category, level: $level, duration: $duration, totalLessons: $totalLessons, rating: $rating, studentsCount: $studentsCount, price: $price, isFeatured: $isFeatured, isFree: $isFree, status: $status, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $CourseUIModelCopyWith<$Res>  {
  factory $CourseUIModelCopyWith(CourseUIModel value, $Res Function(CourseUIModel) _then) = _$CourseUIModelCopyWithImpl;
@useResult
$Res call({
 String id, String title, String? description, String thumbnailUrl, String instructorName, String? category, String? level, String? duration, int? totalLessons, double? rating, int? studentsCount, String? price, bool isFeatured, bool isFree, String? status, double? progress
});




}
/// @nodoc
class _$CourseUIModelCopyWithImpl<$Res>
    implements $CourseUIModelCopyWith<$Res> {
  _$CourseUIModelCopyWithImpl(this._self, this._then);

  final CourseUIModel _self;
  final $Res Function(CourseUIModel) _then;

/// Create a copy of CourseUIModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? thumbnailUrl = null,Object? instructorName = null,Object? category = freezed,Object? level = freezed,Object? duration = freezed,Object? totalLessons = freezed,Object? rating = freezed,Object? studentsCount = freezed,Object? price = freezed,Object? isFeatured = null,Object? isFree = null,Object? status = freezed,Object? progress = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: null == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String,instructorName: null == instructorName ? _self.instructorName : instructorName // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,level: freezed == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as String?,totalLessons: freezed == totalLessons ? _self.totalLessons : totalLessons // ignore: cast_nullable_to_non_nullable
as int?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,studentsCount: freezed == studentsCount ? _self.studentsCount : studentsCount // ignore: cast_nullable_to_non_nullable
as int?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as String?,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,isFree: null == isFree ? _self.isFree : isFree // ignore: cast_nullable_to_non_nullable
as bool,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [CourseUIModel].
extension CourseUIModelPatterns on CourseUIModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CourseUIModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CourseUIModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CourseUIModel value)  $default,){
final _that = this;
switch (_that) {
case _CourseUIModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CourseUIModel value)?  $default,){
final _that = this;
switch (_that) {
case _CourseUIModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String? description,  String thumbnailUrl,  String instructorName,  String? category,  String? level,  String? duration,  int? totalLessons,  double? rating,  int? studentsCount,  String? price,  bool isFeatured,  bool isFree,  String? status,  double? progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CourseUIModel() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.thumbnailUrl,_that.instructorName,_that.category,_that.level,_that.duration,_that.totalLessons,_that.rating,_that.studentsCount,_that.price,_that.isFeatured,_that.isFree,_that.status,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String? description,  String thumbnailUrl,  String instructorName,  String? category,  String? level,  String? duration,  int? totalLessons,  double? rating,  int? studentsCount,  String? price,  bool isFeatured,  bool isFree,  String? status,  double? progress)  $default,) {final _that = this;
switch (_that) {
case _CourseUIModel():
return $default(_that.id,_that.title,_that.description,_that.thumbnailUrl,_that.instructorName,_that.category,_that.level,_that.duration,_that.totalLessons,_that.rating,_that.studentsCount,_that.price,_that.isFeatured,_that.isFree,_that.status,_that.progress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String? description,  String thumbnailUrl,  String instructorName,  String? category,  String? level,  String? duration,  int? totalLessons,  double? rating,  int? studentsCount,  String? price,  bool isFeatured,  bool isFree,  String? status,  double? progress)?  $default,) {final _that = this;
switch (_that) {
case _CourseUIModel() when $default != null:
return $default(_that.id,_that.title,_that.description,_that.thumbnailUrl,_that.instructorName,_that.category,_that.level,_that.duration,_that.totalLessons,_that.rating,_that.studentsCount,_that.price,_that.isFeatured,_that.isFree,_that.status,_that.progress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CourseUIModel implements CourseUIModel {
  const _CourseUIModel({required this.id, required this.title, this.description, required this.thumbnailUrl, required this.instructorName, this.category, this.level, this.duration, this.totalLessons, this.rating, this.studentsCount, this.price, this.isFeatured = false, this.isFree = false, this.status, this.progress});
  factory _CourseUIModel.fromJson(Map<String, dynamic> json) => _$CourseUIModelFromJson(json);

@override final  String id;
@override final  String title;
@override final  String? description;
@override final  String thumbnailUrl;
@override final  String instructorName;
@override final  String? category;
@override final  String? level;
@override final  String? duration;
@override final  int? totalLessons;
@override final  double? rating;
@override final  int? studentsCount;
@override final  String? price;
@override@JsonKey() final  bool isFeatured;
@override@JsonKey() final  bool isFree;
@override final  String? status;
@override final  double? progress;

/// Create a copy of CourseUIModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CourseUIModelCopyWith<_CourseUIModel> get copyWith => __$CourseUIModelCopyWithImpl<_CourseUIModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CourseUIModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CourseUIModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.thumbnailUrl, thumbnailUrl) || other.thumbnailUrl == thumbnailUrl)&&(identical(other.instructorName, instructorName) || other.instructorName == instructorName)&&(identical(other.category, category) || other.category == category)&&(identical(other.level, level) || other.level == level)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.totalLessons, totalLessons) || other.totalLessons == totalLessons)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.studentsCount, studentsCount) || other.studentsCount == studentsCount)&&(identical(other.price, price) || other.price == price)&&(identical(other.isFeatured, isFeatured) || other.isFeatured == isFeatured)&&(identical(other.isFree, isFree) || other.isFree == isFree)&&(identical(other.status, status) || other.status == status)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,description,thumbnailUrl,instructorName,category,level,duration,totalLessons,rating,studentsCount,price,isFeatured,isFree,status,progress);

@override
String toString() {
  return 'CourseUIModel(id: $id, title: $title, description: $description, thumbnailUrl: $thumbnailUrl, instructorName: $instructorName, category: $category, level: $level, duration: $duration, totalLessons: $totalLessons, rating: $rating, studentsCount: $studentsCount, price: $price, isFeatured: $isFeatured, isFree: $isFree, status: $status, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$CourseUIModelCopyWith<$Res> implements $CourseUIModelCopyWith<$Res> {
  factory _$CourseUIModelCopyWith(_CourseUIModel value, $Res Function(_CourseUIModel) _then) = __$CourseUIModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String? description, String thumbnailUrl, String instructorName, String? category, String? level, String? duration, int? totalLessons, double? rating, int? studentsCount, String? price, bool isFeatured, bool isFree, String? status, double? progress
});




}
/// @nodoc
class __$CourseUIModelCopyWithImpl<$Res>
    implements _$CourseUIModelCopyWith<$Res> {
  __$CourseUIModelCopyWithImpl(this._self, this._then);

  final _CourseUIModel _self;
  final $Res Function(_CourseUIModel) _then;

/// Create a copy of CourseUIModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? description = freezed,Object? thumbnailUrl = null,Object? instructorName = null,Object? category = freezed,Object? level = freezed,Object? duration = freezed,Object? totalLessons = freezed,Object? rating = freezed,Object? studentsCount = freezed,Object? price = freezed,Object? isFeatured = null,Object? isFree = null,Object? status = freezed,Object? progress = freezed,}) {
  return _then(_CourseUIModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,thumbnailUrl: null == thumbnailUrl ? _self.thumbnailUrl : thumbnailUrl // ignore: cast_nullable_to_non_nullable
as String,instructorName: null == instructorName ? _self.instructorName : instructorName // ignore: cast_nullable_to_non_nullable
as String,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,level: freezed == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as String?,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as String?,totalLessons: freezed == totalLessons ? _self.totalLessons : totalLessons // ignore: cast_nullable_to_non_nullable
as int?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as double?,studentsCount: freezed == studentsCount ? _self.studentsCount : studentsCount // ignore: cast_nullable_to_non_nullable
as int?,price: freezed == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as String?,isFeatured: null == isFeatured ? _self.isFeatured : isFeatured // ignore: cast_nullable_to_non_nullable
as bool,isFree: null == isFree ? _self.isFree : isFree // ignore: cast_nullable_to_non_nullable
as bool,status: freezed == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String?,progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
