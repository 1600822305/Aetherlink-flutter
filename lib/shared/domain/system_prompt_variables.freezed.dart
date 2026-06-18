// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'system_prompt_variables.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SystemPromptVariables {

 bool get enableTimeVariable; bool get enableLocationVariable; String get customLocation; bool get enableOSVariable;
/// Create a copy of SystemPromptVariables
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemPromptVariablesCopyWith<SystemPromptVariables> get copyWith => _$SystemPromptVariablesCopyWithImpl<SystemPromptVariables>(this as SystemPromptVariables, _$identity);

  /// Serializes this SystemPromptVariables to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemPromptVariables&&(identical(other.enableTimeVariable, enableTimeVariable) || other.enableTimeVariable == enableTimeVariable)&&(identical(other.enableLocationVariable, enableLocationVariable) || other.enableLocationVariable == enableLocationVariable)&&(identical(other.customLocation, customLocation) || other.customLocation == customLocation)&&(identical(other.enableOSVariable, enableOSVariable) || other.enableOSVariable == enableOSVariable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enableTimeVariable,enableLocationVariable,customLocation,enableOSVariable);

@override
String toString() {
  return 'SystemPromptVariables(enableTimeVariable: $enableTimeVariable, enableLocationVariable: $enableLocationVariable, customLocation: $customLocation, enableOSVariable: $enableOSVariable)';
}


}

/// @nodoc
abstract mixin class $SystemPromptVariablesCopyWith<$Res>  {
  factory $SystemPromptVariablesCopyWith(SystemPromptVariables value, $Res Function(SystemPromptVariables) _then) = _$SystemPromptVariablesCopyWithImpl;
@useResult
$Res call({
 bool enableTimeVariable, bool enableLocationVariable, String customLocation, bool enableOSVariable
});




}
/// @nodoc
class _$SystemPromptVariablesCopyWithImpl<$Res>
    implements $SystemPromptVariablesCopyWith<$Res> {
  _$SystemPromptVariablesCopyWithImpl(this._self, this._then);

  final SystemPromptVariables _self;
  final $Res Function(SystemPromptVariables) _then;

/// Create a copy of SystemPromptVariables
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enableTimeVariable = null,Object? enableLocationVariable = null,Object? customLocation = null,Object? enableOSVariable = null,}) {
  return _then(_self.copyWith(
enableTimeVariable: null == enableTimeVariable ? _self.enableTimeVariable : enableTimeVariable // ignore: cast_nullable_to_non_nullable
as bool,enableLocationVariable: null == enableLocationVariable ? _self.enableLocationVariable : enableLocationVariable // ignore: cast_nullable_to_non_nullable
as bool,customLocation: null == customLocation ? _self.customLocation : customLocation // ignore: cast_nullable_to_non_nullable
as String,enableOSVariable: null == enableOSVariable ? _self.enableOSVariable : enableOSVariable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SystemPromptVariables].
extension SystemPromptVariablesPatterns on SystemPromptVariables {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemPromptVariables value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemPromptVariables() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemPromptVariables value)  $default,){
final _that = this;
switch (_that) {
case _SystemPromptVariables():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemPromptVariables value)?  $default,){
final _that = this;
switch (_that) {
case _SystemPromptVariables() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enableTimeVariable,  bool enableLocationVariable,  String customLocation,  bool enableOSVariable)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemPromptVariables() when $default != null:
return $default(_that.enableTimeVariable,_that.enableLocationVariable,_that.customLocation,_that.enableOSVariable);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enableTimeVariable,  bool enableLocationVariable,  String customLocation,  bool enableOSVariable)  $default,) {final _that = this;
switch (_that) {
case _SystemPromptVariables():
return $default(_that.enableTimeVariable,_that.enableLocationVariable,_that.customLocation,_that.enableOSVariable);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enableTimeVariable,  bool enableLocationVariable,  String customLocation,  bool enableOSVariable)?  $default,) {final _that = this;
switch (_that) {
case _SystemPromptVariables() when $default != null:
return $default(_that.enableTimeVariable,_that.enableLocationVariable,_that.customLocation,_that.enableOSVariable);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SystemPromptVariables implements SystemPromptVariables {
  const _SystemPromptVariables({this.enableTimeVariable = false, this.enableLocationVariable = false, this.customLocation = '', this.enableOSVariable = false});
  factory _SystemPromptVariables.fromJson(Map<String, dynamic> json) => _$SystemPromptVariablesFromJson(json);

@override@JsonKey() final  bool enableTimeVariable;
@override@JsonKey() final  bool enableLocationVariable;
@override@JsonKey() final  String customLocation;
@override@JsonKey() final  bool enableOSVariable;

/// Create a copy of SystemPromptVariables
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemPromptVariablesCopyWith<_SystemPromptVariables> get copyWith => __$SystemPromptVariablesCopyWithImpl<_SystemPromptVariables>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SystemPromptVariablesToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemPromptVariables&&(identical(other.enableTimeVariable, enableTimeVariable) || other.enableTimeVariable == enableTimeVariable)&&(identical(other.enableLocationVariable, enableLocationVariable) || other.enableLocationVariable == enableLocationVariable)&&(identical(other.customLocation, customLocation) || other.customLocation == customLocation)&&(identical(other.enableOSVariable, enableOSVariable) || other.enableOSVariable == enableOSVariable));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enableTimeVariable,enableLocationVariable,customLocation,enableOSVariable);

@override
String toString() {
  return 'SystemPromptVariables(enableTimeVariable: $enableTimeVariable, enableLocationVariable: $enableLocationVariable, customLocation: $customLocation, enableOSVariable: $enableOSVariable)';
}


}

/// @nodoc
abstract mixin class _$SystemPromptVariablesCopyWith<$Res> implements $SystemPromptVariablesCopyWith<$Res> {
  factory _$SystemPromptVariablesCopyWith(_SystemPromptVariables value, $Res Function(_SystemPromptVariables) _then) = __$SystemPromptVariablesCopyWithImpl;
@override @useResult
$Res call({
 bool enableTimeVariable, bool enableLocationVariable, String customLocation, bool enableOSVariable
});




}
/// @nodoc
class __$SystemPromptVariablesCopyWithImpl<$Res>
    implements _$SystemPromptVariablesCopyWith<$Res> {
  __$SystemPromptVariablesCopyWithImpl(this._self, this._then);

  final _SystemPromptVariables _self;
  final $Res Function(_SystemPromptVariables) _then;

/// Create a copy of SystemPromptVariables
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enableTimeVariable = null,Object? enableLocationVariable = null,Object? customLocation = null,Object? enableOSVariable = null,}) {
  return _then(_SystemPromptVariables(
enableTimeVariable: null == enableTimeVariable ? _self.enableTimeVariable : enableTimeVariable // ignore: cast_nullable_to_non_nullable
as bool,enableLocationVariable: null == enableLocationVariable ? _self.enableLocationVariable : enableLocationVariable // ignore: cast_nullable_to_non_nullable
as bool,customLocation: null == customLocation ? _self.customLocation : customLocation // ignore: cast_nullable_to_non_nullable
as String,enableOSVariable: null == enableOSVariable ? _self.enableOSVariable : enableOSVariable // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
