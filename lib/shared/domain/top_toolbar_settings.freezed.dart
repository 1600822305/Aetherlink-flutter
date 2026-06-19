// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'top_toolbar_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TopToolbarComponentPosition {

 TopToolbarComponent get component; double get x; double get y;
/// Create a copy of TopToolbarComponentPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopToolbarComponentPositionCopyWith<TopToolbarComponentPosition> get copyWith => _$TopToolbarComponentPositionCopyWithImpl<TopToolbarComponentPosition>(this as TopToolbarComponentPosition, _$identity);

  /// Serializes this TopToolbarComponentPosition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopToolbarComponentPosition&&(identical(other.component, component) || other.component == component)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,component,x,y);

@override
String toString() {
  return 'TopToolbarComponentPosition(component: $component, x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class $TopToolbarComponentPositionCopyWith<$Res>  {
  factory $TopToolbarComponentPositionCopyWith(TopToolbarComponentPosition value, $Res Function(TopToolbarComponentPosition) _then) = _$TopToolbarComponentPositionCopyWithImpl;
@useResult
$Res call({
 TopToolbarComponent component, double x, double y
});




}
/// @nodoc
class _$TopToolbarComponentPositionCopyWithImpl<$Res>
    implements $TopToolbarComponentPositionCopyWith<$Res> {
  _$TopToolbarComponentPositionCopyWithImpl(this._self, this._then);

  final TopToolbarComponentPosition _self;
  final $Res Function(TopToolbarComponentPosition) _then;

/// Create a copy of TopToolbarComponentPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? component = null,Object? x = null,Object? y = null,}) {
  return _then(_self.copyWith(
component: null == component ? _self.component : component // ignore: cast_nullable_to_non_nullable
as TopToolbarComponent,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [TopToolbarComponentPosition].
extension TopToolbarComponentPositionPatterns on TopToolbarComponentPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopToolbarComponentPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopToolbarComponentPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopToolbarComponentPosition value)  $default,){
final _that = this;
switch (_that) {
case _TopToolbarComponentPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopToolbarComponentPosition value)?  $default,){
final _that = this;
switch (_that) {
case _TopToolbarComponentPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TopToolbarComponent component,  double x,  double y)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopToolbarComponentPosition() when $default != null:
return $default(_that.component,_that.x,_that.y);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TopToolbarComponent component,  double x,  double y)  $default,) {final _that = this;
switch (_that) {
case _TopToolbarComponentPosition():
return $default(_that.component,_that.x,_that.y);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TopToolbarComponent component,  double x,  double y)?  $default,) {final _that = this;
switch (_that) {
case _TopToolbarComponentPosition() when $default != null:
return $default(_that.component,_that.x,_that.y);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopToolbarComponentPosition implements TopToolbarComponentPosition {
  const _TopToolbarComponentPosition({required this.component, required this.x, required this.y});
  factory _TopToolbarComponentPosition.fromJson(Map<String, dynamic> json) => _$TopToolbarComponentPositionFromJson(json);

@override final  TopToolbarComponent component;
@override final  double x;
@override final  double y;

/// Create a copy of TopToolbarComponentPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopToolbarComponentPositionCopyWith<_TopToolbarComponentPosition> get copyWith => __$TopToolbarComponentPositionCopyWithImpl<_TopToolbarComponentPosition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopToolbarComponentPositionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopToolbarComponentPosition&&(identical(other.component, component) || other.component == component)&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,component,x,y);

@override
String toString() {
  return 'TopToolbarComponentPosition(component: $component, x: $x, y: $y)';
}


}

/// @nodoc
abstract mixin class _$TopToolbarComponentPositionCopyWith<$Res> implements $TopToolbarComponentPositionCopyWith<$Res> {
  factory _$TopToolbarComponentPositionCopyWith(_TopToolbarComponentPosition value, $Res Function(_TopToolbarComponentPosition) _then) = __$TopToolbarComponentPositionCopyWithImpl;
@override @useResult
$Res call({
 TopToolbarComponent component, double x, double y
});




}
/// @nodoc
class __$TopToolbarComponentPositionCopyWithImpl<$Res>
    implements _$TopToolbarComponentPositionCopyWith<$Res> {
  __$TopToolbarComponentPositionCopyWithImpl(this._self, this._then);

  final _TopToolbarComponentPosition _self;
  final $Res Function(_TopToolbarComponentPosition) _then;

/// Create a copy of TopToolbarComponentPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? component = null,Object? x = null,Object? y = null,}) {
  return _then(_TopToolbarComponentPosition(
component: null == component ? _self.component : component // ignore: cast_nullable_to_non_nullable
as TopToolbarComponent,x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$TopToolbarSettings {

 List<TopToolbarComponentPosition> get positions; ModelSelectorDisplayStyle get modelSelectorDisplayStyle;
/// Create a copy of TopToolbarSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopToolbarSettingsCopyWith<TopToolbarSettings> get copyWith => _$TopToolbarSettingsCopyWithImpl<TopToolbarSettings>(this as TopToolbarSettings, _$identity);

  /// Serializes this TopToolbarSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopToolbarSettings&&const DeepCollectionEquality().equals(other.positions, positions)&&(identical(other.modelSelectorDisplayStyle, modelSelectorDisplayStyle) || other.modelSelectorDisplayStyle == modelSelectorDisplayStyle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(positions),modelSelectorDisplayStyle);

@override
String toString() {
  return 'TopToolbarSettings(positions: $positions, modelSelectorDisplayStyle: $modelSelectorDisplayStyle)';
}


}

/// @nodoc
abstract mixin class $TopToolbarSettingsCopyWith<$Res>  {
  factory $TopToolbarSettingsCopyWith(TopToolbarSettings value, $Res Function(TopToolbarSettings) _then) = _$TopToolbarSettingsCopyWithImpl;
@useResult
$Res call({
 List<TopToolbarComponentPosition> positions, ModelSelectorDisplayStyle modelSelectorDisplayStyle
});




}
/// @nodoc
class _$TopToolbarSettingsCopyWithImpl<$Res>
    implements $TopToolbarSettingsCopyWith<$Res> {
  _$TopToolbarSettingsCopyWithImpl(this._self, this._then);

  final TopToolbarSettings _self;
  final $Res Function(TopToolbarSettings) _then;

/// Create a copy of TopToolbarSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? positions = null,Object? modelSelectorDisplayStyle = null,}) {
  return _then(_self.copyWith(
positions: null == positions ? _self.positions : positions // ignore: cast_nullable_to_non_nullable
as List<TopToolbarComponentPosition>,modelSelectorDisplayStyle: null == modelSelectorDisplayStyle ? _self.modelSelectorDisplayStyle : modelSelectorDisplayStyle // ignore: cast_nullable_to_non_nullable
as ModelSelectorDisplayStyle,
  ));
}

}


/// Adds pattern-matching-related methods to [TopToolbarSettings].
extension TopToolbarSettingsPatterns on TopToolbarSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopToolbarSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopToolbarSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopToolbarSettings value)  $default,){
final _that = this;
switch (_that) {
case _TopToolbarSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopToolbarSettings value)?  $default,){
final _that = this;
switch (_that) {
case _TopToolbarSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<TopToolbarComponentPosition> positions,  ModelSelectorDisplayStyle modelSelectorDisplayStyle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopToolbarSettings() when $default != null:
return $default(_that.positions,_that.modelSelectorDisplayStyle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<TopToolbarComponentPosition> positions,  ModelSelectorDisplayStyle modelSelectorDisplayStyle)  $default,) {final _that = this;
switch (_that) {
case _TopToolbarSettings():
return $default(_that.positions,_that.modelSelectorDisplayStyle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<TopToolbarComponentPosition> positions,  ModelSelectorDisplayStyle modelSelectorDisplayStyle)?  $default,) {final _that = this;
switch (_that) {
case _TopToolbarSettings() when $default != null:
return $default(_that.positions,_that.modelSelectorDisplayStyle);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopToolbarSettings implements TopToolbarSettings {
  const _TopToolbarSettings({final  List<TopToolbarComponentPosition> positions = const [], this.modelSelectorDisplayStyle = ModelSelectorDisplayStyle.icon}): _positions = positions;
  factory _TopToolbarSettings.fromJson(Map<String, dynamic> json) => _$TopToolbarSettingsFromJson(json);

 final  List<TopToolbarComponentPosition> _positions;
@override@JsonKey() List<TopToolbarComponentPosition> get positions {
  if (_positions is EqualUnmodifiableListView) return _positions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_positions);
}

@override@JsonKey() final  ModelSelectorDisplayStyle modelSelectorDisplayStyle;

/// Create a copy of TopToolbarSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopToolbarSettingsCopyWith<_TopToolbarSettings> get copyWith => __$TopToolbarSettingsCopyWithImpl<_TopToolbarSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopToolbarSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopToolbarSettings&&const DeepCollectionEquality().equals(other._positions, _positions)&&(identical(other.modelSelectorDisplayStyle, modelSelectorDisplayStyle) || other.modelSelectorDisplayStyle == modelSelectorDisplayStyle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_positions),modelSelectorDisplayStyle);

@override
String toString() {
  return 'TopToolbarSettings(positions: $positions, modelSelectorDisplayStyle: $modelSelectorDisplayStyle)';
}


}

/// @nodoc
abstract mixin class _$TopToolbarSettingsCopyWith<$Res> implements $TopToolbarSettingsCopyWith<$Res> {
  factory _$TopToolbarSettingsCopyWith(_TopToolbarSettings value, $Res Function(_TopToolbarSettings) _then) = __$TopToolbarSettingsCopyWithImpl;
@override @useResult
$Res call({
 List<TopToolbarComponentPosition> positions, ModelSelectorDisplayStyle modelSelectorDisplayStyle
});




}
/// @nodoc
class __$TopToolbarSettingsCopyWithImpl<$Res>
    implements _$TopToolbarSettingsCopyWith<$Res> {
  __$TopToolbarSettingsCopyWithImpl(this._self, this._then);

  final _TopToolbarSettings _self;
  final $Res Function(_TopToolbarSettings) _then;

/// Create a copy of TopToolbarSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? positions = null,Object? modelSelectorDisplayStyle = null,}) {
  return _then(_TopToolbarSettings(
positions: null == positions ? _self._positions : positions // ignore: cast_nullable_to_non_nullable
as List<TopToolbarComponentPosition>,modelSelectorDisplayStyle: null == modelSelectorDisplayStyle ? _self.modelSelectorDisplayStyle : modelSelectorDisplayStyle // ignore: cast_nullable_to_non_nullable
as ModelSelectorDisplayStyle,
  ));
}


}

// dart format on
