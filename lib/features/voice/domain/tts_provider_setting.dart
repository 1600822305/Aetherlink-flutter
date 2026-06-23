import 'package:freezed_annotation/freezed_annotation.dart';

part 'tts_provider_setting.freezed.dart';
part 'tts_provider_setting.g.dart';

/// The kind of TTS provider. Each maps to a different API endpoint and request
/// format. Combined from Kelivo (OpenAI/Gemini/MiniMax/Qwen/Groq/xAI/ElevenLabs/MiMo)
/// and AetherLink original (SiliconFlow/Azure/Volcano).
enum TtsProviderKind {
  @JsonValue('system')
  system,
  @JsonValue('openai')
  openai,
  @JsonValue('gemini')
  gemini,
  @JsonValue('minimax')
  minimax,
  @JsonValue('siliconflow')
  siliconflow,
  @JsonValue('azure')
  azure,
  @JsonValue('elevenlabs')
  elevenlabs,
  @JsonValue('volcano')
  volcano,
}

/// A single TTS provider's configuration — API key, base URL, model, voice,
/// and provider-specific extras. Uses a flat structure with nullable fields
/// (matching the project's freezed pattern) rather than sealed classes, so the
/// whole list serializes as one JSON blob in the Drift key/value store.
@freezed
abstract class TtsProviderSetting with _$TtsProviderSetting {
  const factory TtsProviderSetting({
    required String id,
    required TtsProviderKind kind,
    @Default('') String name,
    @Default(false) bool enabled,
    @Default('') String apiKey,
    @Default('') String baseUrl,
    @Default('') String model,
    @Default('') String voice,
    // MiniMax-specific
    @Default('') String groupId,
    @Default('') String emotion,
    @Default(1.0) double speed,
    // Azure-specific
    @Default('') String region,
    // Gemini voiceName (distinct from generic `voice`)
    @Default('') String voiceName,
    // ElevenLabs
    @Default('') String outputFormat,
    // Volcano-specific
    @Default('') String appId,
    @Default('') String cluster,
    @Default('auto') String apiVersion,
    @Default('') String resourceId,
    @Default(1.0) double volume,
    @Default(1.0) double pitch,
    @Default('mp3') String encoding,
    // OpenAI gpt-4o-mini-tts instructions (controls accent, tone, emotion, etc.)
    @Default('') String instructions,
  }) = _TtsProviderSetting;

  factory TtsProviderSetting.fromJson(Map<String, dynamic> json) =>
      _$TtsProviderSettingFromJson(json);
}

/// Default provider presets — one per kind with sensible endpoint defaults.
TtsProviderSetting defaultTtsProvider(TtsProviderKind kind) => switch (kind) {
  TtsProviderKind.system => const TtsProviderSetting(
    id: 'system',
    kind: TtsProviderKind.system,
    name: '系统 TTS',
    enabled: true,
  ),
  TtsProviderKind.openai => const TtsProviderSetting(
    id: 'openai',
    kind: TtsProviderKind.openai,
    name: 'OpenAI TTS',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini-tts',
    voice: 'alloy',
  ),
  TtsProviderKind.gemini => const TtsProviderSetting(
    id: 'gemini',
    kind: TtsProviderKind.gemini,
    name: 'Gemini TTS',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    model: 'gemini-2.5-flash-preview-tts',
    voiceName: 'Kore',
  ),
  TtsProviderKind.minimax => const TtsProviderSetting(
    id: 'minimax',
    kind: TtsProviderKind.minimax,
    name: 'MiniMax TTS',
    baseUrl: 'https://api.minimaxi.chat',
    model: 'speech-02-hd',
    voice: 'female-tianmei',
    emotion: 'neutral',
  ),
  TtsProviderKind.siliconflow => const TtsProviderSetting(
    id: 'siliconflow',
    kind: TtsProviderKind.siliconflow,
    name: '硅基流动 TTS',
    baseUrl: 'https://api.siliconflow.cn/v1',
    model: 'FunAudioLLM/CosyVoice2-0.5B',
    voice: 'alex',
  ),
  TtsProviderKind.azure => const TtsProviderSetting(
    id: 'azure',
    kind: TtsProviderKind.azure,
    name: 'Azure TTS',
    model: 'zh-CN-XiaoxiaoMultilingualNeural',
    voice: 'zh-CN-XiaoxiaoMultilingualNeural',
    region: 'eastus',
  ),
  TtsProviderKind.elevenlabs => const TtsProviderSetting(
    id: 'elevenlabs',
    kind: TtsProviderKind.elevenlabs,
    name: 'ElevenLabs TTS',
    baseUrl: 'https://api.elevenlabs.io',
    model: 'eleven_multilingual_v2',
    outputFormat: 'mp3_44100_128',
  ),
  TtsProviderKind.volcano => const TtsProviderSetting(
    id: 'volcano',
    kind: TtsProviderKind.volcano,
    name: '火山引擎 TTS',
    voice: 'BV001_streaming',
    cluster: 'volcano_tts',
    apiVersion: 'auto',
    encoding: 'mp3',
  ),
};
