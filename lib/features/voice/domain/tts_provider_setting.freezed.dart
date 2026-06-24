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

 String get id; TtsProviderKind get kind; String get name; bool get enabled; String get apiKey; String get baseUrl; String get model; String get voice; String get groupId; String get emotion; double get speed; String get languageBoost; int get sampleRate; int get bitrate; String get audioFormat; String get region; String get azureRate; String get azurePitch; String get azureVolume; String get azureStyle; double get azureStyleDegree; String get azureRole; String get azureOutputFormat; String get voiceName; String get stylePrompt; bool get useMultiSpeaker; String get speaker1Name; String get speaker1Voice; String get speaker2Name; String get speaker2Voice; String get outputFormat; double get stability; double get similarityBoost; double get elStyle; bool get useSpeakerBoost; String get appId; String get cluster; String get apiVersion; String get resourceId; double get volume; double get pitch; String get encoding; double get gain; int get maxTokens; String get instructions; String get mimoVoiceDescription; bool get mimoOptimizeTextPreview; String get mimoVoiceCloneAudio; String get qwenLanguageType; String get qwenInstructions; bool get qwenOptimizeInstructions; int get groqSampleRate; String get xaiLanguage; String get xaiCodec; int get xaiSampleRate; int get xaiBitRate; bool get xaiTextNormalization; int get xaiOptimizeStreamingLatency;
/// Create a copy of TtsProviderSetting
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TtsProviderSettingCopyWith<TtsProviderSetting> get copyWith => _$TtsProviderSettingCopyWithImpl<TtsProviderSetting>(this as TtsProviderSetting, _$identity);

  /// Serializes this TtsProviderSetting to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TtsProviderSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.model, model) || other.model == model)&&(identical(other.voice, voice) || other.voice == voice)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.emotion, emotion) || other.emotion == emotion)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.languageBoost, languageBoost) || other.languageBoost == languageBoost)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.bitrate, bitrate) || other.bitrate == bitrate)&&(identical(other.audioFormat, audioFormat) || other.audioFormat == audioFormat)&&(identical(other.region, region) || other.region == region)&&(identical(other.azureRate, azureRate) || other.azureRate == azureRate)&&(identical(other.azurePitch, azurePitch) || other.azurePitch == azurePitch)&&(identical(other.azureVolume, azureVolume) || other.azureVolume == azureVolume)&&(identical(other.azureStyle, azureStyle) || other.azureStyle == azureStyle)&&(identical(other.azureStyleDegree, azureStyleDegree) || other.azureStyleDegree == azureStyleDegree)&&(identical(other.azureRole, azureRole) || other.azureRole == azureRole)&&(identical(other.azureOutputFormat, azureOutputFormat) || other.azureOutputFormat == azureOutputFormat)&&(identical(other.voiceName, voiceName) || other.voiceName == voiceName)&&(identical(other.stylePrompt, stylePrompt) || other.stylePrompt == stylePrompt)&&(identical(other.useMultiSpeaker, useMultiSpeaker) || other.useMultiSpeaker == useMultiSpeaker)&&(identical(other.speaker1Name, speaker1Name) || other.speaker1Name == speaker1Name)&&(identical(other.speaker1Voice, speaker1Voice) || other.speaker1Voice == speaker1Voice)&&(identical(other.speaker2Name, speaker2Name) || other.speaker2Name == speaker2Name)&&(identical(other.speaker2Voice, speaker2Voice) || other.speaker2Voice == speaker2Voice)&&(identical(other.outputFormat, outputFormat) || other.outputFormat == outputFormat)&&(identical(other.stability, stability) || other.stability == stability)&&(identical(other.similarityBoost, similarityBoost) || other.similarityBoost == similarityBoost)&&(identical(other.elStyle, elStyle) || other.elStyle == elStyle)&&(identical(other.useSpeakerBoost, useSpeakerBoost) || other.useSpeakerBoost == useSpeakerBoost)&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.cluster, cluster) || other.cluster == cluster)&&(identical(other.apiVersion, apiVersion) || other.apiVersion == apiVersion)&&(identical(other.resourceId, resourceId) || other.resourceId == resourceId)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.encoding, encoding) || other.encoding == encoding)&&(identical(other.gain, gain) || other.gain == gain)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.instructions, instructions) || other.instructions == instructions)&&(identical(other.mimoVoiceDescription, mimoVoiceDescription) || other.mimoVoiceDescription == mimoVoiceDescription)&&(identical(other.mimoOptimizeTextPreview, mimoOptimizeTextPreview) || other.mimoOptimizeTextPreview == mimoOptimizeTextPreview)&&(identical(other.mimoVoiceCloneAudio, mimoVoiceCloneAudio) || other.mimoVoiceCloneAudio == mimoVoiceCloneAudio)&&(identical(other.qwenLanguageType, qwenLanguageType) || other.qwenLanguageType == qwenLanguageType)&&(identical(other.qwenInstructions, qwenInstructions) || other.qwenInstructions == qwenInstructions)&&(identical(other.qwenOptimizeInstructions, qwenOptimizeInstructions) || other.qwenOptimizeInstructions == qwenOptimizeInstructions)&&(identical(other.groqSampleRate, groqSampleRate) || other.groqSampleRate == groqSampleRate)&&(identical(other.xaiLanguage, xaiLanguage) || other.xaiLanguage == xaiLanguage)&&(identical(other.xaiCodec, xaiCodec) || other.xaiCodec == xaiCodec)&&(identical(other.xaiSampleRate, xaiSampleRate) || other.xaiSampleRate == xaiSampleRate)&&(identical(other.xaiBitRate, xaiBitRate) || other.xaiBitRate == xaiBitRate)&&(identical(other.xaiTextNormalization, xaiTextNormalization) || other.xaiTextNormalization == xaiTextNormalization)&&(identical(other.xaiOptimizeStreamingLatency, xaiOptimizeStreamingLatency) || other.xaiOptimizeStreamingLatency == xaiOptimizeStreamingLatency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,kind,name,enabled,apiKey,baseUrl,model,voice,groupId,emotion,speed,languageBoost,sampleRate,bitrate,audioFormat,region,azureRate,azurePitch,azureVolume,azureStyle,azureStyleDegree,azureRole,azureOutputFormat,voiceName,stylePrompt,useMultiSpeaker,speaker1Name,speaker1Voice,speaker2Name,speaker2Voice,outputFormat,stability,similarityBoost,elStyle,useSpeakerBoost,appId,cluster,apiVersion,resourceId,volume,pitch,encoding,gain,maxTokens,instructions,mimoVoiceDescription,mimoOptimizeTextPreview,mimoVoiceCloneAudio,qwenLanguageType,qwenInstructions,qwenOptimizeInstructions,groqSampleRate,xaiLanguage,xaiCodec,xaiSampleRate,xaiBitRate,xaiTextNormalization,xaiOptimizeStreamingLatency]);

