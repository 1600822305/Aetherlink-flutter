// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'theme_spec.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ThemeSpec {

 String get id; String get name; ThemeColors get colors; ThemeTypography get typography; ThemeShape get shape; ThemeDensity get density; int get schemaVersion;
/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemeSpecCopyWith<ThemeSpec> get copyWith => _$ThemeSpecCopyWithImpl<ThemeSpec>(this as ThemeSpec, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.colors, colors) || other.colors == colors)&&(identical(other.typography, typography) || other.typography == typography)&&(identical(other.shape, shape) || other.shape == shape)&&(identical(other.density, density) || other.density == density)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,colors,typography,shape,density,schemaVersion);

@override
String toString() {
  return 'ThemeSpec(id: $id, name: $name, colors: $colors, typography: $typography, shape: $shape, density: $density, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class $ThemeSpecCopyWith<$Res>  {
  factory $ThemeSpecCopyWith(ThemeSpec value, $Res Function(ThemeSpec) _then) = _$ThemeSpecCopyWithImpl;
@useResult
$Res call({
 String id, String name, ThemeColors colors, ThemeTypography typography, ThemeShape shape, ThemeDensity density, int schemaVersion
});


$ThemeColorsCopyWith<$Res> get colors;$ThemeTypographyCopyWith<$Res> get typography;$ThemeShapeCopyWith<$Res> get shape;

}
/// @nodoc
class _$ThemeSpecCopyWithImpl<$Res>
    implements $ThemeSpecCopyWith<$Res> {
  _$ThemeSpecCopyWithImpl(this._self, this._then);

  final ThemeSpec _self;
  final $Res Function(ThemeSpec) _then;

/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? colors = null,Object? typography = null,Object? shape = null,Object? density = null,Object? schemaVersion = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colors: null == colors ? _self.colors : colors // ignore: cast_nullable_to_non_nullable
as ThemeColors,typography: null == typography ? _self.typography : typography // ignore: cast_nullable_to_non_nullable
as ThemeTypography,shape: null == shape ? _self.shape : shape // ignore: cast_nullable_to_non_nullable
as ThemeShape,density: null == density ? _self.density : density // ignore: cast_nullable_to_non_nullable
as ThemeDensity,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemeColorsCopyWith<$Res> get colors {
  
  return $ThemeColorsCopyWith<$Res>(_self.colors, (value) {
    return _then(_self.copyWith(colors: value));
  });
}/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemeTypographyCopyWith<$Res> get typography {
  
  return $ThemeTypographyCopyWith<$Res>(_self.typography, (value) {
    return _then(_self.copyWith(typography: value));
  });
}/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemeShapeCopyWith<$Res> get shape {
  
  return $ThemeShapeCopyWith<$Res>(_self.shape, (value) {
    return _then(_self.copyWith(shape: value));
  });
}
}


/// Adds pattern-matching-related methods to [ThemeSpec].
extension ThemeSpecPatterns on ThemeSpec {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeSpec() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeSpec value)  $default,){
final _that = this;
switch (_that) {
case _ThemeSpec():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeSpec value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeSpec() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  ThemeColors colors,  ThemeTypography typography,  ThemeShape shape,  ThemeDensity density,  int schemaVersion)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeSpec() when $default != null:
return $default(_that.id,_that.name,_that.colors,_that.typography,_that.shape,_that.density,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  ThemeColors colors,  ThemeTypography typography,  ThemeShape shape,  ThemeDensity density,  int schemaVersion)  $default,) {final _that = this;
switch (_that) {
case _ThemeSpec():
return $default(_that.id,_that.name,_that.colors,_that.typography,_that.shape,_that.density,_that.schemaVersion);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  ThemeColors colors,  ThemeTypography typography,  ThemeShape shape,  ThemeDensity density,  int schemaVersion)?  $default,) {final _that = this;
switch (_that) {
case _ThemeSpec() when $default != null:
return $default(_that.id,_that.name,_that.colors,_that.typography,_that.shape,_that.density,_that.schemaVersion);case _:
  return null;

}
}

}

/// @nodoc


