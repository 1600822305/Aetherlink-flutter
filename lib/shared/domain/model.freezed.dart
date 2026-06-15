// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Model {

 String get id; String get name; String get provider; String? get description; String? get providerType; String? get apiKey; String? get baseUrl; int? get maxTokens; double? get temperature; bool? get enabled; bool? get isDefault; String? get iconUrl; String? get presetModelId; String? get group; ModelCapabilities? get capabilities; bool? get multimodal; bool? get imageGeneration; bool? get videoGeneration; List<ModelType>? get modelTypes; String? get apiVersion; Map<String, String>? get extraHeaders; Map<String, dynamic>? get extraBody; Map<String, String>? get providerExtraHeaders; Map<String, dynamic>? get providerExtraBody;
/// Create a copy of Model
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ModelCopyWith<Model> get copyWith => _$ModelCopyWithImpl<Model>(this as Model, _$identity);

  /// Serializes this Model to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Model&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.description, description) || other.description == description)&&(identical(other.providerType, providerType) || other.providerType == providerType)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.presetModelId, presetModelId) || other.presetModelId == presetModelId)&&(identical(other.group, group) || other.group == group)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities)&&(identical(other.multimodal, multimodal) || other.multimodal == multimodal)&&(identical(other.imageGeneration, imageGeneration) || other.imageGeneration == imageGeneration)&&(identical(other.videoGeneration, videoGeneration) || other.videoGeneration == videoGeneration)&&const DeepCollectionEquality().equals(other.modelTypes, modelTypes)&&(identical(other.apiVersion, apiVersion) || other.apiVersion == apiVersion)&&const DeepCollectionEquality().equals(other.extraHeaders, extraHeaders)&&const DeepCollectionEquality().equals(other.extraBody, extraBody)&&const DeepCollectionEquality().equals(other.providerExtraHeaders, providerExtraHeaders)&&const DeepCollectionEquality().equals(other.providerExtraBody, providerExtraBody));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,provider,description,providerType,apiKey,baseUrl,maxTokens,temperature,enabled,isDefault,iconUrl,presetModelId,group,capabilities,multimodal,imageGeneration,videoGeneration,const DeepCollectionEquality().hash(modelTypes),apiVersion,const DeepCollectionEquality().hash(extraHeaders),const DeepCollectionEquality().hash(extraBody),const DeepCollectionEquality().hash(providerExtraHeaders),const DeepCollectionEquality().hash(providerExtraBody)]);

@override
String toString() {
  return 'Model(id: $id, name: $name, provider: $provider, description: $description, providerType: $providerType, apiKey: $apiKey, baseUrl: $baseUrl, maxTokens: $maxTokens, temperature: $temperature, enabled: $enabled, isDefault: $isDefault, iconUrl: $iconUrl, presetModelId: $presetModelId, group: $group, capabilities: $capabilities, multimodal: $multimodal, imageGeneration: $imageGeneration, videoGeneration: $videoGeneration, modelTypes: $modelTypes, apiVersion: $apiVersion, extraHeaders: $extraHeaders, extraBody: $extraBody, providerExtraHeaders: $providerExtraHeaders, providerExtraBody: $providerExtraBody)';
}


}

