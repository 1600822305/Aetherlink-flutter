// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'input_box_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$InputBoxSettings {

 InputBoxStyle get style; List<InputBoxButtonId> get leftButtons; List<InputBoxButtonId> get rightButtons;
/// Create a copy of InputBoxSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InputBoxSettingsCopyWith<InputBoxSettings> get copyWith => _$InputBoxSettingsCopyWithImpl<InputBoxSettings>(this as InputBoxSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InputBoxSettings&&(identical(other.style, style) || other.style == style)&&const DeepCollectionEquality().equals(other.leftButtons, leftButtons)&&const DeepCollectionEquality().equals(other.rightButtons, rightButtons));
}


@override
int get hashCode => Object.hash(runtimeType,style,const DeepCollectionEquality().hash(leftButtons),const DeepCollectionEquality().hash(rightButtons));

@override
String toString() {
  return 'InputBoxSettings(style: $style, leftButtons: $leftButtons, rightButtons: $rightButtons)';
}


}

/// @nodoc
abstract mixin class $InputBoxSettingsCopyWith<$Res>  {
  factory $InputBoxSettingsCopyWith(InputBoxSettings value, $Res Function(InputBoxSettings) _then) = _$InputBoxSettingsCopyWithImpl;
@useResult
$Res call({
 InputBoxStyle style, List<InputBoxButtonId> leftButtons, List<InputBoxButtonId> rightButtons
});




}
/// @nodoc
class _$InputBoxSettingsCopyWithImpl<$Res>
    implements $InputBoxSettingsCopyWith<$Res> {
  _$InputBoxSettingsCopyWithImpl(this._self, this._then);

  final InputBoxSettings _self;
  final $Res Function(InputBoxSettings) _then;

/// Create a copy of InputBoxSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? style = null,Object? leftButtons = null,Object? rightButtons = null,}) {
  return _then(_self.copyWith(
style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as InputBoxStyle,leftButtons: null == leftButtons ? _self.leftButtons : leftButtons // ignore: cast_nullable_to_non_nullable
as List<InputBoxButtonId>,rightButtons: null == rightButtons ? _self.rightButtons : rightButtons // ignore: cast_nullable_to_non_nullable
as List<InputBoxButtonId>,
  ));
}

}


/// Adds pattern-matching-related methods to [InputBoxSettings].
extension InputBoxSettingsPatterns on InputBoxSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InputBoxSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InputBoxSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InputBoxSettings value)  $default,){
final _that = this;
switch (_that) {
case _InputBoxSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InputBoxSettings value)?  $default,){
final _that = this;
switch (_that) {
case _InputBoxSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( InputBoxStyle style,  List<InputBoxButtonId> leftButtons,  List<InputBoxButtonId> rightButtons)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InputBoxSettings() when $default != null:
return $default(_that.style,_that.leftButtons,_that.rightButtons);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( InputBoxStyle style,  List<InputBoxButtonId> leftButtons,  List<InputBoxButtonId> rightButtons)  $default,) {final _that = this;
switch (_that) {
case _InputBoxSettings():
return $default(_that.style,_that.leftButtons,_that.rightButtons);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( InputBoxStyle style,  List<InputBoxButtonId> leftButtons,  List<InputBoxButtonId> rightButtons)?  $default,) {final _that = this;
switch (_that) {
case _InputBoxSettings() when $default != null:
return $default(_that.style,_that.leftButtons,_that.rightButtons);case _:
  return null;

}
}

}

/// @nodoc


class _InputBoxSettings implements InputBoxSettings {
  const _InputBoxSettings({this.style = InputBoxStyle.defaultStyle, final  List<InputBoxButtonId> leftButtons = const [InputBoxButtonId.tools, InputBoxButtonId.clear, InputBoxButtonId.search], final  List<InputBoxButtonId> rightButtons = const [InputBoxButtonId.upload, InputBoxButtonId.voice, InputBoxButtonId.send]}): _leftButtons = leftButtons,_rightButtons = rightButtons;
  

@override@JsonKey() final  InputBoxStyle style;
 final  List<InputBoxButtonId> _leftButtons;
@override@JsonKey() List<InputBoxButtonId> get leftButtons {
  if (_leftButtons is EqualUnmodifiableListView) return _leftButtons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_leftButtons);
}

 final  List<InputBoxButtonId> _rightButtons;
@override@JsonKey() List<InputBoxButtonId> get rightButtons {
  if (_rightButtons is EqualUnmodifiableListView) return _rightButtons;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_rightButtons);
}


/// Create a copy of InputBoxSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InputBoxSettingsCopyWith<_InputBoxSettings> get copyWith => __$InputBoxSettingsCopyWithImpl<_InputBoxSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InputBoxSettings&&(identical(other.style, style) || other.style == style)&&const DeepCollectionEquality().equals(other._leftButtons, _leftButtons)&&const DeepCollectionEquality().equals(other._rightButtons, _rightButtons));
}


@override
int get hashCode => Object.hash(runtimeType,style,const DeepCollectionEquality().hash(_leftButtons),const DeepCollectionEquality().hash(_rightButtons));

@override
String toString() {
  return 'InputBoxSettings(style: $style, leftButtons: $leftButtons, rightButtons: $rightButtons)';
}


}

/// @nodoc
abstract mixin class _$InputBoxSettingsCopyWith<$Res> implements $InputBoxSettingsCopyWith<$Res> {
  factory _$InputBoxSettingsCopyWith(_InputBoxSettings value, $Res Function(_InputBoxSettings) _then) = __$InputBoxSettingsCopyWithImpl;
@override @useResult
$Res call({
 InputBoxStyle style, List<InputBoxButtonId> leftButtons, List<InputBoxButtonId> rightButtons
});




}
/// @nodoc
class __$InputBoxSettingsCopyWithImpl<$Res>
    implements _$InputBoxSettingsCopyWith<$Res> {
  __$InputBoxSettingsCopyWithImpl(this._self, this._then);

  final _InputBoxSettings _self;
  final $Res Function(_InputBoxSettings) _then;

/// Create a copy of InputBoxSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? style = null,Object? leftButtons = null,Object? rightButtons = null,}) {
  return _then(_InputBoxSettings(
style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as InputBoxStyle,leftButtons: null == leftButtons ? _self._leftButtons : leftButtons // ignore: cast_nullable_to_non_nullable
as List<InputBoxButtonId>,rightButtons: null == rightButtons ? _self._rightButtons : rightButtons // ignore: cast_nullable_to_non_nullable
as List<InputBoxButtonId>,
  ));
}


}

// dart format on
