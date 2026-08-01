// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_interaction_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppInteractionState {

 bool get isHovered; bool get isFocused; bool get isPressed; bool get isDisabled;
/// Create a copy of AppInteractionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppInteractionStateCopyWith<AppInteractionState> get copyWith => _$AppInteractionStateCopyWithImpl<AppInteractionState>(this as AppInteractionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppInteractionState&&(identical(other.isHovered, isHovered) || other.isHovered == isHovered)&&(identical(other.isFocused, isFocused) || other.isFocused == isFocused)&&(identical(other.isPressed, isPressed) || other.isPressed == isPressed)&&(identical(other.isDisabled, isDisabled) || other.isDisabled == isDisabled));
}


@override
int get hashCode => Object.hash(runtimeType,isHovered,isFocused,isPressed,isDisabled);

@override
String toString() {
  return 'AppInteractionState(isHovered: $isHovered, isFocused: $isFocused, isPressed: $isPressed, isDisabled: $isDisabled)';
}


}

/// @nodoc
abstract mixin class $AppInteractionStateCopyWith<$Res>  {
  factory $AppInteractionStateCopyWith(AppInteractionState value, $Res Function(AppInteractionState) _then) = _$AppInteractionStateCopyWithImpl;
@useResult
$Res call({
 bool isHovered, bool isFocused, bool isPressed, bool isDisabled
});




}
/// @nodoc
class _$AppInteractionStateCopyWithImpl<$Res>
    implements $AppInteractionStateCopyWith<$Res> {
  _$AppInteractionStateCopyWithImpl(this._self, this._then);

  final AppInteractionState _self;
  final $Res Function(AppInteractionState) _then;

/// Create a copy of AppInteractionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? isHovered = null,Object? isFocused = null,Object? isPressed = null,Object? isDisabled = null,}) {
  return _then(_self.copyWith(
isHovered: null == isHovered ? _self.isHovered : isHovered // ignore: cast_nullable_to_non_nullable
as bool,isFocused: null == isFocused ? _self.isFocused : isFocused // ignore: cast_nullable_to_non_nullable
as bool,isPressed: null == isPressed ? _self.isPressed : isPressed // ignore: cast_nullable_to_non_nullable
as bool,isDisabled: null == isDisabled ? _self.isDisabled : isDisabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppInteractionState].
extension AppInteractionStatePatterns on AppInteractionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppInteractionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppInteractionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppInteractionState value)  $default,){
final _that = this;
switch (_that) {
case _AppInteractionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppInteractionState value)?  $default,){
final _that = this;
switch (_that) {
case _AppInteractionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool isHovered,  bool isFocused,  bool isPressed,  bool isDisabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppInteractionState() when $default != null:
return $default(_that.isHovered,_that.isFocused,_that.isPressed,_that.isDisabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool isHovered,  bool isFocused,  bool isPressed,  bool isDisabled)  $default,) {final _that = this;
switch (_that) {
case _AppInteractionState():
return $default(_that.isHovered,_that.isFocused,_that.isPressed,_that.isDisabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool isHovered,  bool isFocused,  bool isPressed,  bool isDisabled)?  $default,) {final _that = this;
switch (_that) {
case _AppInteractionState() when $default != null:
return $default(_that.isHovered,_that.isFocused,_that.isPressed,_that.isDisabled);case _:
  return null;

}
}

}

/// @nodoc


class _AppInteractionState implements AppInteractionState {
  const _AppInteractionState({this.isHovered = false, this.isFocused = false, this.isPressed = false, this.isDisabled = false});
  

@override@JsonKey() final  bool isHovered;
@override@JsonKey() final  bool isFocused;
@override@JsonKey() final  bool isPressed;
@override@JsonKey() final  bool isDisabled;

/// Create a copy of AppInteractionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppInteractionStateCopyWith<_AppInteractionState> get copyWith => __$AppInteractionStateCopyWithImpl<_AppInteractionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppInteractionState&&(identical(other.isHovered, isHovered) || other.isHovered == isHovered)&&(identical(other.isFocused, isFocused) || other.isFocused == isFocused)&&(identical(other.isPressed, isPressed) || other.isPressed == isPressed)&&(identical(other.isDisabled, isDisabled) || other.isDisabled == isDisabled));
}


@override
int get hashCode => Object.hash(runtimeType,isHovered,isFocused,isPressed,isDisabled);

@override
String toString() {
  return 'AppInteractionState(isHovered: $isHovered, isFocused: $isFocused, isPressed: $isPressed, isDisabled: $isDisabled)';
}


}

/// @nodoc
abstract mixin class _$AppInteractionStateCopyWith<$Res> implements $AppInteractionStateCopyWith<$Res> {
  factory _$AppInteractionStateCopyWith(_AppInteractionState value, $Res Function(_AppInteractionState) _then) = __$AppInteractionStateCopyWithImpl;
@override @useResult
$Res call({
 bool isHovered, bool isFocused, bool isPressed, bool isDisabled
});




}
/// @nodoc
class __$AppInteractionStateCopyWithImpl<$Res>
    implements _$AppInteractionStateCopyWith<$Res> {
  __$AppInteractionStateCopyWithImpl(this._self, this._then);

  final _AppInteractionState _self;
  final $Res Function(_AppInteractionState) _then;

/// Create a copy of AppInteractionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? isHovered = null,Object? isFocused = null,Object? isPressed = null,Object? isDisabled = null,}) {
  return _then(_AppInteractionState(
isHovered: null == isHovered ? _self.isHovered : isHovered // ignore: cast_nullable_to_non_nullable
as bool,isFocused: null == isFocused ? _self.isFocused : isFocused // ignore: cast_nullable_to_non_nullable
as bool,isPressed: null == isPressed ? _self.isPressed : isPressed // ignore: cast_nullable_to_non_nullable
as bool,isDisabled: null == isDisabled ? _self.isDisabled : isDisabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
