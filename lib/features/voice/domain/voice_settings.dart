import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

part 'voice_settings.freezed.dart';
part 'voice_settings.g.dart';

/// The persisted voice settings: which TTS/ASR providers are configured, which
/// one is currently active, and global TTS preferences. Stored as a single JSON
/// blob in the Drift key/value store, following the project's `JsonKvNotifier`
/// pattern.
@freezed
abstract class VoiceSettings with _$VoiceSettings {
  const factory VoiceSettings({
    /// Whether TTS is globally enabled.
    @Default(true) bool enableTts,
    /// The active TTS provider id (matches a [TtsProviderSetting.id]).
    @Default('system') String activeTtsProviderId,
    /// Configured TTS providers.
    @Default(<TtsProviderSetting>[]) List<TtsProviderSetting> ttsProviders,
    /// Whether ASR is globally enabled.
    @Default(true) bool enableAsr,
    /// The active ASR provider id (matches an [AsrProviderSetting.id]).
    @Default('system') String activeAsrProviderId,
    /// Configured ASR providers.
    @Default(<AsrProviderSetting>[]) List<AsrProviderSetting> asrProviders,
    /// Default TTS playback speed (0.5 - 2.0).
    @Default(1.0) double defaultSpeed,
  }) = _VoiceSettings;

  factory VoiceSettings.fromJson(Map<String, dynamic> json) =>
      _$VoiceSettingsFromJson(json);
}
