// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tts_provider_setting.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TtsProviderSetting {

 String get id; TtsProviderKind get kind; String get name; bool get enabled; String get apiKey; String get baseUrl; String get model; String get voice; String get groupId; String get emotion; double get speed; String get region; String get voiceName; String get outputFormat; String get appId; String get cluster; String get apiVersion; String get resourceId; double get volume; double get pitch; String get encoding; String get instructions;
/// Create a copy of TtsProviderSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TtsProviderSettingCopyWith<TtsProviderSetting> get copyWith => _$TtsProviderSettingCopyWithImpl<TtsProviderSetting>(this as TtsProviderSetting, _$identity);

  /// Serializes this TtsProviderSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsProviderSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.model, model) || other.model == model)&&(identical(other.voice, voice) || other.voice == voice)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.emotion, emotion) || other.emotion == emotion)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.region, region) || other.region == region)&&(identical(other.voiceName, voiceName) || other.voiceName == voiceName)&&(identical(other.outputFormat, outputFormat) || other.outputFormat == outputFormat)&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.cluster, cluster) || other.cluster == cluster)&&(identical(other.apiVersion, apiVersion) || other.apiVersion == apiVersion)&&(identical(other.resourceId, resourceId) || other.resourceId == resourceId)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.encoding, encoding) || other.encoding == encoding)&&(identical(other.instructions, instructions) || other.instructions == instructions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,kind,name,enabled,apiKey,baseUrl,model,voice,groupId,emotion,speed,region,voiceName,outputFormat,appId,cluster,apiVersion,resourceId,volume,pitch,encoding,instructions]);

@override
String toString() {
  return 'TtsProviderSetting(id: $id, kind: $kind, name: $name, enabled: $enabled, apiKey: $apiKey, baseUrl: $baseUrl, model: $model, voice: $voice, groupId: $groupId, emotion: $emotion, speed: $speed, region: $region, voiceName: $voiceName, outputFormat: $outputFormat, appId: $appId, cluster: $cluster, apiVersion: $apiVersion, resourceId: $resourceId, volume: $volume, pitch: $pitch, encoding: $encoding, instructions: $instructions)';
}


}

