// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'assistant_regex.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AssistantRegex {

 String get id; String get name; String get pattern; String get replacement; List<AssistantRegexScope> get scopes; bool get visualOnly; bool get enabled;
/// Create a copy of AssistantRegex
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistantRegexCopyWith<AssistantRegex> get copyWith => _$AssistantRegexCopyWithImpl<AssistantRegex>(this as AssistantRegex, _$identity);

  /// Serializes this AssistantRegex to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistantRegex&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.pattern, pattern) || other.pattern == pattern)&&(identical(other.replacement, replacement) || other.replacement == replacement)&&const DeepCollectionEquality().equals(other.scopes, scopes)&&(identical(other.visualOnly, visualOnly) || other.visualOnly == visualOnly)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,pattern,replacement,const DeepCollectionEquality().hash(scopes),visualOnly,enabled);

@override
String toString() {
  return 'AssistantRegex(id: $id, name: $name, pattern: $pattern, replacement: $replacement, scopes: $scopes, visualOnly: $visualOnly, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class $AssistantRegexCopyWith<$Res>  {
  factory $AssistantRegexCopyWith(AssistantRegex value, $Res Function(AssistantRegex) _then) = _$AssistantRegexCopyWithImpl;
@useResult
$Res call({
 String id, String name, String pattern, String replacement, List<AssistantRegexScope> scopes, bool visualOnly, bool enabled
});




}
/// @nodoc
class _$AssistantRegexCopyWithImpl<$Res>
    implements $AssistantRegexCopyWith<$Res> {
  _$AssistantRegexCopyWithImpl(this._self, this._then);

  final AssistantRegex _self;
  final $Res Function(AssistantRegex) _then;

/// Create a copy of AssistantRegex
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? pattern = null,Object? replacement = null,Object? scopes = null,Object? visualOnly = null,Object? enabled = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,pattern: null == pattern ? _self.pattern : pattern // ignore: cast_nullable_to_non_nullable
as String,replacement: null == replacement ? _self.replacement : replacement // ignore: cast_nullable_to_non_nullable
as String,scopes: null == scopes ? _self.scopes : scopes // ignore: cast_nullable_to_non_nullable
as List<AssistantRegexScope>,visualOnly: null == visualOnly ? _self.visualOnly : visualOnly // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AssistantRegex].
extension AssistantRegexPatterns on AssistantRegex {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AssistantRegex value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AssistantRegex() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AssistantRegex value)  $default,){
final _that = this;
switch (_that) {
case _AssistantRegex():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AssistantRegex value)?  $default,){
final _that = this;
switch (_that) {
case _AssistantRegex() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String pattern,  String replacement,  List<AssistantRegexScope> scopes,  bool visualOnly,  bool enabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AssistantRegex() when $default != null:
return $default(_that.id,_that.name,_that.pattern,_that.replacement,_that.scopes,_that.visualOnly,_that.enabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String pattern,  String replacement,  List<AssistantRegexScope> scopes,  bool visualOnly,  bool enabled)  $default,) {final _that = this;
switch (_that) {
case _AssistantRegex():
return $default(_that.id,_that.name,_that.pattern,_that.replacement,_that.scopes,_that.visualOnly,_that.enabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String pattern,  String replacement,  List<AssistantRegexScope> scopes,  bool visualOnly,  bool enabled)?  $default,) {final _that = this;
switch (_that) {
case _AssistantRegex() when $default != null:
return $default(_that.id,_that.name,_that.pattern,_that.replacement,_that.scopes,_that.visualOnly,_that.enabled);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AssistantRegex implements AssistantRegex {
  const _AssistantRegex({required this.id, required this.name, required this.pattern, required this.replacement, final  List<AssistantRegexScope> scopes = const <AssistantRegexScope>[], required this.visualOnly, required this.enabled}): _scopes = scopes;
  factory _AssistantRegex.fromJson(Map<String, dynamic> json) => _$AssistantRegexFromJson(json);

@override final  String id;
@override final  String name;
@override final  String pattern;
@override final  String replacement;
 final  List<AssistantRegexScope> _scopes;
@override@JsonKey() List<AssistantRegexScope> get scopes {
  if (_scopes is EqualUnmodifiableListView) return _scopes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_scopes);
}

@override final  bool visualOnly;
@override final  bool enabled;

/// Create a copy of AssistantRegex
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AssistantRegexCopyWith<_AssistantRegex> get copyWith => __$AssistantRegexCopyWithImpl<_AssistantRegex>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AssistantRegexToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AssistantRegex&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.pattern, pattern) || other.pattern == pattern)&&(identical(other.replacement, replacement) || other.replacement == replacement)&&const DeepCollectionEquality().equals(other._scopes, _scopes)&&(identical(other.visualOnly, visualOnly) || other.visualOnly == visualOnly)&&(identical(other.enabled, enabled) || other.enabled == enabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,pattern,replacement,const DeepCollectionEquality().hash(_scopes),visualOnly,enabled);

@override
String toString() {
  return 'AssistantRegex(id: $id, name: $name, pattern: $pattern, replacement: $replacement, scopes: $scopes, visualOnly: $visualOnly, enabled: $enabled)';
}


}

/// @nodoc
abstract mixin class _$AssistantRegexCopyWith<$Res> implements $AssistantRegexCopyWith<$Res> {
  factory _$AssistantRegexCopyWith(_AssistantRegex value, $Res Function(_AssistantRegex) _then) = __$AssistantRegexCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String pattern, String replacement, List<AssistantRegexScope> scopes, bool visualOnly, bool enabled
});




}
/// @nodoc
class __$AssistantRegexCopyWithImpl<$Res>
    implements _$AssistantRegexCopyWith<$Res> {
  __$AssistantRegexCopyWithImpl(this._self, this._then);

  final _AssistantRegex _self;
  final $Res Function(_AssistantRegex) _then;

/// Create a copy of AssistantRegex
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? pattern = null,Object? replacement = null,Object? scopes = null,Object? visualOnly = null,Object? enabled = null,}) {
  return _then(_AssistantRegex(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,pattern: null == pattern ? _self.pattern : pattern // ignore: cast_nullable_to_non_nullable
as String,replacement: null == replacement ? _self.replacement : replacement // ignore: cast_nullable_to_non_nullable
as String,scopes: null == scopes ? _self._scopes : scopes // ignore: cast_nullable_to_non_nullable
as List<AssistantRegexScope>,visualOnly: null == visualOnly ? _self.visualOnly : visualOnly // ignore: cast_nullable_to_non_nullable
as bool,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