class _ThemeSpec implements ThemeSpec {
  const _ThemeSpec({required this.id, required this.name, required this.colors, required this.typography, required this.shape, required this.density, this.schemaVersion = kThemeSpecSchemaVersion});
  

@override final  String id;
@override final  String name;
@override final  ThemeColors colors;
@override final  ThemeTypography typography;
@override final  ThemeShape shape;
@override final  ThemeDensity density;
@override@JsonKey() final  int schemaVersion;

/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeSpecCopyWith<_ThemeSpec> get copyWith => __$ThemeSpecCopyWithImpl<_ThemeSpec>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeSpec&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.colors, colors) || other.colors == colors)&&(identical(other.typography, typography) || other.typography == typography)&&(identical(other.shape, shape) || other.shape == shape)&&(identical(other.density, density) || other.density == density)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,colors,typography,shape,density,schemaVersion);

@override
String toString() {
  return 'ThemeSpec(id: $id, name: $name, colors: $colors, typography: $typography, shape: $shape, density: $density, schemaVersion: $schemaVersion)';
}


}

/// @nodoc
abstract mixin class _$ThemeSpecCopyWith<$Res> implements $ThemeSpecCopyWith<$Res> {
  factory _$ThemeSpecCopyWith(_ThemeSpec value, $Res Function(_ThemeSpec) _then) = __$ThemeSpecCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, ThemeColors colors, ThemeTypography typography, ThemeShape shape, ThemeDensity density, int schemaVersion
});


@override $ThemeColorsCopyWith<$Res> get colors;@override $ThemeTypographyCopyWith<$Res> get typography;@override $ThemeShapeCopyWith<$Res> get shape;

}
/// @nodoc
class __$ThemeSpecCopyWithImpl<$Res>
    implements _$ThemeSpecCopyWith<$Res> {
  __$ThemeSpecCopyWithImpl(this._self, this._then);

  final _ThemeSpec _self;
  final $Res Function(_ThemeSpec) _then;

/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? colors = null,Object? typography = null,Object? shape = null,Object? density = null,Object? schemaVersion = null,}) {
  return _then(_ThemeSpec(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,colors: null == colors ? _self.colors : colors // ignore: cast_nullable_to_non_nullable
as ThemeColors,typography: null == typography ? _self.typography : typography // ignore: cast_nullable_to_non_nullable
as ThemeTypography,shape: null == shape ? _self.shape : shape // ignore: cast_nullable_to_non_nullable
as ThemeShape,density: null == density ? _self.density : density // ignore: cast_nullable_to_non_nullable
as ThemeDensity,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemeColorsCopyWith<$Res> get colors {
  
  return $ThemeColorsCopyWith<$Res>(_self.colors, (value) {
    return _then(_self.copyWith(colors: value));
  });
}/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemeTypographyCopyWith<$Res> get typography {
  
  return $ThemeTypographyCopyWith<$Res>(_self.typography, (value) {
    return _then(_self.copyWith(typography: value));
  });
}/// Create a copy of ThemeSpec
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThemeShapeCopyWith<$Res> get shape {
  
  return $ThemeShapeCopyWith<$Res>(_self.shape, (value) {
    return _then(_self.copyWith(shape: value));
  });
}
}

/// @nodoc
mixin _$ThemeColors {

 ColorRoleSet get light; ColorRoleSet get dark;
/// Create a copy of ThemeColors
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemeColorsCopyWith<ThemeColors> get copyWith => _$ThemeColorsCopyWithImpl<ThemeColors>(this as ThemeColors, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeColors&&(identical(other.light, light) || other.light == light)&&(identical(other.dark, dark) || other.dark == dark));
}


@override
int get hashCode => Object.hash(runtimeType,light,dark);

@override
String toString() {
  return 'ThemeColors(light: $light, dark: $dark)';
}


}

/// @nodoc
abstract mixin class $ThemeColorsCopyWith<$Res>  {
  factory $ThemeColorsCopyWith(ThemeColors value, $Res Function(ThemeColors) _then) = _$ThemeColorsCopyWithImpl;
@useResult
$Res call({
 ColorRoleSet light, ColorRoleSet dark
});


$ColorRoleSetCopyWith<$Res> get light;$ColorRoleSetCopyWith<$Res> get dark;

}
/// @nodoc
class _$ThemeColorsCopyWithImpl<$Res>
    implements $ThemeColorsCopyWith<$Res> {
  _$ThemeColorsCopyWithImpl(this._self, this._then);

  final ThemeColors _self;
  final $Res Function(ThemeColors) _then;

/// Create a copy of ThemeColors
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? light = null,Object? dark = null,}) {
  return _then(_self.copyWith(
light: null == light ? _self.light : light // ignore: cast_nullable_to_non_nullable
as ColorRoleSet,dark: null == dark ? _self.dark : dark // ignore: cast_nullable_to_non_nullable
as ColorRoleSet,
  ));
}
/// Create a copy of ThemeColors
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ColorRoleSetCopyWith<$Res> get light {
  
  return $ColorRoleSetCopyWith<$Res>(_self.light, (value) {
    return _then(_self.copyWith(light: value));
  });
}/// Create a copy of ThemeColors
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ColorRoleSetCopyWith<$Res> get dark {
  
  return $ColorRoleSetCopyWith<$Res>(_self.dark, (value) {
    return _then(_self.copyWith(dark: value));
  });
}
}


