// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VoiceSettings {

/// Whether TTS is globally enabled.
 bool get enableTts;/// The active TTS provider id (matches a [TtsProviderSetting.id]).
 String get activeTtsProviderId;/// Configured TTS providers.
 List<TtsProviderSetting> get ttsProviders;/// Whether ASR is globally enabled.
 bool get enableAsr;/// The active ASR provider id (matches an [AsrProviderSetting.id]).
 String get activeAsrProviderId;/// Configured ASR providers.
 List<AsrProviderSetting> get asrProviders;/// Default TTS playback speed (0.5 - 2.0).
 double get defaultSpeed;
/// Create a copy of VoiceSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceSettingsCopyWith<VoiceSettings> get copyWith => _$VoiceSettingsCopyWithImpl<VoiceSettings>(this as VoiceSettings, _$identity);

  /// Serializes this VoiceSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceSettings&&(identical(other.enableTts, enableTts) || other.enableTts == enableTts)&&(identical(other.activeTtsProviderId, activeTtsProviderId) || other.activeTtsProviderId == activeTtsProviderId)&&const DeepCollectionEquality().equals(other.ttsProviders, ttsProviders)&&(identical(other.enableAsr, enableAsr) || other.enableAsr == enableAsr)&&(identical(other.activeAsrProviderId, activeAsrProviderId) || other.activeAsrProviderId == activeAsrProviderId)&&const DeepCollectionEquality().equals(other.asrProviders, asrProviders)&&(identical(other.defaultSpeed, defaultSpeed) || other.defaultSpeed == defaultSpeed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enableTts,activeTtsProviderId,const DeepCollectionEquality().hash(ttsProviders),enableAsr,activeAsrProviderId,const DeepCollectionEquality().hash(asrProviders),defaultSpeed);

@override
String toString() {
  return 'VoiceSettings(enableTts: $enableTts, activeTtsProviderId: $activeTtsProviderId, ttsProviders: $ttsProviders, enableAsr: $enableAsr, activeAsrProviderId: $activeAsrProviderId, asrProviders: $asrProviders, defaultSpeed: $defaultSpeed)';
}


}

