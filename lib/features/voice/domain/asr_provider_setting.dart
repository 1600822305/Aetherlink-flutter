import 'package:freezed_annotation/freezed_annotation.dart';

part 'asr_provider_setting.freezed.dart';
part 'asr_provider_setting.g.dart';

/// The kind of ASR (Automatic Speech Recognition) provider.
/// Combined from RikkaHub (OpenAI Realtime/DashScope/Volcengine) and
/// AetherLink original (Whisper).
enum AsrProviderKind {
  @JsonValue('system')
  system,
  @JsonValue('openai_realtime')
  openaiRealtime,
  @JsonValue('dashscope')
  dashscope,
  @JsonValue('whisper')
  whisper,
}

/// A single ASR provider's configuration.
@freezed
abstract class AsrProviderSetting with _$AsrProviderSetting {
  const factory AsrProviderSetting({
    required String id,
    required AsrProviderKind kind,
    @Default('') String name,
    @Default(false) bool enabled,
    @Default('') String apiKey,
    @Default('') String baseUrl,
    @Default('') String model,
    @Default('') String language,
    // OpenAI Realtime WebSocket URL
    @Default('') String websocketUrl,
    // Whisper-specific
    @Default('') String responseFormat,
    @Default(0.0) double temperature, // Whisper temperature [0,1]
    @Default('') String prompt, // Whisper/Realtime prompt for domain vocabulary
    // VAD threshold (0.0-1.0)
    @Default(0.5) double vadThreshold,
    @Default(500) int silenceDurationMs,
    @Default(300) int prefixPaddingMs, // VAD prefix padding (ms)
    // Realtime delay (latency/accuracy tradeoff)
    @Default('') String realtimeDelay, // minimal/low/medium/high/xhigh
    // DashScope (Qwen-ASR-Realtime) specific
    @Default(16000) int sampleRate, // 16000 / 8000
    @Default('pcm') String inputAudioFormat, // pcm / opus
    @Default('') String corpusText, // contextual biasing text (<=10000 tokens)
    @Default(true) bool useVad, // VAD mode (true) vs manual mode (false)
  }) = _AsrProviderSetting;

  factory AsrProviderSetting.fromJson(Map<String, dynamic> json) =>
      _$AsrProviderSettingFromJson(json);
}

/// Default provider presets for ASR.
AsrProviderSetting defaultAsrProvider(AsrProviderKind kind) => switch (kind) {
  AsrProviderKind.system => const AsrProviderSetting(
    id: 'system',
    kind: AsrProviderKind.system,
    name: '系统语音识别',
    enabled: true,
  ),
  AsrProviderKind.openaiRealtime => const AsrProviderSetting(
    id: 'openai_realtime',
    kind: AsrProviderKind.openaiRealtime,
    name: 'OpenAI Realtime ASR',
    websocketUrl: 'wss://api.openai.com/v1/realtime?intent=transcription',
    model: 'gpt-4o-transcribe',
    realtimeDelay: 'medium',
  ),
  AsrProviderKind.dashscope => const AsrProviderSetting(
    id: 'dashscope',
    kind: AsrProviderKind.dashscope,
    name: 'DashScope ASR',
    websocketUrl: 'wss://dashscope.aliyuncs.com/api-ws/v1/realtime',
    model: 'qwen3-asr-flash-realtime',
    sampleRate: 16000,
    inputAudioFormat: 'pcm',
    vadThreshold: 0.2,
    silenceDurationMs: 800,
  ),
  AsrProviderKind.whisper => const AsrProviderSetting(
    id: 'whisper',
    kind: AsrProviderKind.whisper,
    name: 'OpenAI Whisper',
    baseUrl: 'https://api.openai.com/v1',
    model: 'whisper-1',
    responseFormat: 'json',
  ),
};