/// @nodoc
abstract mixin class $ModelCopyWith<$Res>  {
  factory $ModelCopyWith(Model value, $Res Function(Model) _then) = _$ModelCopyWithImpl;
@useResult
$Res call({
 String id, String name, String provider, String? description, String? providerType, String? apiKey, String? baseUrl, int? maxTokens, double? temperature, bool? enabled, bool? isDefault, String? iconUrl, String? presetModelId, String? group, ModelCapabilities? capabilities, bool? multimodal, bool? imageGeneration, bool? videoGeneration, List<ModelType>? modelTypes, String? apiVersion, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody, Map<String, String>? providerExtraHeaders, Map<String, dynamic>? providerExtraBody
});


$ModelCapabilitiesCopyWith<$Res>? get capabilities;

}
/// @nodoc
class _$ModelCopyWithImpl<$Res>
    implements $ModelCopyWith<$Res> {
  _$ModelCopyWithImpl(this._self, this._then);

  final Model _self;
  final $Res Function(Model) _then;

/// Create a copy of Model
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? provider = null,Object? description = freezed,Object? providerType = freezed,Object? apiKey = freezed,Object? baseUrl = freezed,Object? maxTokens = freezed,Object? temperature = freezed,Object? enabled = freezed,Object? isDefault = freezed,Object? iconUrl = freezed,Object? presetModelId = freezed,Object? group = freezed,Object? capabilities = freezed,Object? multimodal = freezed,Object? imageGeneration = freezed,Object? videoGeneration = freezed,Object? modelTypes = freezed,Object? apiVersion = freezed,Object? extraHeaders = freezed,Object? extraBody = freezed,Object? providerExtraHeaders = freezed,Object? providerExtraBody = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,providerType: freezed == providerType ? _self.providerType : providerType // ignore: cast_nullable_to_non_nullable
as String?,apiKey: freezed == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String?,baseUrl: freezed == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String?,maxTokens: freezed == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,enabled: freezed == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,presetModelId: freezed == presetModelId ? _self.presetModelId : presetModelId // ignore: cast_nullable_to_non_nullable
as String?,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,capabilities: freezed == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as ModelCapabilities?,multimodal: freezed == multimodal ? _self.multimodal : multimodal // ignore: cast_nullable_to_non_nullable
as bool?,imageGeneration: freezed == imageGeneration ? _self.imageGeneration : imageGeneration // ignore: cast_nullable_to_non_nullable
as bool?,videoGeneration: freezed == videoGeneration ? _self.videoGeneration : videoGeneration // ignore: cast_nullable_to_non_nullable
as bool?,modelTypes: freezed == modelTypes ? _self.modelTypes : modelTypes // ignore: cast_nullable_to_non_nullable
as List<ModelType>?,apiVersion: freezed == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String?,extraHeaders: freezed == extraHeaders ? _self.extraHeaders : extraHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,extraBody: freezed == extraBody ? _self.extraBody : extraBody // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,providerExtraHeaders: freezed == providerExtraHeaders ? _self.providerExtraHeaders : providerExtraHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,providerExtraBody: freezed == providerExtraBody ? _self.providerExtraBody : providerExtraBody // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}
/// Create a copy of Model
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelCapabilitiesCopyWith<$Res>? get capabilities {
    if (_self.capabilities == null) {
    return null;
  }

  return $ModelCapabilitiesCopyWith<$Res>(_self.capabilities!, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}


/// Adds pattern-matching-related methods to [Model].
extension ModelPatterns on Model {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Model value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Model() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Model value)  $default,){
final _that = this;
switch (_that) {
case _Model():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Model value)?  $default,){
final _that = this;
switch (_that) {
case _Model() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String provider,  String? description,  String? providerType,  String? apiKey,  String? baseUrl,  int? maxTokens,  double? temperature,  bool? enabled,  bool? isDefault,  String? iconUrl,  String? presetModelId,  String? group,  ModelCapabilities? capabilities,  bool? multimodal,  bool? imageGeneration,  bool? videoGeneration,  List<ModelType>? modelTypes,  String? apiVersion,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody,  Map<String, String>? providerExtraHeaders,  Map<String, dynamic>? providerExtraBody)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Model() when $default != null:
return $default(_that.id,_that.name,_that.provider,_that.description,_that.providerType,_that.apiKey,_that.baseUrl,_that.maxTokens,_that.temperature,_that.enabled,_that.isDefault,_that.iconUrl,_that.presetModelId,_that.group,_that.capabilities,_that.multimodal,_that.imageGeneration,_that.videoGeneration,_that.modelTypes,_that.apiVersion,_that.extraHeaders,_that.extraBody,_that.providerExtraHeaders,_that.providerExtraBody);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String provider,  String? description,  String? providerType,  String? apiKey,  String? baseUrl,  int? maxTokens,  double? temperature,  bool? enabled,  bool? isDefault,  String? iconUrl,  String? presetModelId,  String? group,  ModelCapabilities? capabilities,  bool? multimodal,  bool? imageGeneration,  bool? videoGeneration,  List<ModelType>? modelTypes,  String? apiVersion,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody,  Map<String, String>? providerExtraHeaders,  Map<String, dynamic>? providerExtraBody)  $default,) {final _that = this;
switch (_that) {
case _Model():
return $default(_that.id,_that.name,_that.provider,_that.description,_that.providerType,_that.apiKey,_that.baseUrl,_that.maxTokens,_that.temperature,_that.enabled,_that.isDefault,_that.iconUrl,_that.presetModelId,_that.group,_that.capabilities,_that.multimodal,_that.imageGeneration,_that.videoGeneration,_that.modelTypes,_that.apiVersion,_that.extraHeaders,_that.extraBody,_that.providerExtraHeaders,_that.providerExtraBody);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String provider,  String? description,  String? providerType,  String? apiKey,  String? baseUrl,  int? maxTokens,  double? temperature,  bool? enabled,  bool? isDefault,  String? iconUrl,  String? presetModelId,  String? group,  ModelCapabilities? capabilities,  bool? multimodal,  bool? imageGeneration,  bool? videoGeneration,  List<ModelType>? modelTypes,  String? apiVersion,  Map<String, String>? extraHeaders,  Map<String, dynamic>? extraBody,  Map<String, String>? providerExtraHeaders,  Map<String, dynamic>? providerExtraBody)?  $default,) {final _that = this;
switch (_that) {
case _Model() when $default != null:
return $default(_that.id,_that.name,_that.provider,_that.description,_that.providerType,_that.apiKey,_that.baseUrl,_that.maxTokens,_that.temperature,_that.enabled,_that.isDefault,_that.iconUrl,_that.presetModelId,_that.group,_that.capabilities,_that.multimodal,_that.imageGeneration,_that.videoGeneration,_that.modelTypes,_that.apiVersion,_that.extraHeaders,_that.extraBody,_that.providerExtraHeaders,_that.providerExtraBody);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Model implements Model {
  const _Model({required this.id, required this.name, required this.provider, this.description, this.providerType, this.apiKey, this.baseUrl, this.maxTokens, this.temperature, this.enabled, this.isDefault, this.iconUrl, this.presetModelId, this.group, this.capabilities, this.multimodal, this.imageGeneration, this.videoGeneration, final  List<ModelType>? modelTypes, this.apiVersion, final  Map<String, String>? extraHeaders, final  Map<String, dynamic>? extraBody, final  Map<String, String>? providerExtraHeaders, final  Map<String, dynamic>? providerExtraBody}): _modelTypes = modelTypes,_extraHeaders = extraHeaders,_extraBody = extraBody,_providerExtraHeaders = providerExtraHeaders,_providerExtraBody = providerExtraBody;
  factory _Model.fromJson(Map<String, dynamic> json) => _$ModelFromJson(json);

@override final  String id;
@override final  String name;
@override final  String provider;
@override final  String? description;
@override final  String? providerType;
@override final  String? apiKey;
@override final  String? baseUrl;
@override final  int? maxTokens;
@override final  double? temperature;
@override final  bool? enabled;
@override final  bool? isDefault;
@override final  String? iconUrl;
@override final  String? presetModelId;
@override final  String? group;
@override final  ModelCapabilities? capabilities;
@override final  bool? multimodal;
@override final  bool? imageGeneration;
@override final  bool? videoGeneration;
 final  List<ModelType>? _modelTypes;
@override List<ModelType>? get modelTypes {
  final value = _modelTypes;
  if (value == null) return null;
  if (_modelTypes is EqualUnmodifiableListView) return _modelTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? apiVersion;
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

 final  Map<String, String>? _providerExtraHeaders;
@override Map<String, String>? get providerExtraHeaders {
  final value = _providerExtraHeaders;
  if (value == null) return null;
  if (_providerExtraHeaders is EqualUnmodifiableMapView) return _providerExtraHeaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _providerExtraBody;
@override Map<String, dynamic>? get providerExtraBody {
  final value = _providerExtraBody;
  if (value == null) return null;
  if (_providerExtraBody is EqualUnmodifiableMapView) return _providerExtraBody;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of Model
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ModelCopyWith<_Model> get copyWith => __$ModelCopyWithImpl<_Model>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Model&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.provider, provider) || other.provider == provider)&&(identical(other.description, description) || other.description == description)&&(identical(other.providerType, providerType) || other.providerType == providerType)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl)&&(identical(other.presetModelId, presetModelId) || other.presetModelId == presetModelId)&&(identical(other.group, group) || other.group == group)&&(identical(other.capabilities, capabilities) || other.capabilities == capabilities)&&(identical(other.multimodal, multimodal) || other.multimodal == multimodal)&&(identical(other.imageGeneration, imageGeneration) || other.imageGeneration == imageGeneration)&&(identical(other.videoGeneration, videoGeneration) || other.videoGeneration == videoGeneration)&&const DeepCollectionEquality().equals(other._modelTypes, _modelTypes)&&(identical(other.apiVersion, apiVersion) || other.apiVersion == apiVersion)&&const DeepCollectionEquality().equals(other._extraHeaders, _extraHeaders)&&const DeepCollectionEquality().equals(other._extraBody, _extraBody)&&const DeepCollectionEquality().equals(other._providerExtraHeaders, _providerExtraHeaders)&&const DeepCollectionEquality().equals(other._providerExtraBody, _providerExtraBody));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,name,provider,description,providerType,apiKey,baseUrl,maxTokens,temperature,enabled,isDefault,iconUrl,presetModelId,group,capabilities,multimodal,imageGeneration,videoGeneration,const DeepCollectionEquality().hash(_modelTypes),apiVersion,const DeepCollectionEquality().hash(_extraHeaders),const DeepCollectionEquality().hash(_extraBody),const DeepCollectionEquality().hash(_providerExtraHeaders),const DeepCollectionEquality().hash(_providerExtraBody)]);