/// @nodoc
abstract mixin class $VoiceSettingsCopyWith<$Res>  {
  factory $VoiceSettingsCopyWith(VoiceSettings value, $Res Function(VoiceSettings) _then) = _$VoiceSettingsCopyWithImpl;
@useResult
$Res call({
 bool enableTts, String activeTtsProviderId, List<TtsProviderSetting> ttsProviders, bool enableAsr, String activeAsrProviderId, List<AsrProviderSetting> asrProviders, double defaultSpeed
});




}
/// @nodoc
class _$VoiceSettingsCopyWithImpl<$Res>
    implements $VoiceSettingsCopyWith<$Res> {
  _$VoiceSettingsCopyWithImpl(this._self, this._then);

  final VoiceSettings _self;
  final $Res Function(VoiceSettings) _then;

/// Create a copy of VoiceSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enableTts = null,Object? activeTtsProviderId = null,Object? ttsProviders = null,Object? enableAsr = null,Object? activeAsrProviderId = null,Object? asrProviders = null,Object? defaultSpeed = null,}) {
  return _then(_self.copyWith(
enableTts: null == enableTts ? _self.enableTts : enableTts // ignore: cast_nullable_to_non_nullable
as bool,activeTtsProviderId: null == activeTtsProviderId ? _self.activeTtsProviderId : activeTtsProviderId // ignore: cast_nullable_to_non_nullable
as String,ttsProviders: null == ttsProviders ? _self.ttsProviders : ttsProviders // ignore: cast_nullable_to_non_nullable
as List<TtsProviderSetting>,enableAsr: null == enableAsr ? _self.enableAsr : enableAsr // ignore: cast_nullable_to_non_nullable
as bool,activeAsrProviderId: null == activeAsrProviderId ? _self.activeAsrProviderId : activeAsrProviderId // ignore: cast_nullable_to_non_nullable
as String,asrProviders: null == asrProviders ? _self.asrProviders : asrProviders // ignore: cast_nullable_to_non_nullable
as List<AsrProviderSetting>,defaultSpeed: null == defaultSpeed ? _self.defaultSpeed : defaultSpeed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceSettings].
extension VoiceSettingsPatterns on VoiceSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceSettings value)  $default,){
final _that = this;
switch (_that) {
case _VoiceSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceSettings value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enableTts,  String activeTtsProviderId,  List<TtsProviderSetting> ttsProviders,  bool enableAsr,  String activeAsrProviderId,  List<AsrProviderSetting> asrProviders,  double defaultSpeed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceSettings() when $default != null:
return $default(_that.enableTts,_that.activeTtsProviderId,_that.ttsProviders,_that.enableAsr,_that.activeAsrProviderId,_that.asrProviders,_that.defaultSpeed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enableTts,  String activeTtsProviderId,  List<TtsProviderSetting> ttsProviders,  bool enableAsr,  String activeAsrProviderId,  List<AsrProviderSetting> asrProviders,  double defaultSpeed)  $default,) {final _that = this;
switch (_that) {
case _VoiceSettings():
return $default(_that.enableTts,_that.activeTtsProviderId,_that.ttsProviders,_that.enableAsr,_that.activeAsrProviderId,_that.asrProviders,_that.defaultSpeed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enableTts,  String activeTtsProviderId,  List<TtsProviderSetting> ttsProviders,  bool enableAsr,  String activeAsrProviderId,  List<AsrProviderSetting> asrProviders,  double defaultSpeed)?  $default,) {final _that = this;
switch (_that) {
case _VoiceSettings() when $default != null:
return $default(_that.enableTts,_that.activeTtsProviderId,_that.ttsProviders,_that.enableAsr,_that.activeAsrProviderId,_that.asrProviders,_that.defaultSpeed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoiceSettings implements VoiceSettings {
  const _VoiceSettings({this.enableTts = true, this.activeTtsProviderId = 'system', final  List<TtsProviderSetting> ttsProviders = const <TtsProviderSetting>[], this.enableAsr = true, this.activeAsrProviderId = 'system', final  List<AsrProviderSetting> asrProviders = const <AsrProviderSetting>[], this.defaultSpeed = 1.0}): _ttsProviders = ttsProviders,_asrProviders = asrProviders;
  factory _VoiceSettings.fromJson(Map<String, dynamic> json) => _$VoiceSettingsFromJson(json);

/// Whether TTS is globally enabled.
@override@JsonKey() final  bool enableTts;
/// The active TTS provider id (matches a [TtsProviderSetting.id]).
@override@JsonKey() final  String activeTtsProviderId;
/// Configured TTS providers.
 final  List<TtsProviderSetting> _ttsProviders;
/// Configured TTS providers.
@override@JsonKey() List<TtsProviderSetting> get ttsProviders {
  if (_ttsProviders is EqualUnmodifiableListView) return _ttsProviders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ttsProviders);
}

/// Whether ASR is globally enabled.
@override@JsonKey() final  bool enableAsr;
/// The active ASR provider id (matches an [AsrProviderSetting.id]).
@override@JsonKey() final  String activeAsrProviderId;
/// Configured ASR providers.
 final  List<AsrProviderSetting> _asrProviders;
/// Configured ASR providers.
@override@JsonKey() List<AsrProviderSetting> get asrProviders {
  if (_asrProviders is EqualUnmodifiableListView) return _asrProviders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_asrProviders);
}

/// Default TTS playback speed (0.5 - 2.0).
@override@JsonKey() final  double defaultSpeed;

/// Create a copy of VoiceSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceSettingsCopyWith<_VoiceSettings> get copyWith => __$VoiceSettingsCopyWithImpl<_VoiceSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoiceSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceSettings&&(identical(other.enableTts, enableTts) || other.enableTts == enableTts)&&(identical(other.activeTtsProviderId, activeTtsProviderId) || other.activeTtsProviderId == activeTtsProviderId)&&const DeepCollectionEquality().equals(other._ttsProviders, _ttsProviders)&&(identical(other.enableAsr, enableAsr) || other.enableAsr == enableAsr)&&(identical(other.activeAsrProviderId, activeAsrProviderId) || other.activeAsrProviderId == activeAsrProviderId)&&const DeepCollectionEquality().equals(other._asrProviders, _asrProviders)&&(identical(other.defaultSpeed, defaultSpeed) || other.defaultSpeed == defaultSpeed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,enableTts,activeTtsProviderId,const DeepCollectionEquality().hash(_ttsProviders),enableAsr,activeAsrProviderId,const DeepCollectionEquality().hash(_asrProviders),defaultSpeed);

@override
String toString() {
  return 'VoiceSettings(enableTts: $enableTts, activeTtsProviderId: $activeTtsProviderId, ttsProviders: $ttsProviders, enableAsr: $enableAsr, activeAsrProviderId: $activeAsrProviderId, asrProviders: $asrProviders, defaultSpeed: $defaultSpeed)';
}


}

/// @nodoc
abstract mixin class _$VoiceSettingsCopyWith<$Res> implements $VoiceSettingsCopyWith<$Res> {
  factory _$VoiceSettingsCopyWith(_VoiceSettings value, $Res Function(_VoiceSettings) _then) = __$VoiceSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool enableTts, String activeTtsProviderId, List<TtsProviderSetting> ttsProviders, bool enableAsr, String activeAsrProviderId, List<AsrProviderSetting> asrProviders, double defaultSpeed
});




}
/// @nodoc
class __$VoiceSettingsCopyWithImpl<$Res>
    implements _$VoiceSettingsCopyWith<$Res> {
  __$VoiceSettingsCopyWithImpl(this._self, this._then);

  final _VoiceSettings _self;
  final $Res Function(_VoiceSettings) _then;

/// Create a copy of VoiceSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enableTts = null,Object? activeTtsProviderId = null,Object? ttsProviders = null,Object? enableAsr = null,Object? activeAsrProviderId = null,Object? asrProviders = null,Object? defaultSpeed = null,}) {
  return _then(_VoiceSettings(
enableTts: null == enableTts ? _self.enableTts : enableTts // ignore: cast_nullable_to_non_nullable
as bool,activeTtsProviderId: null == activeTtsProviderId ? _self.activeTtsProviderId : activeTtsProviderId // ignore: cast_nullable_to_non_nullable
as String,ttsProviders: null == ttsProviders ? _self._ttsProviders : ttsProviders // ignore: cast_nullable_to_non_nullable
as List<TtsProviderSetting>,enableAsr: null == enableAsr ? _self.enableAsr : enableAsr // ignore: cast_nullable_to_non_nullable
as bool,activeAsrProviderId: null == activeAsrProviderId ? _self.activeAsrProviderId : activeAsrProviderId // ignore: cast_nullable_to_non_nullable
as String,asrProviders: null == asrProviders ? _self._asrProviders : asrProviders // ignore: cast_nullable_to_non_nullable
as List<AsrProviderSetting>,defaultSpeed: null == defaultSpeed ? _self.defaultSpeed : defaultSpeed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
