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
  @JsonValue('volcengine')
  volcengine,
  @JsonValue('mimo')
  mimo,
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
    // Volcengine (字节火山引擎大模型流式语音识别) specific
    @Default('') String appKey, // X-Api-App-Key (旧版控制台 APP ID)
    @Default('') String accessKey, // X-Api-Access-Key (旧版控制台 Access Token)
    @Default('volc.bigasr.sauc.duration')
    String resourceId, // X-Api-Resource-Id
    @Default(true) bool enableItn, // 文本规范化 (ITN)
    @Default(true) bool enablePunc, // 标点
    @Default(false) bool enableDdc, // 语义顺滑
    @Default(800) int endWindowSize, // 强制判停时间 (ms)，最小 200
    @Default('') String outputZhVariant, // ''/traditional/tw/hk
    // MiMo (小米 mimo-v2.5-asr) specific. HTTP 分段上传 (OpenAI 兼容 chat)
    @Default(30) int segmentDurationSec, // 自动分段上传间隔 (秒)，0 表示禁用分段
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
  AsrProviderKind.volcengine => const AsrProviderSetting(
    id: 'volcengine',
    kind: AsrProviderKind.volcengine,
    name: '火山引擎 ASR',
    websocketUrl: 'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel',
    model: 'bigmodel',
    resourceId: 'volc.bigasr.sauc.duration',
    sampleRate: 16000,
  ),
  AsrProviderKind.mimo => const AsrProviderSetting(
    id: 'mimo',
    kind: AsrProviderKind.mimo,
    name: 'MiMo ASR',
    baseUrl: 'https://api.xiaomimimo.com/v1',
    model: 'mimo-v2.5-asr',
    language: 'auto',
    sampleRate: 16000,
    segmentDurationSec: 30,
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