/// Adds pattern-matching-related methods to [ThemeColors].
extension ThemeColorsPatterns on ThemeColors {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeColors value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeColors() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeColors value)  $default,){
final _that = this;
switch (_that) {
case _ThemeColors():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeColors value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeColors() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ColorRoleSet light,  ColorRoleSet dark)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeColors() when $default != null:
return $default(_that.light,_that.dark);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ColorRoleSet light,  ColorRoleSet dark)  $default,) {final _that = this;
switch (_that) {
case _ThemeColors():
return $default(_that.light,_that.dark);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ColorRoleSet light,  ColorRoleSet dark)?  $default,) {final _that = this;
switch (_that) {
case _ThemeColors() when $default != null:
return $default(_that.light,_that.dark);case _:
  return null;

}
}

}

/// @nodoc


class _ThemeColors implements ThemeColors {
  const _ThemeColors({required this.light, required this.dark});
  

@override final  ColorRoleSet light;
@override final  ColorRoleSet dark;

/// Create a copy of ThemeColors
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeColorsCopyWith<_ThemeColors> get copyWith => __$ThemeColorsCopyWithImpl<_ThemeColors>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeColors&&(identical(other.light, light) || other.light == light)&&(identical(other.dark, dark) || other.dark == dark));
}


@override
int get hashCode => Object.hash(runtimeType,light,dark);

@override
String toString() {
  return 'ThemeColors(light: $light, dark: $dark)';
}


}

/// @nodoc
abstract mixin class _$ThemeColorsCopyWith<$Res> implements $ThemeColorsCopyWith<$Res> {
  factory _$ThemeColorsCopyWith(_ThemeColors value, $Res Function(_ThemeColors) _then) = __$ThemeColorsCopyWithImpl;
@override @useResult
$Res call({
 ColorRoleSet light, ColorRoleSet dark
});


@override $ColorRoleSetCopyWith<$Res> get light;@override $ColorRoleSetCopyWith<$Res> get dark;

}
/// @nodoc
class __$ThemeColorsCopyWithImpl<$Res>
    implements _$ThemeColorsCopyWith<$Res> {
  __$ThemeColorsCopyWithImpl(this._self, this._then);

  final _ThemeColors _self;
  final $Res Function(_ThemeColors) _then;

/// Create a copy of ThemeColors
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? light = null,Object? dark = null,}) {
  return _then(_ThemeColors(
light: null == light ? _self.light : light // ignore: cast_nullable_to_non_nullable
as ColorRoleSet,dark: null == dark ? _self.dark : dark // ignore: cast_nullable_to_non_nullable
as ColorRoleSet,
  ));
}

/// Create a copy of ThemeColors
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ColorRoleSetCopyWith<$Res> get light {
  
  return $ColorRoleSetCopyWith<$Res>(_self.light, (value) {
    return _then(_self.copyWith(light: value));
  });
}/// Create a copy of ThemeColors
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ColorRoleSetCopyWith<$Res> get dark {
  
  return $ColorRoleSetCopyWith<$Res>(_self.dark, (value) {
    return _then(_self.copyWith(dark: value));
  });
}
}

