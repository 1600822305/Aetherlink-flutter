// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'asr_provider_setting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AsrProviderSetting {

 String get id; AsrProviderKind get kind; String get name; bool get enabled; String get apiKey; String get baseUrl; String get model; String get language; String get websocketUrl; String get responseFormat; double get temperature; double get vadThreshold; int get silenceDurationMs;
/// Create a copy of AsrProviderSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AsrProviderSettingCopyWith<AsrProviderSetting> get copyWith => _$AsrProviderSettingCopyWithImpl<AsrProviderSetting>(this as AsrProviderSetting, _$identity);

  /// Serializes this AsrProviderSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AsrProviderSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.model, model) || other.model == model)&&(identical(other.language, language) || other.language == language)&&(identical(other.websocketUrl, websocketUrl) || other.websocketUrl == websocketUrl)&&(identical(other.responseFormat, responseFormat) || other.responseFormat == responseFormat)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.vadThreshold, vadThreshold) || other.vadThreshold == vadThreshold)&&(identical(other.silenceDurationMs, silenceDurationMs) || other.silenceDurationMs == silenceDurationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,name,enabled,apiKey,baseUrl,model,language,websocketUrl,responseFormat,temperature,vadThreshold,silenceDurationMs);

@override
String toString() {
  return 'AsrProviderSetting(id: $id, kind: $kind, name: $name, enabled: $enabled, apiKey: $apiKey, baseUrl: $baseUrl, model: $model, language: $language, websocketUrl: $websocketUrl, responseFormat: $responseFormat, temperature: $temperature, vadThreshold: $vadThreshold, silenceDurationMs: $silenceDurationMs)';
}


}