/// @nodoc
abstract mixin class $TtsProviderSettingCopyWith<$Res>  {
  factory $TtsProviderSettingCopyWith(TtsProviderSetting value, $Res Function(TtsProviderSetting) _then) = _$TtsProviderSettingCopyWithImpl;
@useResult
$Res call({
 String id, TtsProviderKind kind, String name, bool enabled, String apiKey, String baseUrl, String model, String voice, String groupId, String emotion, double speed, String region, String voiceName, String outputFormat, String appId, String cluster, String apiVersion, String resourceId, double volume, double pitch, String encoding, String instructions
});




}
/// @nodoc
class _$TtsProviderSettingCopyWithImpl<$Res>
    implements $TtsProviderSettingCopyWith<$Res> {
  _$TtsProviderSettingCopyWithImpl(this._self, this._then);

  final TtsProviderSetting _self;
  final $Res Function(TtsProviderSetting) _then;

/// Create a copy of TtsProviderSetting
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? enabled = null,Object? apiKey = null,Object? baseUrl = null,Object? model = null,Object? voice = null,Object? groupId = null,Object? emotion = null,Object? speed = null,Object? region = null,Object? voiceName = null,Object? outputFormat = null,Object? appId = null,Object? cluster = null,Object? apiVersion = null,Object? resourceId = null,Object? volume = null,Object? pitch = null,Object? encoding = null,Object? instructions = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as TtsProviderKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,voice: null == voice ? _self.voice : voice // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,emotion: null == emotion ? _self.emotion : emotion // ignore: cast_nullable_to_non_nullable
as String,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String,voiceName: null == voiceName ? _self.voiceName : voiceName // ignore: cast_nullable_to_non_nullable
as String,outputFormat: null == outputFormat ? _self.outputFormat : outputFormat // ignore: cast_nullable_to_non_nullable
as String,appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,cluster: null == cluster ? _self.cluster : cluster // ignore: cast_nullable_to_non_nullable
as String,apiVersion: null == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String,resourceId: null == resourceId ? _self.resourceId : resourceId // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,encoding: null == encoding ? _self.encoding : encoding // ignore: cast_nullable_to_non_nullable
as String,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TtsProviderSetting].
extension TtsProviderSettingPatterns on TtsProviderSetting {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TtsProviderSetting value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TtsProviderSetting() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TtsProviderSetting value)  $default,){
final _that = this;
switch (_that) {
case _TtsProviderSetting():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TtsProviderSetting value)?  $default,){
final _that = this;
switch (_that) {
case _TtsProviderSetting() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  TtsProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String voice,  String groupId,  String emotion,  double speed,  String region,  String voiceName,  String outputFormat,  String appId,  String cluster,  String apiVersion,  String resourceId,  double volume,  double pitch,  String encoding,  String instructions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TtsProviderSetting() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.voice,_that.groupId,_that.emotion,_that.speed,_that.region,_that.voiceName,_that.outputFormat,_that.appId,_that.cluster,_that.apiVersion,_that.resourceId,_that.volume,_that.pitch,_that.encoding,_that.instructions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  TtsProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String voice,  String groupId,  String emotion,  double speed,  String region,  String voiceName,  String outputFormat,  String appId,  String cluster,  String apiVersion,  String resourceId,  double volume,  double pitch,  String encoding,  String instructions)  $default,) {final _that = this;
switch (_that) {
case _TtsProviderSetting():
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.voice,_that.groupId,_that.emotion,_that.speed,_that.region,_that.voiceName,_that.outputFormat,_that.appId,_that.cluster,_that.apiVersion,_that.resourceId,_that.volume,_that.pitch,_that.encoding,_that.instructions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  TtsProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String voice,  String groupId,  String emotion,  double speed,  String region,  String voiceName,  String outputFormat,  String appId,  String cluster,  String apiVersion,  String resourceId,  double volume,  double pitch,  String encoding,  String instructions)?  $default,) {final _that = this;
switch (_that) {
case _TtsProviderSetting() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.voice,_that.groupId,_that.emotion,_that.speed,_that.region,_that.voiceName,_that.outputFormat,_that.appId,_that.cluster,_that.apiVersion,_that.resourceId,_that.volume,_that.pitch,_that.encoding,_that.instructions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TtsProviderSetting implements TtsProviderSetting {
  const _TtsProviderSetting({required this.id, required this.kind, this.name = '', this.enabled = false, this.apiKey = '', this.baseUrl = '', this.model = '', this.voice = '', this.groupId = '', this.emotion = '', this.speed = 1.0, this.region = '', this.voiceName = '', this.outputFormat = '', this.appId = '', this.cluster = '', this.apiVersion = 'auto', this.resourceId = '', this.volume = 1.0, this.pitch = 1.0, this.encoding = 'mp3', this.instructions = ''});
  factory _TtsProviderSetting.fromJson(Map<String, dynamic> json) => _$TtsProviderSettingFromJson(json);

@override final  String id;
@override final  TtsProviderKind kind;
@override@JsonKey() final  String name;
@override@JsonKey() final  bool enabled;
@override@JsonKey() final  String apiKey;
@override@JsonKey() final  String baseUrl;
@override@JsonKey() final  String model;
@override@JsonKey() final  String voice;
@override@JsonKey() final  String groupId;
@override@JsonKey() final  String emotion;
@override@JsonKey() final  double speed;
@override@JsonKey() final  String region;
@override@JsonKey() final  String voiceName;
@override@JsonKey() final  String outputFormat;
@override@JsonKey() final  String appId;
@override@JsonKey() final  String cluster;
@override@JsonKey() final  String apiVersion;
@override@JsonKey() final  String resourceId;
@override@JsonKey() final  double volume;
@override@JsonKey() final  double pitch;
@override@JsonKey() final  String encoding;
@override@JsonKey() final  String instructions;

/// Create a copy of TtsProviderSetting
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TtsProviderSettingCopyWith<_TtsProviderSetting> get copyWith => __$TtsProviderSettingCopyWithImpl<_TtsProviderSetting>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TtsProviderSettingToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TtsProviderSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.model, model) || other.model == model)&&(identical(other.voice, voice) || other.voice == voice)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.emotion, emotion) || other.emotion == emotion)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.region, region) || other.region == region)&&(identical(other.voiceName, voiceName) || other.voiceName == voiceName)&&(identical(other.outputFormat, outputFormat) || other.outputFormat == outputFormat)&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.cluster, cluster) || other.cluster == cluster)&&(identical(other.apiVersion, apiVersion) || other.apiVersion == apiVersion)&&(identical(other.resourceId, resourceId) || other.resourceId == resourceId)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.encoding, encoding) || other.encoding == encoding)&&(identical(other.instructions, instructions) || other.instructions == instructions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,kind,name,enabled,apiKey,baseUrl,model,voice,groupId,emotion,speed,region,voiceName,outputFormat,appId,cluster,apiVersion,resourceId,volume,pitch,encoding,instructions]);