/// @nodoc
mixin _$ColorRoleSet {

 int get primary; int get secondary; int get background; int get surface; int get textPrimary; int get textSecondary; int get bubbleUser; int get bubbleAi; int? get accent;
/// Create a copy of ColorRoleSet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ColorRoleSetCopyWith<ColorRoleSet> get copyWith => _$ColorRoleSetCopyWithImpl<ColorRoleSet>(this as ColorRoleSet, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ColorRoleSet&&(identical(other.primary, primary) || other.primary == primary)&&(identical(other.secondary, secondary) || other.secondary == secondary)&&(identical(other.background, background) || other.background == background)&&(identical(other.surface, surface) || other.surface == surface)&&(identical(other.textPrimary, textPrimary) || other.textPrimary == textPrimary)&&(identical(other.textSecondary, textSecondary) || other.textSecondary == textSecondary)&&(identical(other.bubbleUser, bubbleUser) || other.bubbleUser == bubbleUser)&&(identical(other.bubbleAi, bubbleAi) || other.bubbleAi == bubbleAi)&&(identical(other.accent, accent) || other.accent == accent));
}


@override
int get hashCode => Object.hash(runtimeType,primary,secondary,background,surface,textPrimary,textSecondary,bubbleUser,bubbleAi,accent);

@override
String toString() {
  return 'ColorRoleSet(primary: $primary, secondary: $secondary, background: $background, surface: $surface, textPrimary: $textPrimary, textSecondary: $textSecondary, bubbleUser: $bubbleUser, bubbleAi: $bubbleAi, accent: $accent)';
}


}