/// @nodoc
abstract mixin class $AsrProviderSettingCopyWith<$Res>  {
  factory $AsrProviderSettingCopyWith(AsrProviderSetting value, $Res Function(AsrProviderSetting) _then) = _$AsrProviderSettingCopyWithImpl;
@useResult
$Res call({
 String id, AsrProviderKind kind, String name, bool enabled, String apiKey, String baseUrl, String model, String language, String websocketUrl, String responseFormat, double temperature, double vadThreshold, int silenceDurationMs
});




}
/// @nodoc
class _$AsrProviderSettingCopyWithImpl<$Res>
    implements $AsrProviderSettingCopyWith<$Res> {
  _$AsrProviderSettingCopyWithImpl(this._self, this._then);

  final AsrProviderSetting _self;
  final $Res Function(AsrProviderSetting) _then;

/// Create a copy of AsrProviderSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? enabled = null,Object? apiKey = null,Object? baseUrl = null,Object? model = null,Object? language = null,Object? websocketUrl = null,Object? responseFormat = null,Object? temperature = null,Object? vadThreshold = null,Object? silenceDurationMs = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AsrProviderKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,websocketUrl: null == websocketUrl ? _self.websocketUrl : websocketUrl // ignore: cast_nullable_to_non_nullable
as String,responseFormat: null == responseFormat ? _self.responseFormat : responseFormat // ignore: cast_nullable_to_non_nullable
as String,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,vadThreshold: null == vadThreshold ? _self.vadThreshold : vadThreshold // ignore: cast_nullable_to_non_nullable
as double,silenceDurationMs: null == silenceDurationMs ? _self.silenceDurationMs : silenceDurationMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AsrProviderSetting].
extension AsrProviderSettingPatterns on AsrProviderSetting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AsrProviderSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AsrProviderSetting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AsrProviderSetting value)  $default,){
final _that = this;
switch (_that) {
case _AsrProviderSetting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AsrProviderSetting value)?  $default,){
final _that = this;
switch (_that) {
case _AsrProviderSetting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  AsrProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String language,  String websocketUrl,  String responseFormat,  double temperature,  double vadThreshold,  int silenceDurationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AsrProviderSetting() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.language,_that.websocketUrl,_that.responseFormat,_that.temperature,_that.vadThreshold,_that.silenceDurationMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  AsrProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String language,  String websocketUrl,  String responseFormat,  double temperature,  double vadThreshold,  int silenceDurationMs)  $default,) {final _that = this;
switch (_that) {
case _AsrProviderSetting():
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.language,_that.websocketUrl,_that.responseFormat,_that.temperature,_that.vadThreshold,_that.silenceDurationMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  AsrProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String language,  String websocketUrl,  String responseFormat,  double temperature,  double vadThreshold,  int silenceDurationMs)?  $default,) {final _that = this;
switch (_that) {
case _AsrProviderSetting() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.language,_that.websocketUrl,_that.responseFormat,_that.temperature,_that.vadThreshold,_that.silenceDurationMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AsrProviderSetting implements AsrProviderSetting {
  const _AsrProviderSetting({required this.id, required this.kind, this.name = '', this.enabled = false, this.apiKey = '', this.baseUrl = '', this.model = '', this.language = '', this.websocketUrl = '', this.responseFormat = '', this.temperature = 0.0, this.vadThreshold = 0.5, this.silenceDurationMs = 500});
  factory _AsrProviderSetting.fromJson(Map<String, dynamic> json) => _$AsrProviderSettingFromJson(json);

@override final  String id;
@override final  AsrProviderKind kind;
@override@JsonKey() final  String name;
@override@JsonKey() final  bool enabled;
@override@JsonKey() final  String apiKey;
@override@JsonKey() final  String baseUrl;
@override@JsonKey() final  String model;
@override@JsonKey() final  String language;
@override@JsonKey() final  String websocketUrl;
@override@JsonKey() final  String responseFormat;
@override@JsonKey() final  double temperature;
@override@JsonKey() final  double vadThreshold;
@override@JsonKey() final  int silenceDurationMs;

/// Create a copy of AsrProviderSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AsrProviderSettingCopyWith<_AsrProviderSetting> get copyWith => __$AsrProviderSettingCopyWithImpl<_AsrProviderSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AsrProviderSettingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AsrProviderSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.model, model) || other.model == model)&&(identical(other.language, language) || other.language == language)&&(identical(other.websocketUrl, websocketUrl) || other.websocketUrl == websocketUrl)&&(identical(other.responseFormat, responseFormat) || other.responseFormat == responseFormat)&&(identical(other.temperature, temperature) || other.temperature == temperature)&&(identical(other.vadThreshold, vadThreshold) || other.vadThreshold == vadThreshold)&&(identical(other.silenceDurationMs, silenceDurationMs) || other.silenceDurationMs == silenceDurationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,kind,name,enabled,apiKey,baseUrl,model,language,websocketUrl,responseFormat,temperature,vadThreshold,silenceDurationMs);

@override
String toString() {
  return 'AsrProviderSetting(id: $id, kind: $kind, name: $name, enabled: $enabled, apiKey: $apiKey, baseUrl: $baseUrl, model: $model, language: $language, websocketUrl: $websocketUrl, responseFormat: $responseFormat, temperature: $temperature, vadThreshold: $vadThreshold, silenceDurationMs: $silenceDurationMs)';
}


}

/// @nodoc
abstract mixin class _$AsrProviderSettingCopyWith<$Res> implements $AsrProviderSettingCopyWith<$Res> {
  factory _$AsrProviderSettingCopyWith(_AsrProviderSetting value, $Res Function(_AsrProviderSetting) _then) = __$AsrProviderSettingCopyWithImpl;
@override @useResult
$Res call({
 String id, AsrProviderKind kind, String name, bool enabled, String apiKey, String baseUrl, String model, String language, String websocketUrl, String responseFormat, double temperature, double vadThreshold, int silenceDurationMs
});




}
/// @nodoc
class __$AsrProviderSettingCopyWithImpl<$Res>
    implements _$AsrProviderSettingCopyWith<$Res> {
  __$AsrProviderSettingCopyWithImpl(this._self, this._then);

  final _AsrProviderSetting _self;
  final $Res Function(_AsrProviderSetting) _then;

/// Create a copy of AsrProviderSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? enabled = null,Object? apiKey = null,Object? baseUrl = null,Object? model = null,Object? language = null,Object? websocketUrl = null,Object? responseFormat = null,Object? temperature = null,Object? vadThreshold = null,Object? silenceDurationMs = null,}) {
  return _then(_AsrProviderSetting(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as AsrProviderKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,websocketUrl: null == websocketUrl ? _self.websocketUrl : websocketUrl // ignore: cast_nullable_to_non_nullable
as String,responseFormat: null == responseFormat ? _self.responseFormat : responseFormat // ignore: cast_nullable_to_non_nullable
as String,temperature: null == temperature ? _self.temperature : temperature // ignore: cast_nullable_to_non_nullable
as double,vadThreshold: null == vadThreshold ? _self.vadThreshold : vadThreshold // ignore: cast_nullable_to_non_nullable
as double,silenceDurationMs: null == silenceDurationMs ? _self.silenceDurationMs : silenceDurationMs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