@override
String toString() {
  return 'TtsProviderSetting(id: $id, kind: $kind, name: $name, enabled: $enabled, apiKey: $apiKey, baseUrl: $baseUrl, model: $model, voice: $voice, groupId: $groupId, emotion: $emotion, speed: $speed, region: $region, voiceName: $voiceName, outputFormat: $outputFormat, appId: $appId, cluster: $cluster, apiVersion: $apiVersion, resourceId: $resourceId, volume: $volume, pitch: $pitch, encoding: $encoding, instructions: $instructions)';
}


}

/// @nodoc
abstract mixin class _$TtsProviderSettingCopyWith<$Res> implements $TtsProviderSettingCopyWith<$Res> {
  factory _$TtsProviderSettingCopyWith(_TtsProviderSetting value, $Res Function(_TtsProviderSetting) _then) = __$TtsProviderSettingCopyWithImpl;
@override @useResult
$Res call({
 String id, TtsProviderKind kind, String name, bool enabled, String apiKey, String baseUrl, String model, String voice, String groupId, String emotion, double speed, String region, String voiceName, String outputFormat, String appId, String cluster, String apiVersion, String resourceId, double volume, double pitch, String encoding, String instructions
});




}
/// @nodoc
class __$TtsProviderSettingCopyWithImpl<$Res>
    implements _$TtsProviderSettingCopyWith<$Res> {
  __$TtsProviderSettingCopyWithImpl(this._self, this._then);

  final _TtsProviderSetting _self;
  final $Res Function(_TtsProviderSetting) _then;

/// Create a copy of TtsProviderSetting
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? enabled = null,Object? apiKey = null,Object? baseUrl = null,Object? model = null,Object? voice = null,Object? groupId = null,Object? emotion = null,Object? speed = null,Object? region = null,Object? voiceName = null,Object? outputFormat = null,Object? appId = null,Object? cluster = null,Object? apiVersion = null,Object? resourceId = null,Object? volume = null,Object? pitch = null,Object? encoding = null,Object? instructions = null,}) {
  return _then(_TtsProviderSetting(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as TtsProviderKind,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,apiKey: null == apiKey ? _self.apiKey : apiKey // ignore: cast_nullable_to_non_nullable
as String,baseUrl: null == baseUrl ? _self.baseUrl : baseUrl // ignore: cast_nullable_to_non_nullable
as String,model: null == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String,voice: null == voice ? _self.voice : voice // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,emotion: null == emotion ? _self.emotion : emotion // ignore: cast_nullable_to_non_nullable
as String,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String,voiceName: null == voiceName ? _self.voiceName : voiceName // ignore: cast_nullable_to_non_nullable
as String,outputFormat: null == outputFormat ? _self.outputFormat : outputFormat // ignore: cast_nullable_to_non_nullable
as String,appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,cluster: null == cluster ? _self.cluster : cluster // ignore: cast_nullable_to_non_nullable
as String,apiVersion: null == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String,resourceId: null == resourceId ? _self.resourceId : resourceId // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,encoding: null == encoding ? _self.encoding : encoding // ignore: cast_nullable_to_non_nullable
as String,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