/// @nodoc
abstract mixin class $ColorRoleSetCopyWith<$Res>  {
  factory $ColorRoleSetCopyWith(ColorRoleSet value, $Res Function(ColorRoleSet) _then) = _$ColorRoleSetCopyWithImpl;
@useResult
$Res call({
 int primary, int secondary, int background, int surface, int textPrimary, int textSecondary, int bubbleUser, int bubbleAi, int? accent
});




}
/// @nodoc
class _$ColorRoleSetCopyWithImpl<$Res>
    implements $ColorRoleSetCopyWith<$Res> {
  _$ColorRoleSetCopyWithImpl(this._self, this._then);

  final ColorRoleSet _self;
  final $Res Function(ColorRoleSet) _then;

/// Create a copy of ColorRoleSet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? primary = null,Object? secondary = null,Object? background = null,Object? surface = null,Object? textPrimary = null,Object? textSecondary = null,Object? bubbleUser = null,Object? bubbleAi = null,Object? accent = freezed,}) {
  return _then(_self.copyWith(
primary: null == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as int,secondary: null == secondary ? _self.secondary : secondary // ignore: cast_nullable_to_non_nullable
as int,background: null == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as int,surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as int,textPrimary: null == textPrimary ? _self.textPrimary : textPrimary // ignore: cast_nullable_to_non_nullable
as int,textSecondary: null == textSecondary ? _self.textSecondary : textSecondary // ignore: cast_nullable_to_non_nullable
as int,bubbleUser: null == bubbleUser ? _self.bubbleUser : bubbleUser // ignore: cast_nullable_to_non_nullable
as int,bubbleAi: null == bubbleAi ? _self.bubbleAi : bubbleAi // ignore: cast_nullable_to_non_nullable
as int,accent: freezed == accent ? _self.accent : accent // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ColorRoleSet].
extension ColorRoleSetPatterns on ColorRoleSet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ColorRoleSet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ColorRoleSet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ColorRoleSet value)  $default,){
final _that = this;
switch (_that) {
case _ColorRoleSet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ColorRoleSet value)?  $default,){
final _that = this;
switch (_that) {
case _ColorRoleSet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int primary,  int secondary,  int background,  int surface,  int textPrimary,  int textSecondary,  int bubbleUser,  int bubbleAi,  int? accent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ColorRoleSet() when $default != null:
return $default(_that.primary,_that.secondary,_that.background,_that.surface,_that.textPrimary,_that.textSecondary,_that.bubbleUser,_that.bubbleAi,_that.accent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int primary,  int secondary,  int background,  int surface,  int textPrimary,  int textSecondary,  int bubbleUser,  int bubbleAi,  int? accent)  $default,) {final _that = this;
switch (_that) {
case _ColorRoleSet():
return $default(_that.primary,_that.secondary,_that.background,_that.surface,_that.textPrimary,_that.textSecondary,_that.bubbleUser,_that.bubbleAi,_that.accent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int primary,  int secondary,  int background,  int surface,  int textPrimary,  int textSecondary,  int bubbleUser,  int bubbleAi,  int? accent)?  $default,) {final _that = this;
switch (_that) {
case _ColorRoleSet() when $default != null:
return $default(_that.primary,_that.secondary,_that.background,_that.surface,_that.textPrimary,_that.textSecondary,_that.bubbleUser,_that.bubbleAi,_that.accent);case _:
  return null;

}
}

}

/// @nodoc


class _ColorRoleSet implements ColorRoleSet {
  const _ColorRoleSet({required this.primary, required this.secondary, required this.background, required this.surface, required this.textPrimary, required this.textSecondary, required this.bubbleUser, required this.bubbleAi, this.accent});
  

@override final  int primary;
@override final  int secondary;
@override final  int background;
@override final  int surface;
@override final  int textPrimary;
@override final  int textSecondary;
@override final  int bubbleUser;
@override final  int bubbleAi;
@override final  int? accent;

/// Create a copy of ColorRoleSet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ColorRoleSetCopyWith<_ColorRoleSet> get copyWith => __$ColorRoleSetCopyWithImpl<_ColorRoleSet>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ColorRoleSet&&(identical(other.primary, primary) || other.primary == primary)&&(identical(other.secondary, secondary) || other.secondary == secondary)&&(identical(other.background, background) || other.background == background)&&(identical(other.surface, surface) || other.surface == surface)&&(identical(other.textPrimary, textPrimary) || other.textPrimary == textPrimary)&&(identical(other.textSecondary, textSecondary) || other.textSecondary == textSecondary)&&(identical(other.bubbleUser, bubbleUser) || other.bubbleUser == bubbleUser)&&(identical(other.bubbleAi, bubbleAi) || other.bubbleAi == bubbleAi)&&(identical(other.accent, accent) || other.accent == accent));
}


@override
int get hashCode => Object.hash(runtimeType,primary,secondary,background,surface,textPrimary,textSecondary,bubbleUser,bubbleAi,accent);

@override
String toString() {
  return 'ColorRoleSet(primary: $primary, secondary: $secondary, background: $background, surface: $surface, textPrimary: $textPrimary, textSecondary: $textSecondary, bubbleUser: $bubbleUser, bubbleAi: $bubbleAi, accent: $accent)';
}


}

/// @nodoc
abstract mixin class _$ColorRoleSetCopyWith<$Res> implements $ColorRoleSetCopyWith<$Res> {
  factory _$ColorRoleSetCopyWith(_ColorRoleSet value, $Res Function(_ColorRoleSet) _then) = __$ColorRoleSetCopyWithImpl;
@override @useResult
$Res call({
 int primary, int secondary, int background, int surface, int textPrimary, int textSecondary, int bubbleUser, int bubbleAi, int? accent
});




}
/// @nodoc
class __$ColorRoleSetCopyWithImpl<$Res>
    implements _$ColorRoleSetCopyWith<$Res> {
  __$ColorRoleSetCopyWithImpl(this._self, this._then);

  final _ColorRoleSet _self;
  final $Res Function(_ColorRoleSet) _then;

/// Create a copy of ColorRoleSet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? primary = null,Object? secondary = null,Object? background = null,Object? surface = null,Object? textPrimary = null,Object? textSecondary = null,Object? bubbleUser = null,Object? bubbleAi = null,Object? accent = freezed,}) {
  return _then(_ColorRoleSet(
primary: null == primary ? _self.primary : primary // ignore: cast_nullable_to_non_nullable
as int,secondary: null == secondary ? _self.secondary : secondary // ignore: cast_nullable_to_non_nullable
as int,background: null == background ? _self.background : background // ignore: cast_nullable_to_non_nullable
as int,surface: null == surface ? _self.surface : surface // ignore: cast_nullable_to_non_nullable
as int,textPrimary: null == textPrimary ? _self.textPrimary : textPrimary // ignore: cast_nullable_to_non_nullable
as int,textSecondary: null == textSecondary ? _self.textSecondary : textSecondary // ignore: cast_nullable_to_non_nullable
as int,bubbleUser: null == bubbleUser ? _self.bubbleUser : bubbleUser // ignore: cast_nullable_to_non_nullable
as int,bubbleAi: null == bubbleAi ? _self.bubbleAi : bubbleAi // ignore: cast_nullable_to_non_nullable
as int,accent: freezed == accent ? _self.accent : accent // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$ThemeTypography {

 String? get fontFamily; double get textScale;
/// Create a copy of ThemeTypography
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemeTypographyCopyWith<ThemeTypography> get copyWith => _$ThemeTypographyCopyWithImpl<ThemeTypography>(this as ThemeTypography, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeTypography&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.textScale, textScale) || other.textScale == textScale));
}


@override
int get hashCode => Object.hash(runtimeType,fontFamily,textScale);

@override
String toString() {
  return 'ThemeTypography(fontFamily: $fontFamily, textScale: $textScale)';
}


}

