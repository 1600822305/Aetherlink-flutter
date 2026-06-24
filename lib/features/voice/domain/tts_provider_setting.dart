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
  @JsonValue('mimo')
  mimo,
  @JsonValue('qwen')
  qwen,
  @JsonValue('groq')
  groq,
  @JsonValue('xai')
  xai,
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
    @Default('') String languageBoost,
    @Default(32000) int sampleRate,
    @Default(128000) int bitrate,
    @Default('mp3') String audioFormat,
    // Azure-specific
    @Default('') String region,
    @Default('medium') String azureRate, // prosody rate
    @Default('medium') String azurePitch, // prosody pitch
    @Default('medium') String azureVolume, // prosody volume
    @Default('') String azureStyle, // express-as style
    @Default(1.0) double azureStyleDegree, // 0.01-2.0
    @Default('') String azureRole, // express-as role
    @Default('audio-16khz-128kbitrate-mono-mp3') String azureOutputFormat,
    // Gemini voiceName (distinct from generic `voice`)
    @Default('') String voiceName,
    // Gemini style prompt (natural language control of speech style)
    @Default('') String stylePrompt,
    // Gemini multi-speaker TTS
    @Default(false) bool useMultiSpeaker,
    @Default('') String speaker1Name,
    @Default('') String speaker1Voice,
    @Default('') String speaker2Name,
    @Default('') String speaker2Voice,
    // ElevenLabs
    @Default('') String outputFormat,
    @Default(0.5) double stability, // ElevenLabs voice stability [0,1]
    @Default(0.75) double similarityBoost, // ElevenLabs similarity [0,1]
    @Default(0.0) double elStyle, // ElevenLabs style exaggeration [0,1]
    @Default(true) bool useSpeakerBoost, // ElevenLabs speaker boost
    // Volcano-specific
    @Default('') String appId,
    @Default('') String cluster,
    @Default('auto') String apiVersion,
    @Default('') String resourceId,
    @Default(1.0) double volume,
    @Default(1.0) double pitch,
    @Default('mp3') String encoding,
    // SiliconFlow-specific
    @Default(0.0) double gain, // audio gain in dB, [-10, 10]
    @Default(1600) int maxTokens, // MOSS-TTSD max_tokens
    // OpenAI gpt-4o-mini-tts instructions (controls accent, tone, emotion, etc.)
    @Default('') String instructions,
    // MiMo-specific
    @Default('')
    String mimoVoiceDescription, // voice description for voicedesign model
    @Default(false)
    bool mimoOptimizeTextPreview, // polish text in voicedesign mode
    @Default('')
    String mimoVoiceCloneAudio, // base64 audio sample for voiceclone model
    // Qwen-specific
    @Default('Auto')
    String qwenLanguageType, // output language: Auto, Chinese, English, etc.
    @Default('')
    String qwenInstructions, // natural language instruction for instruct models
    @Default(false)
    bool
    qwenOptimizeInstructions, // rewrite instructions for better naturalness
    // Groq-specific
    @Default(24000)
    int groqSampleRate, // 8000/16000/22050/24000/32000/44100/48000
    // xAI-specific
    @Default('auto') String xaiLanguage, // BCP-47 language code or 'auto'
    @Default('mp3') String xaiCodec, // mp3/wav/pcm/mulaw/alaw
    @Default(24000) int xaiSampleRate, // output sample rate
    @Default(128000) int xaiBitRate, // output bit rate (for mp3)
    @Default(false)
    bool xaiTextNormalization, // normalize numbers/symbols to spoken form
    @Default(0)
    int xaiOptimizeStreamingLatency, // 0=best quality, 1/2=lower latency
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
    model: 'gemini-3.1-flash-tts-preview',
    voiceName: 'Kore',
  ),
  TtsProviderKind.minimax => const TtsProviderSetting(
    id: 'minimax',
    kind: TtsProviderKind.minimax,
    name: 'MiniMax TTS',
    baseUrl: 'https://api.minimaxi.chat',
    model: 'speech-2.8-hd',
    voice: 'female-tianmei',
    emotion: 'neutral',
    languageBoost: 'auto',
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
    voice: 'zh-CN-XiaoxiaoNeural',
    region: 'eastus',
    azureRate: 'medium',
    azurePitch: 'medium',
    azureVolume: 'medium',
    azureOutputFormat: 'audio-16khz-128kbitrate-mono-mp3',
  ),
  TtsProviderKind.elevenlabs => const TtsProviderSetting(
    id: 'elevenlabs',
    kind: TtsProviderKind.elevenlabs,
    name: 'ElevenLabs TTS',
    baseUrl: 'https://api.elevenlabs.io',
    model: 'eleven_multilingual_v2',
    voice: 'JBFqnCBsd6RMkjVDRZzb',
    outputFormat: 'mp3_44100_128',
    stability: 0.5,
    similarityBoost: 0.75,
    elStyle: 0.0,
    useSpeakerBoost: true,
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
  TtsProviderKind.mimo => const TtsProviderSetting(
    id: 'mimo',
    kind: TtsProviderKind.mimo,
    name: 'MiMo TTS',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    model: 'mimo-v2.5-tts',
    voice: 'mimo_default',
    audioFormat: 'wav',
  ),
  TtsProviderKind.qwen => const TtsProviderSetting(
    id: 'qwen',
    kind: TtsProviderKind.qwen,
    name: 'Qwen TTS',
    baseUrl: 'https://dashscope.aliyuncs.com/api/v1',
    model: 'qwen3-tts-flash',
    voice: 'Cherry',
    qwenLanguageType: 'Auto',
  ),
  TtsProviderKind.groq => const TtsProviderSetting(
    id: 'groq',
    kind: TtsProviderKind.groq,
    name: 'Groq TTS',
    baseUrl: 'https://api.groq.com/openai/v1',
    model: 'playai-tts',
    voice: 'Fritz-PlayAI',
    audioFormat: 'wav',
    groqSampleRate: 24000,
  ),
  TtsProviderKind.xai => const TtsProviderSetting(
    id: 'xai',
    kind: TtsProviderKind.xai,
    name: 'xAI TTS',
    baseUrl: 'https://api.x.ai/v1',
    voice: 'eve',
    xaiLanguage: 'auto',
    xaiCodec: 'mp3',
    xaiSampleRate: 24000,
    xaiBitRate: 128000,
  ),
};
