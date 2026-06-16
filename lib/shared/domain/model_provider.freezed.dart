// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelProvider {

 String get id; String get name; String get avatar; String get color; bool get isEnabled; List<Model> get models; String? get apiKey; String? get baseUrl; String? get providerType; bool? get isSystem; Map<String, String>? get extraHeaders; Map<String, dynamic>? get extraBody;
/// Create a copy of ModelProvider
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelProviderCopyWith<ModelProvider> get copyWith => _$ModelProviderCopyWithImpl<ModelProvider>(this as ModelProvider, _$identity);

  /// Serializes this ModelProvider to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ModelProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.color, color) || other.color == color)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&const DeepCollectionEquality().equals(other.models, models)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.providerType, providerType) || other.providerType == providerType)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&const DeepCollectionEquality().equals(other.extraHeaders, extraHeaders)&&const DeepCollectionEquality().equals(other.extraBody, extraBody));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,avatar,color,isEnabled,const DeepCollectionEquality().hash(models),apiKey,baseUrl,providerType,isSystem,const DeepCollectionEquality().hash(extraHeaders),const DeepCollectionEquality().hash(extraBody));

@override
String toString() {
  return 'ModelProvider(id: $id, name: $name, avatar: $avatar, color: $color, isEnabled: $isEnabled, models: $models, apiKey: $apiKey, baseUrl: $baseUrl, providerType: $providerType, isSystem: $isSystem, extraHeaders: $extraHeaders, extraBody: $extraBody)';
}


}

/// @nodoc
abstract mixin class $ModelProviderCopyWith<$Res>  {
  factory $ModelProviderCopyWith(ModelProvider value, $Res Function(ModelProvider) _then) = _$ModelProviderCopyWithImpl;
@useResult
$Res call({
 String id, String name, String avatar, String color, bool isEnabled, List<Model> models, String? apiKey, String? baseUrl, String? providerType, bool? isSystem, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody
});




}
/// @nodoc
class _$ModelProviderCopyWithImpl<$Res>
    implements $ModelProviderCopyWith<$Res> {
  _$ModelProviderCopyWithImpl(this._self, this._then);

  final ModelProvider _self;
  final $Res Function(ModelProvider) _then;

/// Create a copy of ModelProvider
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? avatar = null,Object? color = null,Object? isEnabled = null,Object? models = null,Object? apiKey = freezed,Object? baseUrl = freezed,Object? providerType = freezed,Object? isSystem = freezed,Object? extraHeaders = freezed,Object? extraBody = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,models: null == models ? _self.models : models // ignore: cast_nullable_to_non_nullable
as List<Model>,apiKey: freezed == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String?,baseUrl: freezed == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String?,providerType: freezed == providerType ? _self.providerType : providerType // ignore: cast_nullable_to_non_nullable
as String?,isSystem: freezed == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool?,extraHeaders: freezed == extraHeaders ? _self.extraHeaders : extraHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,extraBody: freezed == extraBody ? _self.extraBody : extraBody // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ModelProvider].
extension ModelProviderPatterns on ModelProvider {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ModelProvider value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ModelProvider() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ModelProvider value)  $default,){
final _that = this;
switch (_that) {
case _ModelProvider():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ModelProvider value)?  $default,){
final _that = this;
switch (_that) {
case _ModelProvider() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String avatar,  String color,  bool isEnabled,  List<Model> models,  String? apiKey,  String? baseUrl,  String? providerType,  bool? isSystem,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ModelProvider() when $default != null:
return $default(_that.id,_that.name,_that.avatar,_that.color,_that.isEnabled,_that.models,_that.apiKey,_that.baseUrl,_that.providerType,_that.isSystem,_that.extraHeaders,_that.extraBody);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String avatar,  String color,  bool isEnabled,  List<Model> models,  String? apiKey,  String? baseUrl,  String? providerType,  bool? isSystem,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)  $default,) {final _that = this;
switch (_that) {
case _ModelProvider():
return $default(_that.id,_that.name,_that.avatar,_that.color,_that.isEnabled,_that.models,_that.apiKey,_that.baseUrl,_that.providerType,_that.isSystem,_that.extraHeaders,_that.extraBody);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String avatar,  String color,  bool isEnabled,  List<Model> models,  String? apiKey,  String? baseUrl,  String? providerType,  bool? isSystem,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody)?  $default,) {final _that = this;
switch (_that) {
case _ModelProvider() when $default != null:
return $default(_that.id,_that.name,_that.avatar,_that.color,_that.isEnabled,_that.models,_that.apiKey,_that.baseUrl,_that.providerType,_that.isSystem,_that.extraHeaders,_that.extraBody);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ModelProvider implements ModelProvider {
  const _ModelProvider({required this.id, required this.name, required this.avatar, required this.color, this.isEnabled = false, final  List<Model> models = const <Model>[], this.apiKey, this.baseUrl, this.providerType, this.isSystem, final  Map<String, String>? extraHeaders, final  Map<String, dynamic>? extraBody}): _models = models,_extraHeaders = extraHeaders,_extraBody = extraBody;
  factory _ModelProvider.fromJson(Map<String, dynamic> json) => _$ModelProviderFromJson(json);

@override final  String id;
@override final  String name;
@override final  String avatar;
@override final  String color;
@override@JsonKey() final  bool isEnabled;
 final  List<Model> _models;
@override@JsonKey() List<Model> get models {
  if (_models is EqualUnmodifiableListView) return _models;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_models);
}

@override final  String? apiKey;
@override final  String? baseUrl;
@override final  String? providerType;
@override final  bool? isSystem;
 final  Map<String, String>? _extraHeaders;
@override Map<String, String>? get extraHeaders {
  final value = _extraHeaders;
  if (value == null) return null;
  if (_extraHeaders is EqualUnmodifiableMapView) return _extraHeaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _extraBody;
@override Map<String, dynamic>? get extraBody {
  final value = _extraBody;
  if (value == null) return null;
  if (_extraBody is EqualUnmodifiableMapView) return _extraBody;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of ModelProvider
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelProviderCopyWith<_ModelProvider> get copyWith => __$ModelProviderCopyWithImpl<_ModelProvider>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelProviderToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ModelProvider&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.color, color) || other.color == color)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled)&&const DeepCollectionEquality().equals(other._models, _models)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.providerType, providerType) || other.providerType == providerType)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&const DeepCollectionEquality().equals(other._extraHeaders, _extraHeaders)&&const DeepCollectionEquality().equals(other._extraBody, _extraBody));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,avatar,color,isEnabled,const DeepCollectionEquality().hash(_models),apiKey,baseUrl,providerType,isSystem,const DeepCollectionEquality().hash(_extraHeaders),const DeepCollectionEquality().hash(_extraBody));