/// @nodoc
abstract mixin class $ThemeTypographyCopyWith<$Res>  {
  factory $ThemeTypographyCopyWith(ThemeTypography value, $Res Function(ThemeTypography) _then) = _$ThemeTypographyCopyWithImpl;
@useResult
$Res call({
 String? fontFamily, double textScale
});




}
/// @nodoc
class _$ThemeTypographyCopyWithImpl<$Res>
    implements $ThemeTypographyCopyWith<$Res> {
  _$ThemeTypographyCopyWithImpl(this._self, this._then);

  final ThemeTypography _self;
  final $Res Function(ThemeTypography) _then;

/// Create a copy of ThemeTypography
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fontFamily = freezed,Object? textScale = null,}) {
  return _then(_self.copyWith(
fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ThemeTypography].
extension ThemeTypographyPatterns on ThemeTypography {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeTypography value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeTypography() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeTypography value)  $default,){
final _that = this;
switch (_that) {
case _ThemeTypography():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeTypography value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeTypography() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? fontFamily,  double textScale)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeTypography() when $default != null:
return $default(_that.fontFamily,_that.textScale);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? fontFamily,  double textScale)  $default,) {final _that = this;
switch (_that) {
case _ThemeTypography():
return $default(_that.fontFamily,_that.textScale);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? fontFamily,  double textScale)?  $default,) {final _that = this;
switch (_that) {
case _ThemeTypography() when $default != null:
return $default(_that.fontFamily,_that.textScale);case _:
  return null;

}
}

}

/// @nodoc


class _ThemeTypography implements ThemeTypography {
  const _ThemeTypography({this.fontFamily, this.textScale = 1.0});
  

@override final  String? fontFamily;
@override@JsonKey() final  double textScale;

/// Create a copy of ThemeTypography
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeTypographyCopyWith<_ThemeTypography> get copyWith => __$ThemeTypographyCopyWithImpl<_ThemeTypography>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeTypography&&(identical(other.fontFamily, fontFamily) || other.fontFamily == fontFamily)&&(identical(other.textScale, textScale) || other.textScale == textScale));
}


@override
int get hashCode => Object.hash(runtimeType,fontFamily,textScale);

@override
String toString() {
  return 'ThemeTypography(fontFamily: $fontFamily, textScale: $textScale)';
}


}