@override
String toString() {
  return 'TtsProviderSetting(id: $id, kind: $kind, name: $name, enabled: $enabled, apiKey: $apiKey, baseUrl: $baseUrl, model: $model, voice: $voice, groupId: $groupId, emotion: $emotion, speed: $speed, languageBoost: $languageBoost, sampleRate: $sampleRate, bitrate: $bitrate, audioFormat: $audioFormat, region: $region, azureRate: $azureRate, azurePitch: $azurePitch, azureVolume: $azureVolume, azureStyle: $azureStyle, azureStyleDegree: $azureStyleDegree, azureRole: $azureRole, azureOutputFormat: $azureOutputFormat, voiceName: $voiceName, stylePrompt: $stylePrompt, useMultiSpeaker: $useMultiSpeaker, speaker1Name: $speaker1Name, speaker1Voice: $speaker1Voice, speaker2Name: $speaker2Name, speaker2Voice: $speaker2Voice, outputFormat: $outputFormat, stability: $stability, similarityBoost: $similarityBoost, elStyle: $elStyle, useSpeakerBoost: $useSpeakerBoost, appId: $appId, cluster: $cluster, apiVersion: $apiVersion, resourceId: $resourceId, volume: $volume, pitch: $pitch, encoding: $encoding, gain: $gain, maxTokens: $maxTokens, instructions: $instructions, mimoVoiceDescription: $mimoVoiceDescription, mimoOptimizeTextPreview: $mimoOptimizeTextPreview, mimoVoiceCloneAudio: $mimoVoiceCloneAudio, qwenLanguageType: $qwenLanguageType, qwenInstructions: $qwenInstructions, qwenOptimizeInstructions: $qwenOptimizeInstructions, groqSampleRate: $groqSampleRate, xaiLanguage: $xaiLanguage, xaiCodec: $xaiCodec, xaiSampleRate: $xaiSampleRate, xaiBitRate: $xaiBitRate, xaiTextNormalization: $xaiTextNormalization, xaiOptimizeStreamingLatency: $xaiOptimizeStreamingLatency)';
}


}

