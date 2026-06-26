import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/azure_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/elevenlabs_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/gemini_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/groq_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/mimo_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/minimax_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/openai_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/qwen_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/siliconflow_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/volcano_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/xai_tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

// Re-export engine types so existing consumers keep importing them from here.
export 'package:aetherlink_flutter/features/voice/data/tts/engines/azure_tts_engine.dart'
    show AzureRemoteVoice;
export 'package:aetherlink_flutter/features/voice/data/tts/engines/elevenlabs_tts_engine.dart'
    show ElevenLabsRemoteVoice;
export 'package:aetherlink_flutter/features/voice/data/tts/engines/minimax_tts_engine.dart'
    show MiniMaxRemoteVoice;
export 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart'
    show TtsEngine, TtsSynthesisResult;

/// Network TTS dispatcher. Selects the right [TtsEngine] based on the
/// provider's [TtsProviderKind] and delegates synthesis / voice-fetching to it.
///
/// Each provider lives in its own engine file under `engines/`. This class is
/// a thin registry/factory keeping a stable public API for callers.
class NetworkTtsService {
  NetworkTtsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const Map<TtsProviderKind, TtsEngine> _engines = {
    TtsProviderKind.openai: OpenAiTtsEngine(),
    TtsProviderKind.gemini: GeminiTtsEngine(),
    TtsProviderKind.minimax: MiniMaxTtsEngine(),
    TtsProviderKind.siliconflow: SiliconFlowTtsEngine(),
    TtsProviderKind.elevenlabs: ElevenLabsTtsEngine(),
    TtsProviderKind.azure: AzureTtsEngine(),
    TtsProviderKind.volcano: VolcanoTtsEngine(),
    TtsProviderKind.mimo: MimoTtsEngine(),
    TtsProviderKind.qwen: QwenTtsEngine(),
    TtsProviderKind.groq: GroqTtsEngine(),
    TtsProviderKind.xai: XaiTtsEngine(),
  };

  /// Synthesizes [text] using the given [provider] configuration. Returns raw
  /// audio bytes. Throws on network or API errors.
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    CancelToken? cancelToken,
  }) {
    if (provider.kind == TtsProviderKind.system) {
      throw UnsupportedError('System TTS uses flutter_tts, not network');
    }
    final engine = _engines[provider.kind];
    if (engine == null) {
      throw UnsupportedError('No TTS engine for ${provider.kind}');
    }
    return engine.synthesize(
      text,
      provider,
      dio: _dio,
      cancelToken: cancelToken,
    );
  }

  /// Fetches available MiniMax voices from the `/v1/get_voice` API.
  Future<List<MiniMaxRemoteVoice>> fetchMiniMaxVoices(
    TtsProviderSetting provider,
  ) {
    return const MiniMaxTtsEngine().fetchVoices(provider, dio: _dio);
  }

  /// Fetches the dynamic voice list from ElevenLabs `/v1/voices` API.
  Future<List<ElevenLabsRemoteVoice>> fetchElevenLabsVoices(
    TtsProviderSetting provider,
  ) {
    return const ElevenLabsTtsEngine().fetchVoices(provider, dio: _dio);
  }

  /// Fetches the dynamic voice list from Azure
  /// `/cognitiveservices/voices/list` API.
  Future<List<AzureRemoteVoice>> fetchAzureVoices(TtsProviderSetting provider) {
    return const AzureTtsEngine().fetchVoices(provider, dio: _dio);
  }
}
