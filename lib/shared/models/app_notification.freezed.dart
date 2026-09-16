// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_notification.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppNotification {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'notification_id') String? get notificationId;@JsonKey(name: 'is_read') bool get isRead;@JsonKey(name: 'read_at') DateTime? get readAt;@JsonKey(name: 'tenant_id') String get tenantId;@JsonKey(name: 'created_at') DateTime get createdAt;/// Nested notification details from the `notifications` table.
/// This is populated via a join in the remote data source.
@JsonKey(name: 'notification') NotificationDetails? get details;
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppNotificationCopyWith<AppNotification> get copyWith => _$AppNotificationCopyWithImpl<AppNotification>(this as AppNotification, _$identity);

  /// Serializes this AppNotification to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.details, details) || other.details == details));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,notificationId,isRead,readAt,tenantId,createdAt,details);

@override
String toString() {
  return 'AppNotification(id: $id, userId: $userId, notificationId: $notificationId, isRead: $isRead, readAt: $readAt, tenantId: $tenantId, createdAt: $createdAt, details: $details)';
}


}

/// @nodoc
abstract mixin class $AppNotificationCopyWith<$Res>  {
  factory $AppNotificationCopyWith(AppNotification value, $Res Function(AppNotification) _then) = _$AppNotificationCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'notification_id') String? notificationId,@JsonKey(name: 'is_read') bool isRead,@JsonKey(name: 'read_at') DateTime? readAt,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'notification') NotificationDetails? details
});


$NotificationDetailsCopyWith<$Res>? get details;

}
/// @nodoc
class _$AppNotificationCopyWithImpl<$Res>
    implements $AppNotificationCopyWith<$Res> {
  _$AppNotificationCopyWithImpl(this._self, this._then);

  final AppNotification _self;
  final $Res Function(AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? notificationId = freezed,Object? isRead = null,Object? readAt = freezed,Object? tenantId = null,Object? createdAt = null,Object? details = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,notificationId: freezed == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String?,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as NotificationDetails?,
  ));
}
/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationDetailsCopyWith<$Res>? get details {
    if (_self.details == null) {
    return null;
  }

  return $NotificationDetailsCopyWith<$Res>(_self.details!, (value) {
    return _then(_self.copyWith(details: value));
  });
}
}


/// Adds pattern-matching-related methods to [AppNotification].
extension AppNotificationPatterns on AppNotification {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppNotification value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppNotification value)  $default,){
final _that = this;
switch (_that) {
case _AppNotification():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppNotification value)?  $default,){
final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'notification_id')  String? notificationId, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'notification')  NotificationDetails? details)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.userId,_that.notificationId,_that.isRead,_that.readAt,_that.tenantId,_that.createdAt,_that.details);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'notification_id')  String? notificationId, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'notification')  NotificationDetails? details)  $default,) {final _that = this;
switch (_that) {
case _AppNotification():
return $default(_that.id,_that.userId,_that.notificationId,_that.isRead,_that.readAt,_that.tenantId,_that.createdAt,_that.details);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'notification_id')  String? notificationId, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'read_at')  DateTime? readAt, @JsonKey(name: 'tenant_id')  String tenantId, @JsonKey(name: 'created_at')  DateTime createdAt, @JsonKey(name: 'notification')  NotificationDetails? details)?  $default,) {final _that = this;
switch (_that) {
case _AppNotification() when $default != null:
return $default(_that.id,_that.userId,_that.notificationId,_that.isRead,_that.readAt,_that.tenantId,_that.createdAt,_that.details);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppNotification extends AppNotification {
  const _AppNotification({required this.id, @JsonKey(name: 'user_id') required this.userId, @JsonKey(name: 'notification_id') this.notificationId, @JsonKey(name: 'is_read') this.isRead = false, @JsonKey(name: 'read_at') this.readAt, @JsonKey(name: 'tenant_id') required this.tenantId, @JsonKey(name: 'created_at') required this.createdAt, @JsonKey(name: 'notification') this.details}): super._();
  factory _AppNotification.fromJson(Map<String, dynamic> json) => _$AppNotificationFromJson(json);

@override final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'notification_id') final  String? notificationId;
@override@JsonKey(name: 'is_read') final  bool isRead;
@override@JsonKey(name: 'read_at') final  DateTime? readAt;
@override@JsonKey(name: 'tenant_id') final  String tenantId;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
/// Nested notification details from the `notifications` table.
/// This is populated via a join in the remote data source.
@override@JsonKey(name: 'notification') final  NotificationDetails? details;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppNotificationCopyWith<_AppNotification> get copyWith => __$AppNotificationCopyWithImpl<_AppNotification>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppNotificationToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppNotification&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.notificationId, notificationId) || other.notificationId == notificationId)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.readAt, readAt) || other.readAt == readAt)&&(identical(other.tenantId, tenantId) || other.tenantId == tenantId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.details, details) || other.details == details));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,notificationId,isRead,readAt,tenantId,createdAt,details);

@override
String toString() {
  return 'AppNotification(id: $id, userId: $userId, notificationId: $notificationId, isRead: $isRead, readAt: $readAt, tenantId: $tenantId, createdAt: $createdAt, details: $details)';
}


}