/// @nodoc
abstract mixin class $TtsProviderSettingCopyWith<$Res>  {
  factory $TtsProviderSettingCopyWith(TtsProviderSetting value, $Res Function(TtsProviderSetting) _then) = _$TtsProviderSettingCopyWithImpl;
@useResult
$Res call({
 String id, TtsProviderKind kind, String name, bool enabled, String apiKey, String baseUrl, String model, String voice, String groupId, String emotion, double speed, String languageBoost, int sampleRate, int bitrate, String audioFormat, String region, String azureRate, String azurePitch, String azureVolume, String azureStyle, double azureStyleDegree, String azureRole, String azureOutputFormat, String voiceName, String stylePrompt, bool useMultiSpeaker, String speaker1Name, String speaker1Voice, String speaker2Name, String speaker2Voice, String outputFormat, double stability, double similarityBoost, double elStyle, bool useSpeakerBoost, String appId, String cluster, String apiVersion, String resourceId, double volume, double pitch, String encoding, double gain, int maxTokens, String instructions, String mimoVoiceDescription, bool mimoOptimizeTextPreview, String mimoVoiceCloneAudio, String qwenLanguageType, String qwenInstructions, bool qwenOptimizeInstructions, int groqSampleRate, String xaiLanguage, String xaiCodec, int xaiSampleRate, int xaiBitRate, bool xaiTextNormalization, int xaiOptimizeStreamingLatency
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? enabled = null,Object? apiKey = null,Object? baseUrl = null,Object? model = null,Object? voice = null,Object? groupId = null,Object? emotion = null,Object? speed = null,Object? languageBoost = null,Object? sampleRate = null,Object? bitrate = null,Object? audioFormat = null,Object? region = null,Object? azureRate = null,Object? azurePitch = null,Object? azureVolume = null,Object? azureStyle = null,Object? azureStyleDegree = null,Object? azureRole = null,Object? azureOutputFormat = null,Object? voiceName = null,Object? stylePrompt = null,Object? useMultiSpeaker = null,Object? speaker1Name = null,Object? speaker1Voice = null,Object? speaker2Name = null,Object? speaker2Voice = null,Object? outputFormat = null,Object? stability = null,Object? similarityBoost = null,Object? elStyle = null,Object? useSpeakerBoost = null,Object? appId = null,Object? cluster = null,Object? apiVersion = null,Object? resourceId = null,Object? volume = null,Object? pitch = null,Object? encoding = null,Object? gain = null,Object? maxTokens = null,Object? instructions = null,Object? mimoVoiceDescription = null,Object? mimoOptimizeTextPreview = null,Object? mimoVoiceCloneAudio = null,Object? qwenLanguageType = null,Object? qwenInstructions = null,Object? qwenOptimizeInstructions = null,Object? groqSampleRate = null,Object? xaiLanguage = null,Object? xaiCodec = null,Object? xaiSampleRate = null,Object? xaiBitRate = null,Object? xaiTextNormalization = null,Object? xaiOptimizeStreamingLatency = null,}) {
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
as double,languageBoost: null == languageBoost ? _self.languageBoost : languageBoost // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,bitrate: null == bitrate ? _self.bitrate : bitrate // ignore: cast_nullable_to_non_nullable
as int,audioFormat: null == audioFormat ? _self.audioFormat : audioFormat // ignore: cast_nullable_to_non_nullable
as String,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String,azureRate: null == azureRate ? _self.azureRate : azureRate // ignore: cast_nullable_to_non_nullable
as String,azurePitch: null == azurePitch ? _self.azurePitch : azurePitch // ignore: cast_nullable_to_non_nullable
as String,azureVolume: null == azureVolume ? _self.azureVolume : azureVolume // ignore: cast_nullable_to_non_nullable
as String,azureStyle: null == azureStyle ? _self.azureStyle : azureStyle // ignore: cast_nullable_to_non_nullable
as String,azureStyleDegree: null == azureStyleDegree ? _self.azureStyleDegree : azureStyleDegree // ignore: cast_nullable_to_non_nullable
as double,azureRole: null == azureRole ? _self.azureRole : azureRole // ignore: cast_nullable_to_non_nullable
as String,azureOutputFormat: null == azureOutputFormat ? _self.azureOutputFormat : azureOutputFormat // ignore: cast_nullable_to_non_nullable
as String,voiceName: null == voiceName ? _self.voiceName : voiceName // ignore: cast_nullable_to_non_nullable
as String,stylePrompt: null == stylePrompt ? _self.stylePrompt : stylePrompt // ignore: cast_nullable_to_non_nullable
as String,useMultiSpeaker: null == useMultiSpeaker ? _self.useMultiSpeaker : useMultiSpeaker // ignore: cast_nullable_to_non_nullable
as bool,speaker1Name: null == speaker1Name ? _self.speaker1Name : speaker1Name // ignore: cast_nullable_to_non_nullable
as String,speaker1Voice: null == speaker1Voice ? _self.speaker1Voice : speaker1Voice // ignore: cast_nullable_to_non_nullable
as String,speaker2Name: null == speaker2Name ? _self.speaker2Name : speaker2Name // ignore: cast_nullable_to_non_nullable
as String,speaker2Voice: null == speaker2Voice ? _self.speaker2Voice : speaker2Voice // ignore: cast_nullable_to_non_nullable
as String,outputFormat: null == outputFormat ? _self.outputFormat : outputFormat // ignore: cast_nullable_to_non_nullable
as String,stability: null == stability ? _self.stability : stability // ignore: cast_nullable_to_non_nullable
as double,similarityBoost: null == similarityBoost ? _self.similarityBoost : similarityBoost // ignore: cast_nullable_to_non_nullable
as double,elStyle: null == elStyle ? _self.elStyle : elStyle // ignore: cast_nullable_to_non_nullable
as double,useSpeakerBoost: null == useSpeakerBoost ? _self.useSpeakerBoost : useSpeakerBoost // ignore: cast_nullable_to_non_nullable
as bool,appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,cluster: null == cluster ? _self.cluster : cluster // ignore: cast_nullable_to_non_nullable
as String,apiVersion: null == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String,resourceId: null == resourceId ? _self.resourceId : resourceId // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,encoding: null == encoding ? _self.encoding : encoding // ignore: cast_nullable_to_non_nullable
as String,gain: null == gain ? _self.gain : gain // ignore: cast_nullable_to_non_nullable
as double,maxTokens: null == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,mimoVoiceDescription: null == mimoVoiceDescription ? _self.mimoVoiceDescription : mimoVoiceDescription // ignore: cast_nullable_to_non_nullable
as String,mimoOptimizeTextPreview: null == mimoOptimizeTextPreview ? _self.mimoOptimizeTextPreview : mimoOptimizeTextPreview // ignore: cast_nullable_to_non_nullable
as bool,mimoVoiceCloneAudio: null == mimoVoiceCloneAudio ? _self.mimoVoiceCloneAudio : mimoVoiceCloneAudio // ignore: cast_nullable_to_non_nullable
as String,qwenLanguageType: null == qwenLanguageType ? _self.qwenLanguageType : qwenLanguageType // ignore: cast_nullable_to_non_nullable
as String,qwenInstructions: null == qwenInstructions ? _self.qwenInstructions : qwenInstructions // ignore: cast_nullable_to_non_nullable
as String,qwenOptimizeInstructions: null == qwenOptimizeInstructions ? _self.qwenOptimizeInstructions : qwenOptimizeInstructions // ignore: cast_nullable_to_non_nullable
as bool,groqSampleRate: null == groqSampleRate ? _self.groqSampleRate : groqSampleRate // ignore: cast_nullable_to_non_nullable
as int,xaiLanguage: null == xaiLanguage ? _self.xaiLanguage : xaiLanguage // ignore: cast_nullable_to_non_nullable
as String,xaiCodec: null == xaiCodec ? _self.xaiCodec : xaiCodec // ignore: cast_nullable_to_non_nullable
as String,xaiSampleRate: null == xaiSampleRate ? _self.xaiSampleRate : xaiSampleRate // ignore: cast_nullable_to_non_nullable
as int,xaiBitRate: null == xaiBitRate ? _self.xaiBitRate : xaiBitRate // ignore: cast_nullable_to_non_nullable
as int,xaiTextNormalization: null == xaiTextNormalization ? _self.xaiTextNormalization : xaiTextNormalization // ignore: cast_nullable_to_non_nullable
as bool,xaiOptimizeStreamingLatency: null == xaiOptimizeStreamingLatency ? _self.xaiOptimizeStreamingLatency : xaiOptimizeStreamingLatency // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  TtsProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String voice,  String groupId,  String emotion,  double speed,  String languageBoost,  int sampleRate,  int bitrate,  String audioFormat,  String region,  String azureRate,  String azurePitch,  String azureVolume,  String azureStyle,  double azureStyleDegree,  String azureRole,  String azureOutputFormat,  String voiceName,  String stylePrompt,  bool useMultiSpeaker,  String speaker1Name,  String speaker1Voice,  String speaker2Name,  String speaker2Voice,  String outputFormat,  double stability,  double similarityBoost,  double elStyle,  bool useSpeakerBoost,  String appId,  String cluster,  String apiVersion,  String resourceId,  double volume,  double pitch,  String encoding,  double gain,  int maxTokens,  String instructions, String mimoVoiceDescription, bool mimoOptimizeTextPreview, String mimoVoiceCloneAudio, String qwenLanguageType, String qwenInstructions, bool qwenOptimizeInstructions, int groqSampleRate, String xaiLanguage, String xaiCodec, int xaiSampleRate, int xaiBitRate, bool xaiTextNormalization, int xaiOptimizeStreamingLatency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TtsProviderSetting() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.voice,_that.groupId,_that.emotion,_that.speed,_that.languageBoost,_that.sampleRate,_that.bitrate,_that.audioFormat,_that.region,_that.azureRate,_that.azurePitch,_that.azureVolume,_that.azureStyle,_that.azureStyleDegree,_that.azureRole,_that.azureOutputFormat,_that.voiceName,_that.stylePrompt,_that.useMultiSpeaker,_that.speaker1Name,_that.speaker1Voice,_that.speaker2Name,_that.speaker2Voice,_that.outputFormat,_that.stability,_that.similarityBoost,_that.elStyle,_that.useSpeakerBoost,_that.appId,_that.cluster,_that.apiVersion,_that.resourceId,_that.volume,_that.pitch,_that.encoding,_that.gain,_that.maxTokens,_that.instructions,_that.mimoVoiceDescription,_that.mimoOptimizeTextPreview,_that.mimoVoiceCloneAudio,_that.qwenLanguageType,_that.qwenInstructions,_that.qwenOptimizeInstructions,_that.groqSampleRate,_that.xaiLanguage,_that.xaiCodec,_that.xaiSampleRate,_that.xaiBitRate,_that.xaiTextNormalization,_that.xaiOptimizeStreamingLatency);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  TtsProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String voice,  String groupId,  String emotion,  double speed,  String languageBoost,  int sampleRate,  int bitrate,  String audioFormat,  String region,  String azureRate,  String azurePitch,  String azureVolume,  String azureStyle,  double azureStyleDegree,  String azureRole,  String azureOutputFormat,  String voiceName,  String stylePrompt,  bool useMultiSpeaker,  String speaker1Name,  String speaker1Voice,  String speaker2Name,  String speaker2Voice,  String outputFormat,  double stability,  double similarityBoost,  double elStyle,  bool useSpeakerBoost,  String appId,  String cluster,  String apiVersion,  String resourceId,  double volume,  double pitch,  String encoding,  double gain,  int maxTokens,  String instructions, String mimoVoiceDescription, bool mimoOptimizeTextPreview, String mimoVoiceCloneAudio, String qwenLanguageType, String qwenInstructions, bool qwenOptimizeInstructions, int groqSampleRate, String xaiLanguage, String xaiCodec, int xaiSampleRate, int xaiBitRate, bool xaiTextNormalization, int xaiOptimizeStreamingLatency)  $default,) {final _that = this;
switch (_that) {
case _TtsProviderSetting():
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.voice,_that.groupId,_that.emotion,_that.speed,_that.languageBoost,_that.sampleRate,_that.bitrate,_that.audioFormat,_that.region,_that.azureRate,_that.azurePitch,_that.azureVolume,_that.azureStyle,_that.azureStyleDegree,_that.azureRole,_that.azureOutputFormat,_that.voiceName,_that.stylePrompt,_that.useMultiSpeaker,_that.speaker1Name,_that.speaker1Voice,_that.speaker2Name,_that.speaker2Voice,_that.outputFormat,_that.stability,_that.similarityBoost,_that.elStyle,_that.useSpeakerBoost,_that.appId,_that.cluster,_that.apiVersion,_that.resourceId,_that.volume,_that.pitch,_that.encoding,_that.gain,_that.maxTokens,_that.instructions,_that.mimoVoiceDescription,_that.mimoOptimizeTextPreview,_that.mimoVoiceCloneAudio,_that.qwenLanguageType,_that.qwenInstructions,_that.qwenOptimizeInstructions,_that.groqSampleRate,_that.xaiLanguage,_that.xaiCodec,_that.xaiSampleRate,_that.xaiBitRate,_that.xaiTextNormalization,_that.xaiOptimizeStreamingLatency);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  TtsProviderKind kind,  String name,  bool enabled,  String apiKey,  String baseUrl,  String model,  String voice,  String groupId,  String emotion,  double speed,  String languageBoost,  int sampleRate,  int bitrate,  String audioFormat,  String region,  String azureRate,  String azurePitch,  String azureVolume,  String azureStyle,  double azureStyleDegree,  String azureRole,  String azureOutputFormat,  String voiceName,  String stylePrompt,  bool useMultiSpeaker,  String speaker1Name,  String speaker1Voice,  String speaker2Name,  String speaker2Voice,  String outputFormat,  double stability,  double similarityBoost,  double elStyle,  bool useSpeakerBoost,  String appId,  String cluster,  String apiVersion,  String resourceId,  double volume,  double pitch,  String encoding,  double gain,  int maxTokens,  String instructions, String mimoVoiceDescription, bool mimoOptimizeTextPreview, String mimoVoiceCloneAudio, String qwenLanguageType, String qwenInstructions, bool qwenOptimizeInstructions, int groqSampleRate, String xaiLanguage, String xaiCodec, int xaiSampleRate, int xaiBitRate, bool xaiTextNormalization, int xaiOptimizeStreamingLatency)?  $default,) {final _that = this;
switch (_that) {
case _TtsProviderSetting() when $default != null:
return $default(_that.id,_that.kind,_that.name,_that.enabled,_that.apiKey,_that.baseUrl,_that.model,_that.voice,_that.groupId,_that.emotion,_that.speed,_that.languageBoost,_that.sampleRate,_that.bitrate,_that.audioFormat,_that.region,_that.azureRate,_that.azurePitch,_that.azureVolume,_that.azureStyle,_that.azureStyleDegree,_that.azureRole,_that.azureOutputFormat,_that.voiceName,_that.stylePrompt,_that.useMultiSpeaker,_that.speaker1Name,_that.speaker1Voice,_that.speaker2Name,_that.speaker2Voice,_that.outputFormat,_that.stability,_that.similarityBoost,_that.elStyle,_that.useSpeakerBoost,_that.appId,_that.cluster,_that.apiVersion,_that.resourceId,_that.volume,_that.pitch,_that.encoding,_that.gain,_that.maxTokens,_that.instructions,_that.mimoVoiceDescription,_that.mimoOptimizeTextPreview,_that.mimoVoiceCloneAudio,_that.qwenLanguageType,_that.qwenInstructions,_that.qwenOptimizeInstructions,_that.groqSampleRate,_that.xaiLanguage,_that.xaiCodec,_that.xaiSampleRate,_that.xaiBitRate,_that.xaiTextNormalization,_that.xaiOptimizeStreamingLatency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TtsProviderSetting implements TtsProviderSetting {
  const _TtsProviderSetting({required this.id, required this.kind, this.name = '', this.enabled = false, this.apiKey = '', this.baseUrl = '', this.model = '', this.voice = '', this.groupId = '', this.emotion = '', this.speed = 1.0, this.languageBoost = '', this.sampleRate = 32000, this.bitrate = 128000, this.audioFormat = 'mp3', this.region = '', this.azureRate = 'medium', this.azurePitch = 'medium', this.azureVolume = 'medium', this.azureStyle = '', this.azureStyleDegree = 1.0, this.azureRole = '', this.azureOutputFormat = 'audio-16khz-128kbitrate-mono-mp3', this.voiceName = '', this.stylePrompt = '', this.useMultiSpeaker = false, this.speaker1Name = '', this.speaker1Voice = '', this.speaker2Name = '', this.speaker2Voice = '', this.outputFormat = '', this.stability = 0.5, this.similarityBoost = 0.75, this.elStyle = 0.0, this.useSpeakerBoost = true, this.appId = '', this.cluster = '', this.apiVersion = 'auto', this.resourceId = '', this.volume = 1.0, this.pitch = 1.0, this.encoding = 'mp3', this.gain = 0.0, this.maxTokens = 1600, this.instructions = '', this.mimoVoiceDescription = '', this.mimoOptimizeTextPreview = false, this.mimoVoiceCloneAudio = '', this.qwenLanguageType = 'Auto', this.qwenInstructions = '', this.qwenOptimizeInstructions = false, this.groqSampleRate = 24000, this.xaiLanguage = 'auto', this.xaiCodec = 'mp3', this.xaiSampleRate = 24000, this.xaiBitRate = 128000, this.xaiTextNormalization = false, this.xaiOptimizeStreamingLatency = 0});
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
@override@JsonKey() final  String languageBoost;
@override@JsonKey() final  int sampleRate;
@override@JsonKey() final  int bitrate;
@override@JsonKey() final  String audioFormat;
@override@JsonKey() final  String region;
@override@JsonKey() final  String azureRate;
@override@JsonKey() final  String azurePitch;
@override@JsonKey() final  String azureVolume;
@override@JsonKey() final  String azureStyle;
@override@JsonKey() final  double azureStyleDegree;
@override@JsonKey() final  String azureRole;
@override@JsonKey() final  String azureOutputFormat;
@override@JsonKey() final  String voiceName;
@override@JsonKey() final  String stylePrompt;
@override@JsonKey() final  bool useMultiSpeaker;
@override@JsonKey() final  String speaker1Name;
@override@JsonKey() final  String speaker1Voice;
@override@JsonKey() final  String speaker2Name;
@override@JsonKey() final  String speaker2Voice;
@override@JsonKey() final  String outputFormat;
@override@JsonKey() final  double stability;
@override@JsonKey() final  double similarityBoost;
@override@JsonKey() final  double elStyle;
@override@JsonKey() final  bool useSpeakerBoost;
@override@JsonKey() final  String appId;
@override@JsonKey() final  String cluster;
@override@JsonKey() final  String apiVersion;
@override@JsonKey() final  String resourceId;
@override@JsonKey() final  double volume;
@override@JsonKey() final  double pitch;
@override@JsonKey() final  String encoding;
@override@JsonKey() final  double gain;
@override@JsonKey() final  int maxTokens;
@override@JsonKey() final  String instructions;
@override@JsonKey() final  String mimoVoiceDescription;
@override@JsonKey() final  bool mimoOptimizeTextPreview;
@override@JsonKey() final  String mimoVoiceCloneAudio;
@override@JsonKey() final  String qwenLanguageType;
@override@JsonKey() final  String qwenInstructions;
@override@JsonKey() final  bool qwenOptimizeInstructions;
@override@JsonKey() final  int groqSampleRate;
@override@JsonKey() final  String xaiLanguage;
@override@JsonKey() final  String xaiCodec;
@override@JsonKey() final  int xaiSampleRate;
@override@JsonKey() final  int xaiBitRate;
@override@JsonKey() final  bool xaiTextNormalization;
@override@JsonKey() final  int xaiOptimizeStreamingLatency;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TtsProviderSetting&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.name, name) || other.name == name)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.apiKey, apiKey) || other.apiKey == apiKey)&&(identical(other.baseUrl, baseUrl) || other.baseUrl == baseUrl)&&(identical(other.model, model) || other.model == model)&&(identical(other.voice, voice) || other.voice == voice)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.emotion, emotion) || other.emotion == emotion)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.languageBoost, languageBoost) || other.languageBoost == languageBoost)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.bitrate, bitrate) || other.bitrate == bitrate)&&(identical(other.audioFormat, audioFormat) || other.audioFormat == audioFormat)&&(identical(other.region, region) || other.region == region)&&(identical(other.azureRate, azureRate) || other.azureRate == azureRate)&&(identical(other.azurePitch, azurePitch) || other.azurePitch == azurePitch)&&(identical(other.azureVolume, azureVolume) || other.azureVolume == azureVolume)&&(identical(other.azureStyle, azureStyle) || other.azureStyle == azureStyle)&&(identical(other.azureStyleDegree, azureStyleDegree) || other.azureStyleDegree == azureStyleDegree)&&(identical(other.azureRole, azureRole) || other.azureRole == azureRole)&&(identical(other.azureOutputFormat, azureOutputFormat) || other.azureOutputFormat == azureOutputFormat)&&(identical(other.voiceName, voiceName) || other.voiceName == voiceName)&&(identical(other.stylePrompt, stylePrompt) || other.stylePrompt == stylePrompt)&&(identical(other.useMultiSpeaker, useMultiSpeaker) || other.useMultiSpeaker == useMultiSpeaker)&&(identical(other.speaker1Name, speaker1Name) || other.speaker1Name == speaker1Name)&&(identical(other.speaker1Voice, speaker1Voice) || other.speaker1Voice == speaker1Voice)&&(identical(other.speaker2Name, speaker2Name) || other.speaker2Name == speaker2Name)&&(identical(other.speaker2Voice, speaker2Voice) || other.speaker2Voice == speaker2Voice)&&(identical(other.outputFormat, outputFormat) || other.outputFormat == outputFormat)&&(identical(other.stability, stability) || other.stability == stability)&&(identical(other.similarityBoost, similarityBoost) || other.similarityBoost == similarityBoost)&&(identical(other.elStyle, elStyle) || other.elStyle == elStyle)&&(identical(other.useSpeakerBoost, useSpeakerBoost) || other.useSpeakerBoost == useSpeakerBoost)&&(identical(other.appId, appId) || other.appId == appId)&&(identical(other.cluster, cluster) || other.cluster == cluster)&&(identical(other.apiVersion, apiVersion) || other.apiVersion == apiVersion)&&(identical(other.resourceId, resourceId) || other.resourceId == resourceId)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.encoding, encoding) || other.encoding == encoding)&&(identical(other.gain, gain) || other.gain == gain)&&(identical(other.maxTokens, maxTokens) || other.maxTokens == maxTokens)&&(identical(other.instructions, instructions) || other.instructions == instructions)&&(identical(other.mimoVoiceDescription, mimoVoiceDescription) || other.mimoVoiceDescription == mimoVoiceDescription)&&(identical(other.mimoOptimizeTextPreview, mimoOptimizeTextPreview) || other.mimoOptimizeTextPreview == mimoOptimizeTextPreview)&&(identical(other.mimoVoiceCloneAudio, mimoVoiceCloneAudio) || other.mimoVoiceCloneAudio == mimoVoiceCloneAudio)&&(identical(other.qwenLanguageType, qwenLanguageType) || other.qwenLanguageType == qwenLanguageType)&&(identical(other.qwenInstructions, qwenInstructions) || other.qwenInstructions == qwenInstructions)&&(identical(other.qwenOptimizeInstructions, qwenOptimizeInstructions) || other.qwenOptimizeInstructions == qwenOptimizeInstructions)&&(identical(other.groqSampleRate, groqSampleRate) || other.groqSampleRate == groqSampleRate)&&(identical(other.xaiLanguage, xaiLanguage) || other.xaiLanguage == xaiLanguage)&&(identical(other.xaiCodec, xaiCodec) || other.xaiCodec == xaiCodec)&&(identical(other.xaiSampleRate, xaiSampleRate) || other.xaiSampleRate == xaiSampleRate)&&(identical(other.xaiBitRate, xaiBitRate) || other.xaiBitRate == xaiBitRate)&&(identical(other.xaiTextNormalization, xaiTextNormalization) || other.xaiTextNormalization == xaiTextNormalization)&&(identical(other.xaiOptimizeStreamingLatency, xaiOptimizeStreamingLatency) || other.xaiOptimizeStreamingLatency == xaiOptimizeStreamingLatency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,kind,name,enabled,apiKey,baseUrl,model,voice,groupId,emotion,speed,languageBoost,sampleRate,bitrate,audioFormat,region,azureRate,azurePitch,azureVolume,azureStyle,azureStyleDegree,azureRole,azureOutputFormat,voiceName,stylePrompt,useMultiSpeaker,speaker1Name,speaker1Voice,speaker2Name,speaker2Voice,outputFormat,stability,similarityBoost,elStyle,useSpeakerBoost,appId,cluster,apiVersion,resourceId,volume,pitch,encoding,gain,maxTokens,instructions,mimoVoiceDescription,mimoOptimizeTextPreview,mimoVoiceCloneAudio,qwenLanguageType,qwenInstructions,qwenOptimizeInstructions,groqSampleRate,xaiLanguage,xaiCodec,xaiSampleRate,xaiBitRate,xaiTextNormalization,xaiOptimizeStreamingLatency]);