@override
String toString() {
  return 'Model(id: $id, name: $name, provider: $provider, description: $description, providerType: $providerType, apiKey: $apiKey, baseUrl: $baseUrl, maxTokens: $maxTokens, temperature: $temperature, enabled: $enabled, isDefault: $isDefault, iconUrl: $iconUrl, presetModelId: $presetModelId, group: $group, capabilities: $capabilities, multimodal: $multimodal, imageGeneration: $imageGeneration, videoGeneration: $videoGeneration, modelTypes: $modelTypes, apiVersion: $apiVersion, extraHeaders: $extraHeaders, extraBody: $extraBody, providerExtraHeaders: $providerExtraHeaders, providerExtraBody: $providerExtraBody)';
}


}

/// @nodoc
abstract mixin class _$ModelCopyWith<$Res> implements $ModelCopyWith<$Res> {
  factory _$ModelCopyWith(_Model value, $Res Function(_Model) _then) = __$ModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String provider, String? description, String? providerType, String? apiKey, String? baseUrl, int? maxTokens, double? temperature, bool? enabled, bool? isDefault, String? iconUrl, String? presetModelId, String? group, ModelCapabilities? capabilities, bool? multimodal, bool? imageGeneration, bool? videoGeneration, List<ModelType>? modelTypes, String? apiVersion, Map<String, String>? extraHeaders, Map<String, dynamic>? extraBody, Map<String, String>? providerExtraHeaders, Map<String, dynamic>? providerExtraBody
});