/// @nodoc
abstract mixin class _$AppNotificationCopyWith<$Res> implements $AppNotificationCopyWith<$Res> {
  factory _$AppNotificationCopyWith(_AppNotification value, $Res Function(_AppNotification) _then) = __$AppNotificationCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'notification_id') String? notificationId,@JsonKey(name: 'is_read') bool isRead,@JsonKey(name: 'read_at') DateTime? readAt,@JsonKey(name: 'tenant_id') String tenantId,@JsonKey(name: 'created_at') DateTime createdAt,@JsonKey(name: 'notification') NotificationDetails? details
});


@override $NotificationDetailsCopyWith<$Res>? get details;

}
/// @nodoc
class __$AppNotificationCopyWithImpl<$Res>
    implements _$AppNotificationCopyWith<$Res> {
  __$AppNotificationCopyWithImpl(this._self, this._then);

  final _AppNotification _self;
  final $Res Function(_AppNotification) _then;

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? notificationId = freezed,Object? isRead = null,Object? readAt = freezed,Object? tenantId = null,Object? createdAt = null,Object? details = freezed,}) {
  return _then(_AppNotification(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,notificationId: freezed == notificationId ? _self.notificationId : notificationId // ignore: cast_nullable_to_non_nullable
as String?,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,readAt: freezed == readAt ? _self.readAt : readAt // ignore: cast_nullable_to_non_nullable
as DateTime?,tenantId: null == tenantId ? _self.tenantId : tenantId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,details: freezed == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as NotificationDetails?,
  ));
}

/// Create a copy of AppNotification
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NotificationDetailsCopyWith<$Res>? get details {
    if (_self.details == null) {
    return null;
  }

  return $NotificationDetailsCopyWith<$Res>(_self.details!, (value) {
    return _then(_self.copyWith(details: value));
  });
}
}


/// @nodoc
mixin _$NotificationDetails {

 String get title; String get body;
/// Create a copy of NotificationDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NotificationDetailsCopyWith<NotificationDetails> get copyWith => _$NotificationDetailsCopyWithImpl<NotificationDetails>(this as NotificationDetails, _$identity);

  /// Serializes this NotificationDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NotificationDetails&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,body);

@override
String toString() {
  return 'NotificationDetails(title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class $NotificationDetailsCopyWith<$Res>  {
  factory $NotificationDetailsCopyWith(NotificationDetails value, $Res Function(NotificationDetails) _then) = _$NotificationDetailsCopyWithImpl;
@useResult
$Res call({
 String title, String body
});




}
/// @nodoc
class _$NotificationDetailsCopyWithImpl<$Res>
    implements $NotificationDetailsCopyWith<$Res> {
  _$NotificationDetailsCopyWithImpl(this._self, this._then);

  final NotificationDetails _self;
  final $Res Function(NotificationDetails) _then;

/// Create a copy of NotificationDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? body = null,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [NotificationDetails].
extension NotificationDetailsPatterns on NotificationDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NotificationDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NotificationDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NotificationDetails value)  $default,){
final _that = this;
switch (_that) {
case _NotificationDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NotificationDetails value)?  $default,){
final _that = this;
switch (_that) {
case _NotificationDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String body)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NotificationDetails() when $default != null:
return $default(_that.title,_that.body);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String body)  $default,) {final _that = this;
switch (_that) {
case _NotificationDetails():
return $default(_that.title,_that.body);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String body)?  $default,) {final _that = this;
switch (_that) {
case _NotificationDetails() when $default != null:
return $default(_that.title,_that.body);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _NotificationDetails implements NotificationDetails {
  const _NotificationDetails({required this.title, required this.body});
  factory _NotificationDetails.fromJson(Map<String, dynamic> json) => _$NotificationDetailsFromJson(json);

@override final  String title;
@override final  String body;

/// Create a copy of NotificationDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NotificationDetailsCopyWith<_NotificationDetails> get copyWith => __$NotificationDetailsCopyWithImpl<_NotificationDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$NotificationDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NotificationDetails&&(identical(other.title, title) || other.title == title)&&(identical(other.body, body) || other.body == body));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,body);

@override
String toString() {
  return 'NotificationDetails(title: $title, body: $body)';
}


}

/// @nodoc
abstract mixin class _$NotificationDetailsCopyWith<$Res> implements $NotificationDetailsCopyWith<$Res> {
  factory _$NotificationDetailsCopyWith(_NotificationDetails value, $Res Function(_NotificationDetails) _then) = __$NotificationDetailsCopyWithImpl;
@override @useResult
$Res call({
 String title, String body
});




}
/// @nodoc
class __$NotificationDetailsCopyWithImpl<$Res>
    implements _$NotificationDetailsCopyWith<$Res> {
  __$NotificationDetailsCopyWithImpl(this._self, this._then);

  final _NotificationDetails _self;
  final $Res Function(_NotificationDetails) _then;

/// Create a copy of NotificationDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? body = null,}) {
  return _then(_NotificationDetails(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,body: null == body ? _self.body : body // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