@override
String toString() {
  return 'TtsProviderSetting(id: $id, kind: $kind, name: $name, enabled: $enabled, apiKey: $apiKey, baseUrl: $baseUrl, model: $model, voice: $voice, groupId: $groupId, emotion: $emotion, speed: $speed, languageBoost: $languageBoost, sampleRate: $sampleRate, bitrate: $bitrate, audioFormat: $audioFormat, region: $region, azureRate: $azureRate, azurePitch: $azurePitch, azureVolume: $azureVolume, azureStyle: $azureStyle, azureStyleDegree: $azureStyleDegree, azureRole: $azureRole, azureOutputFormat: $azureOutputFormat, voiceName: $voiceName, stylePrompt: $stylePrompt, useMultiSpeaker: $useMultiSpeaker, speaker1Name: $speaker1Name, speaker1Voice: $speaker1Voice, speaker2Name: $speaker2Name, speaker2Voice: $speaker2Voice, outputFormat: $outputFormat, stability: $stability, similarityBoost: $similarityBoost, elStyle: $elStyle, useSpeakerBoost: $useSpeakerBoost, appId: $appId, cluster: $cluster, apiVersion: $apiVersion, resourceId: $resourceId, volume: $volume, pitch: $pitch, encoding: $encoding, gain: $gain, maxTokens: $maxTokens, instructions: $instructions, mimoVoiceDescription: $mimoVoiceDescription, mimoOptimizeTextPreview: $mimoOptimizeTextPreview, mimoVoiceCloneAudio: $mimoVoiceCloneAudio, qwenLanguageType: $qwenLanguageType, qwenInstructions: $qwenInstructions, qwenOptimizeInstructions: $qwenOptimizeInstructions, groqSampleRate: $groqSampleRate, xaiLanguage: $xaiLanguage, xaiCodec: $xaiCodec, xaiSampleRate: $xaiSampleRate, xaiBitRate: $xaiBitRate, xaiTextNormalization: $xaiTextNormalization, xaiOptimizeStreamingLatency: $xaiOptimizeStreamingLatency)';
}


}