@override
String toString() {
  return 'ModelProvider(id: $id, name: $name, avatar: $avatar, color: $color, isEnabled: $isEnabled, models: $models, apiKey: $apiKey, baseUrl: $baseUrl, providerType: $providerType, isSystem: $isSystem, extraHeaders: $extraHeaders, extraBody: $extraBody)';
}


}

/// @nodoc
abstract mixin class _$ModelProviderCopyWith<$Res> implements $ModelProviderCopyWith<$Res> {
  factory _$ModelProviderCopyWith(_ModelProvider value, $Res Function(_ModelProvider) _then) = __$ModelProviderCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String avatar, String color, bool isEnabled, List<Model> models, String? apiKey, String? baseUrl, String? providerType, bool? isSystem, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody
});




}
/// @nodoc
class __$ModelProviderCopyWithImpl<$Res>
    implements _$ModelProviderCopyWith<$Res> {
  __$ModelProviderCopyWithImpl(this._self, this._then);

  final _ModelProvider _self;
  final $Res Function(_ModelProvider) _then;

/// Create a copy of ModelProvider
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? avatar = null,Object? color = null,Object? isEnabled = null,Object? models = null,Object? apiKey = freezed,Object? baseUrl = freezed,Object? providerType = freezed,Object? isSystem = freezed,Object? extraHeaders = freezed,Object? extraBody = freezed,}) {
  return _then(_ModelProvider(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,models: null == models ? _self._models : models // ignore: cast_nullable_to_non_nullable
as List<Model>,apiKey: freezed == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String?,baseUrl: freezed == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String?,providerType: freezed == providerType ? _self.providerType : providerType // ignore: cast_nullable_to_non_nullable
as String?,isSystem: freezed == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool?,extraHeaders: freezed == extraHeaders ? _self._extraHeaders : extraHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,extraBody: freezed == extraBody ? _self._extraBody : extraBody // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