/// @nodoc
abstract mixin class _$ThemeTypographyCopyWith<$Res> implements $ThemeTypographyCopyWith<$Res> {
  factory _$ThemeTypographyCopyWith(_ThemeTypography value, $Res Function(_ThemeTypography) _then) = __$ThemeTypographyCopyWithImpl;
@override @useResult
$Res call({
 String? fontFamily, double textScale
});




}
/// @nodoc
class __$ThemeTypographyCopyWithImpl<$Res>
    implements _$ThemeTypographyCopyWith<$Res> {
  __$ThemeTypographyCopyWithImpl(this._self, this._then);

  final _ThemeTypography _self;
  final $Res Function(_ThemeTypography) _then;

/// Create a copy of ThemeTypography
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fontFamily = freezed,Object? textScale = null,}) {
  return _then(_ThemeTypography(
fontFamily: freezed == fontFamily ? _self.fontFamily : fontFamily // ignore: cast_nullable_to_non_nullable
as String?,textScale: null == textScale ? _self.textScale : textScale // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$ThemeShape {

 double get borderRadius;
/// Create a copy of ThemeShape
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThemeShapeCopyWith<ThemeShape> get copyWith => _$ThemeShapeCopyWithImpl<ThemeShape>(this as ThemeShape, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThemeShape&&(identical(other.borderRadius, borderRadius) || other.borderRadius == borderRadius));
}


@override
int get hashCode => Object.hash(runtimeType,borderRadius);

@override
String toString() {
  return 'ThemeShape(borderRadius: $borderRadius)';
}


}

/// @nodoc
abstract mixin class $ThemeShapeCopyWith<$Res>  {
  factory $ThemeShapeCopyWith(ThemeShape value, $Res Function(ThemeShape) _then) = _$ThemeShapeCopyWithImpl;
@useResult
$Res call({
 double borderRadius
});




}
/// @nodoc
class _$ThemeShapeCopyWithImpl<$Res>
    implements $ThemeShapeCopyWith<$Res> {
  _$ThemeShapeCopyWithImpl(this._self, this._then);

  final ThemeShape _self;
  final $Res Function(ThemeShape) _then;

/// Create a copy of ThemeShape
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? borderRadius = null,}) {
  return _then(_self.copyWith(
borderRadius: null == borderRadius ? _self.borderRadius : borderRadius // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [ThemeShape].
extension ThemeShapePatterns on ThemeShape {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThemeShape value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThemeShape() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThemeShape value)  $default,){
final _that = this;
switch (_that) {
case _ThemeShape():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThemeShape value)?  $default,){
final _that = this;
switch (_that) {
case _ThemeShape() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double borderRadius)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThemeShape() when $default != null:
return $default(_that.borderRadius);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double borderRadius)  $default,) {final _that = this;
switch (_that) {
case _ThemeShape():
return $default(_that.borderRadius);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double borderRadius)?  $default,) {final _that = this;
switch (_that) {
case _ThemeShape() when $default != null:
return $default(_that.borderRadius);case _:
  return null;

}
}

}

/// @nodoc


class _ThemeShape implements ThemeShape {
  const _ThemeShape({this.borderRadius = 8.0});
  

@override@JsonKey() final  double borderRadius;

/// Create a copy of ThemeShape
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThemeShapeCopyWith<_ThemeShape> get copyWith => __$ThemeShapeCopyWithImpl<_ThemeShape>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThemeShape&&(identical(other.borderRadius, borderRadius) || other.borderRadius == borderRadius));
}


@override
int get hashCode => Object.hash(runtimeType,borderRadius);

@override
String toString() {
  return 'ThemeShape(borderRadius: $borderRadius)';
}


}

/// @nodoc
abstract mixin class _$ThemeShapeCopyWith<$Res> implements $ThemeShapeCopyWith<$Res> {
  factory _$ThemeShapeCopyWith(_ThemeShape value, $Res Function(_ThemeShape) _then) = __$ThemeShapeCopyWithImpl;
@override @useResult
$Res call({
 double borderRadius
});




}
/// @nodoc
class __$ThemeShapeCopyWithImpl<$Res>
    implements _$ThemeShapeCopyWith<$Res> {
  __$ThemeShapeCopyWithImpl(this._self, this._then);

  final _ThemeShape _self;
  final $Res Function(_ThemeShape) _then;

/// Create a copy of ThemeShape
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? borderRadius = null,}) {
  return _then(_ThemeShape(
borderRadius: null == borderRadius ? _self.borderRadius : borderRadius // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
