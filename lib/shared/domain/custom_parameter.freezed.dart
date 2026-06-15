// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'custom_parameter.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CustomParameter {

 String get name; Object? get value; CustomParameterType get type;
/// Create a copy of CustomParameter
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomParameterCopyWith<CustomParameter> get copyWith => _$CustomParameterCopyWithImpl<CustomParameter>(this as CustomParameter, _$identity);

  /// Serializes this CustomParameter to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomParameter&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.value, value)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(value),type);

@override
String toString() {
  return 'CustomParameter(name: $name, value: $value, type: $type)';
}


}

/// @nodoc
abstract mixin class $CustomParameterCopyWith<$Res>  {
  factory $CustomParameterCopyWith(CustomParameter value, $Res Function(CustomParameter) _then) = _$CustomParameterCopyWithImpl;
@useResult
$Res call({
 String name, Object? value, CustomParameterType type
});




}
/// @nodoc
class _$CustomParameterCopyWithImpl<$Res>
    implements $CustomParameterCopyWith<$Res> {
  _$CustomParameterCopyWithImpl(this._self, this._then);

  final CustomParameter _self;
  final $Res Function(CustomParameter) _then;

/// Create a copy of CustomParameter
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? value = freezed,Object? type = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CustomParameterType,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomParameter].
extension CustomParameterPatterns on CustomParameter {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomParameter value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomParameter() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomParameter value)  $default,){
final _that = this;
switch (_that) {
case _CustomParameter():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomParameter value)?  $default,){
final _that = this;
switch (_that) {
case _CustomParameter() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  Object? value,  CustomParameterType type)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomParameter() when $default != null:
return $default(_that.name,_that.value,_that.type);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  Object? value,  CustomParameterType type)  $default,) {final _that = this;
switch (_that) {
case _CustomParameter():
return $default(_that.name,_that.value,_that.type);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  Object? value,  CustomParameterType type)?  $default,) {final _that = this;
switch (_that) {
case _CustomParameter() when $default != null:
return $default(_that.name,_that.value,_that.type);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CustomParameter implements CustomParameter {
  const _CustomParameter({required this.name, required this.value, required this.type});
  factory _CustomParameter.fromJson(Map<String, dynamic> json) => _$CustomParameterFromJson(json);

@override final  String name;
@override final  Object? value;
@override final  CustomParameterType type;

/// Create a copy of CustomParameter
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomParameterCopyWith<_CustomParameter> get copyWith => __$CustomParameterCopyWithImpl<_CustomParameter>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CustomParameterToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomParameter&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.value, value)&&(identical(other.type, type) || other.type == type));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(value),type);

@override
String toString() {
  return 'CustomParameter(name: $name, value: $value, type: $type)';
}


}

/// @nodoc
abstract mixin class _$CustomParameterCopyWith<$Res> implements $CustomParameterCopyWith<$Res> {
  factory _$CustomParameterCopyWith(_CustomParameter value, $Res Function(_CustomParameter) _then) = __$CustomParameterCopyWithImpl;
@override @useResult
$Res call({
 String name, Object? value, CustomParameterType type
});




}
/// @nodoc
class __$CustomParameterCopyWithImpl<$Res>
    implements _$CustomParameterCopyWith<$Res> {
  __$CustomParameterCopyWithImpl(this._self, this._then);

  final _CustomParameter _self;
  final $Res Function(_CustomParameter) _then;

/// Create a copy of CustomParameter
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? value = freezed,Object? type = null,}) {
  return _then(_CustomParameter(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as CustomParameterType,
  ));
}


}

// dart format on