@override $ModelCapabilitiesCopyWith<$Res>? get capabilities;

}
/// @nodoc
class __$ModelCopyWithImpl<$Res>
    implements _$ModelCopyWith<$Res> {
  __$ModelCopyWithImpl(this._self, this._then);

  final _Model _self;
  final $Res Function(_Model) _then;

/// Create a copy of Model
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? provider = null,Object? description = freezed,Object? providerType = freezed,Object? apiKey = freezed,Object? baseUrl = freezed,Object? maxTokens = freezed,Object? temperature = freezed,Object? enabled = freezed,Object? isDefault = freezed,Object? iconUrl = freezed,Object? presetModelId = freezed,Object? group = freezed,Object? capabilities = freezed,Object? multimodal = freezed,Object? imageGeneration = freezed,Object? videoGeneration = freezed,Object? modelTypes = freezed,Object? apiVersion = freezed,Object? extraHeaders = freezed,Object? extraBody = freezed,Object? providerExtraHeaders = freezed,Object? providerExtraBody = freezed,}) {
  return _then(_Model(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,provider: null == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,providerType: freezed == providerType ? _self.providerType : providerType // ignore: cast_nullable_to_non_nullable
as String?,apiKey: freezed == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String?,baseUrl: freezed == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String?,maxTokens: freezed == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int?,temperature: freezed == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double?,enabled: freezed == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool?,isDefault: freezed == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool?,iconUrl: freezed == iconUrl ? _self.iconUrl : iconUrl // ignore: cast_nullable_to_non_nullable
as String?,presetModelId: freezed == presetModelId ? _self.presetModelId : presetModelId // ignore: cast_nullable_to_non_nullable
as String?,group: freezed == group ? _self.group : group // ignore: cast_nullable_to_non_nullable
as String?,capabilities: freezed == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as ModelCapabilities?,multimodal: freezed == multimodal ? _self.multimodal : multimodal // ignore: cast_nullable_to_non_nullable
as bool?,imageGeneration: freezed == imageGeneration ? _self.imageGeneration : imageGeneration // ignore: cast_nullable_to_non_nullable
as bool?,videoGeneration: freezed == videoGeneration ? _self.videoGeneration : videoGeneration // ignore: cast_nullable_to_non_nullable
as bool?,modelTypes: freezed == modelTypes ? _self._modelTypes : modelTypes // ignore: cast_nullable_to_non_nullable
as List<ModelType>?,apiVersion: freezed == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String?,extraHeaders: freezed == extraHeaders ? _self._extraHeaders : extraHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,extraBody: freezed == extraBody ? _self._extraBody : extraBody // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,providerExtraHeaders: freezed == providerExtraHeaders ? _self._providerExtraHeaders : providerExtraHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>?,providerExtraBody: freezed == providerExtraBody ? _self._providerExtraBody : providerExtraBody // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

/// Create a copy of Model
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ModelCapabilitiesCopyWith<$Res>? get capabilities {
    if (_self.capabilities == null) {
    return null;
  }

  return $ModelCapabilitiesCopyWith<$Res>(_self.capabilities!, (value) {
    return _then(_self.copyWith(capabilities: value));
  });
}
}

// dart format on
