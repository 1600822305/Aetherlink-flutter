// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'thinking_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ThinkingSettings {

 ThinkingDisplayStyle get displayStyle; bool get thoughtAutoCollapse; bool get thinkingToolInline;
/// Create a copy of ThinkingSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThinkingSettingsCopyWith<ThinkingSettings> get copyWith => _$ThinkingSettingsCopyWithImpl<ThinkingSettings>(this as ThinkingSettings, _$identity);

  /// Serializes this ThinkingSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThinkingSettings&&(identical(other.displayStyle, displayStyle) || other.displayStyle == displayStyle)&&(identical(other.thoughtAutoCollapse, thoughtAutoCollapse) || other.thoughtAutoCollapse == thoughtAutoCollapse)&&(identical(other.thinkingToolInline, thinkingToolInline) || other.thinkingToolInline == thinkingToolInline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,displayStyle,thoughtAutoCollapse,thinkingToolInline);

@override
String toString() {
  return 'ThinkingSettings(displayStyle: $displayStyle, thoughtAutoCollapse: $thoughtAutoCollapse, thinkingToolInline: $thinkingToolInline)';
}


}

/// @nodoc
abstract mixin class $ThinkingSettingsCopyWith<$Res>  {
  factory $ThinkingSettingsCopyWith(ThinkingSettings value, $Res Function(ThinkingSettings) _then) = _$ThinkingSettingsCopyWithImpl;
@useResult
$Res call({
 ThinkingDisplayStyle displayStyle, bool thoughtAutoCollapse, bool thinkingToolInline
});




}
/// @nodoc
class _$ThinkingSettingsCopyWithImpl<$Res>
    implements $ThinkingSettingsCopyWith<$Res> {
  _$ThinkingSettingsCopyWithImpl(this._self, this._then);

  final ThinkingSettings _self;
  final $Res Function(ThinkingSettings) _then;

/// Create a copy of ThinkingSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? displayStyle = null,Object? thoughtAutoCollapse = null,Object? thinkingToolInline = null,}) {
  return _then(_self.copyWith(
displayStyle: null == displayStyle ? _self.displayStyle : displayStyle // ignore: cast_nullable_to_non_nullable
as ThinkingDisplayStyle,thoughtAutoCollapse: null == thoughtAutoCollapse ? _self.thoughtAutoCollapse : thoughtAutoCollapse // ignore: cast_nullable_to_non_nullable
as bool,thinkingToolInline: null == thinkingToolInline ? _self.thinkingToolInline : thinkingToolInline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ThinkingSettings].
extension ThinkingSettingsPatterns on ThinkingSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThinkingSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThinkingSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThinkingSettings value)  $default,){
final _that = this;
switch (_that) {
case _ThinkingSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThinkingSettings value)?  $default,){
final _that = this;
switch (_that) {
case _ThinkingSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ThinkingDisplayStyle displayStyle,  bool thoughtAutoCollapse,  bool thinkingToolInline)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThinkingSettings() when $default != null:
return $default(_that.displayStyle,_that.thoughtAutoCollapse,_that.thinkingToolInline);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ThinkingDisplayStyle displayStyle,  bool thoughtAutoCollapse,  bool thinkingToolInline)  $default,) {final _that = this;
switch (_that) {
case _ThinkingSettings():
return $default(_that.displayStyle,_that.thoughtAutoCollapse,_that.thinkingToolInline);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ThinkingDisplayStyle displayStyle,  bool thoughtAutoCollapse,  bool thinkingToolInline)?  $default,) {final _that = this;
switch (_that) {
case _ThinkingSettings() when $default != null:
return $default(_that.displayStyle,_that.thoughtAutoCollapse,_that.thinkingToolInline);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ThinkingSettings implements ThinkingSettings {
  const _ThinkingSettings({this.displayStyle = ThinkingDisplayStyle.compact, this.thoughtAutoCollapse = true, this.thinkingToolInline = true});
  factory _ThinkingSettings.fromJson(Map<String, dynamic> json) => _$ThinkingSettingsFromJson(json);

@override@JsonKey() final  ThinkingDisplayStyle displayStyle;
@override@JsonKey() final  bool thoughtAutoCollapse;
@override@JsonKey() final  bool thinkingToolInline;

/// Create a copy of ThinkingSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThinkingSettingsCopyWith<_ThinkingSettings> get copyWith => __$ThinkingSettingsCopyWithImpl<_ThinkingSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ThinkingSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThinkingSettings&&(identical(other.displayStyle, displayStyle) || other.displayStyle == displayStyle)&&(identical(other.thoughtAutoCollapse, thoughtAutoCollapse) || other.thoughtAutoCollapse == thoughtAutoCollapse)&&(identical(other.thinkingToolInline, thinkingToolInline) || other.thinkingToolInline == thinkingToolInline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,displayStyle,thoughtAutoCollapse,thinkingToolInline);

@override
String toString() {
  return 'ThinkingSettings(displayStyle: $displayStyle, thoughtAutoCollapse: $thoughtAutoCollapse, thinkingToolInline: $thinkingToolInline)';
}


}

/// @nodoc
abstract mixin class _$ThinkingSettingsCopyWith<$Res> implements $ThinkingSettingsCopyWith<$Res> {
  factory _$ThinkingSettingsCopyWith(_ThinkingSettings value, $Res Function(_ThinkingSettings) _then) = __$ThinkingSettingsCopyWithImpl;
@override @useResult
$Res call({
 ThinkingDisplayStyle displayStyle, bool thoughtAutoCollapse, bool thinkingToolInline
});




}
/// @nodoc
class __$ThinkingSettingsCopyWithImpl<$Res>
    implements _$ThinkingSettingsCopyWith<$Res> {
  __$ThinkingSettingsCopyWithImpl(this._self, this._then);

  final _ThinkingSettings _self;
  final $Res Function(_ThinkingSettings) _then;

/// Create a copy of ThinkingSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? displayStyle = null,Object? thoughtAutoCollapse = null,Object? thinkingToolInline = null,}) {
  return _then(_ThinkingSettings(
displayStyle: null == displayStyle ? _self.displayStyle : displayStyle // ignore: cast_nullable_to_non_nullable
as ThinkingDisplayStyle,thoughtAutoCollapse: null == thoughtAutoCollapse ? _self.thoughtAutoCollapse : thoughtAutoCollapse // ignore: cast_nullable_to_non_nullable
as bool,thinkingToolInline: null == thinkingToolInline ? _self.thinkingToolInline : thinkingToolInline // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