/// @nodoc
abstract mixin class _$TtsProviderSettingCopyWith<$Res> implements $TtsProviderSettingCopyWith<$Res> {
  factory _$TtsProviderSettingCopyWith(_TtsProviderSetting value, $Res Function(_TtsProviderSetting) _then) = __$TtsProviderSettingCopyWithImpl;
@override @useResult
$Res call({
 String id, TtsProviderKind kind, String name, bool enabled, String apiKey, String baseUrl, String model, String voice, String groupId, String emotion, double speed, String languageBoost, int sampleRate, int bitrate, String audioFormat, String region, String azureRate, String azurePitch, String azureVolume, String azureStyle, double azureStyleDegree, String azureRole, String azureOutputFormat, String voiceName, String stylePrompt, bool useMultiSpeaker, String speaker1Name, String speaker1Voice, String speaker2Name, String speaker2Voice, String outputFormat, double stability, double similarityBoost, double elStyle, bool useSpeakerBoost, String appId, String cluster, String apiVersion, String resourceId, double volume, double pitch, String encoding, double gain, int maxTokens, String instructions, String mimoVoiceDescription, bool mimoOptimizeTextPreview, String mimoVoiceCloneAudio, String qwenLanguageType, String qwenInstructions, bool qwenOptimizeInstructions, int groqSampleRate, String xaiLanguage, String xaiCodec, int xaiSampleRate, int xaiBitRate, bool xaiTextNormalization, int xaiOptimizeStreamingLatency
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? name = null,Object? enabled = null,Object? apiKey = null,Object? baseUrl = null,Object? model = null,Object? voice = null,Object? groupId = null,Object? emotion = null,Object? speed = null,Object? languageBoost = null,Object? sampleRate = null,Object? bitrate = null,Object? audioFormat = null,Object? region = null,Object? azureRate = null,Object? azurePitch = null,Object? azureVolume = null,Object? azureStyle = null,Object? azureStyleDegree = null,Object? azureRole = null,Object? azureOutputFormat = null,Object? voiceName = null,Object? stylePrompt = null,Object? useMultiSpeaker = null,Object? speaker1Name = null,Object? speaker1Voice = null,Object? speaker2Name = null,Object? speaker2Voice = null,Object? outputFormat = null,Object? stability = null,Object? similarityBoost = null,Object? elStyle = null,Object? useSpeakerBoost = null,Object? appId = null,Object? cluster = null,Object? apiVersion = null,Object? resourceId = null,Object? volume = null,Object? pitch = null,Object? encoding = null,Object? gain = null,Object? maxTokens = null,Object? instructions = null,Object? mimoVoiceDescription = null,Object? mimoOptimizeTextPreview = null,Object? mimoVoiceCloneAudio = null,Object? qwenLanguageType = null,Object? qwenInstructions = null,Object? qwenOptimizeInstructions = null,Object? groqSampleRate = null,Object? xaiLanguage = null,Object? xaiCodec = null,Object? xaiSampleRate = null,Object? xaiBitRate = null,Object? xaiTextNormalization = null,Object? xaiOptimizeStreamingLatency = null,}) {
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
as double,languageBoost: null == languageBoost ? _self.languageBoost : languageBoost // ignore: cast_nullable_to_non_nullable
as String,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,bitrate: null == bitrate ? _self.bitrate : bitrate // ignore: cast_nullable_to_non_nullable
as int,audioFormat: null == audioFormat ? _self.audioFormat : audioFormat // ignore: cast_nullable_to_non_nullable
as String,region: null == region ? _self.region : region // ignore: cast_nullable_to_non_nullable
as String,azureRate: null == azureRate ? _self.azureRate : azureRate // ignore: cast_nullable_to_non_nullable
as String,azurePitch: null == azurePitch ? _self.azurePitch : azurePitch // ignore: cast_nullable_to_non_nullable
as String,azureVolume: null == azureVolume ? _self.azureVolume : azureVolume // ignore: cast_nullable_to_non_nullable
as String,azureStyle: null == azureStyle ? _self.azureStyle : azureStyle // ignore: cast_nullable_to_non_nullable
as String,azureStyleDegree: null == azureStyleDegree ? _self.azureStyleDegree : azureStyleDegree // ignore: cast_nullable_to_non_nullable
as double,azureRole: null == azureRole ? _self.azureRole : azureRole // ignore: cast_nullable_to_non_nullable
as String,azureOutputFormat: null == azureOutputFormat ? _self.azureOutputFormat : azureOutputFormat // ignore: cast_nullable_to_non_nullable
as String,voiceName: null == voiceName ? _self.voiceName : voiceName // ignore: cast_nullable_to_non_nullable
as String,stylePrompt: null == stylePrompt ? _self.stylePrompt : stylePrompt // ignore: cast_nullable_to_non_nullable
as String,useMultiSpeaker: null == useMultiSpeaker ? _self.useMultiSpeaker : useMultiSpeaker // ignore: cast_nullable_to_non_nullable
as bool,speaker1Name: null == speaker1Name ? _self.speaker1Name : speaker1Name // ignore: cast_nullable_to_non_nullable
as String,speaker1Voice: null == speaker1Voice ? _self.speaker1Voice : speaker1Voice // ignore: cast_nullable_to_non_nullable
as String,speaker2Name: null == speaker2Name ? _self.speaker2Name : speaker2Name // ignore: cast_nullable_to_non_nullable
as String,speaker2Voice: null == speaker2Voice ? _self.speaker2Voice : speaker2Voice // ignore: cast_nullable_to_non_nullable
as String,outputFormat: null == outputFormat ? _self.outputFormat : outputFormat // ignore: cast_nullable_to_non_nullable
as String,stability: null == stability ? _self.stability : stability // ignore: cast_nullable_to_non_nullable
as double,similarityBoost: null == similarityBoost ? _self.similarityBoost : similarityBoost // ignore: cast_nullable_to_non_nullable
as double,elStyle: null == elStyle ? _self.elStyle : elStyle // ignore: cast_nullable_to_non_nullable
as double,useSpeakerBoost: null == useSpeakerBoost ? _self.useSpeakerBoost : useSpeakerBoost // ignore: cast_nullable_to_non_nullable
as bool,appId: null == appId ? _self.appId : appId // ignore: cast_nullable_to_non_nullable
as String,cluster: null == cluster ? _self.cluster : cluster // ignore: cast_nullable_to_non_nullable
as String,apiVersion: null == apiVersion ? _self.apiVersion : apiVersion // ignore: cast_nullable_to_non_nullable
as String,resourceId: null == resourceId ? _self.resourceId : resourceId // ignore: cast_nullable_to_non_nullable
as String,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,encoding: null == encoding ? _self.encoding : encoding // ignore: cast_nullable_to_non_nullable
as String,gain: null == gain ? _self.gain : gain // ignore: cast_nullable_to_non_nullable
as double,maxTokens: null == maxTokens ? _self.maxTokens : maxTokens // ignore: cast_nullable_to_non_nullable
as int,instructions: null == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String,mimoVoiceDescription: null == mimoVoiceDescription ? _self.mimoVoiceDescription : mimoVoiceDescription // ignore: cast_nullable_to_non_nullable
as String,mimoOptimizeTextPreview: null == mimoOptimizeTextPreview ? _self.mimoOptimizeTextPreview : mimoOptimizeTextPreview // ignore: cast_nullable_to_non_nullable
as bool,mimoVoiceCloneAudio: null == mimoVoiceCloneAudio ? _self.mimoVoiceCloneAudio : mimoVoiceCloneAudio // ignore: cast_nullable_to_non_nullable
as String,qwenLanguageType: null == qwenLanguageType ? _self.qwenLanguageType : qwenLanguageType // ignore: cast_nullable_to_non_nullable
as String,qwenInstructions: null == qwenInstructions ? _self.qwenInstructions : qwenInstructions // ignore: cast_nullable_to_non_nullable
as String,qwenOptimizeInstructions: null == qwenOptimizeInstructions ? _self.qwenOptimizeInstructions : qwenOptimizeInstructions // ignore: cast_nullable_to_non_nullable
as bool,groqSampleRate: null == groqSampleRate ? _self.groqSampleRate : groqSampleRate // ignore: cast_nullable_to_non_nullable
as int,xaiLanguage: null == xaiLanguage ? _self.xaiLanguage : xaiLanguage // ignore: cast_nullable_to_non_nullable
as String,xaiCodec: null == xaiCodec ? _self.xaiCodec : xaiCodec // ignore: cast_nullable_to_non_nullable
as String,xaiSampleRate: null == xaiSampleRate ? _self.xaiSampleRate : xaiSampleRate // ignore: cast_nullable_to_non_nullable
as int,xaiBitRate: null == xaiBitRate ? _self.xaiBitRate : xaiBitRate // ignore: cast_nullable_to_non_nullable
as int,xaiTextNormalization: null == xaiTextNormalization ? _self.xaiTextNormalization : xaiTextNormalization // ignore: cast_nullable_to_non_nullable
as bool,xaiOptimizeStreamingLatency: null == xaiOptimizeStreamingLatency ? _self.xaiOptimizeStreamingLatency : xaiOptimizeStreamingLatency // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
