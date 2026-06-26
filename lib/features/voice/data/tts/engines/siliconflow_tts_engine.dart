import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// SiliconFlow TTS — uses OpenAI-compatible `/audio/speech` endpoint.
/// Builds model-specific request bodies for CosyVoice2 / Fish-Speech /
/// IndexTTS-2 / MOSS-TTSD.
class SiliconFlowTtsEngine extends TtsEngine {
  const SiliconFlowTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final url = joinUrl(provider.baseUrl, '/audio/speech');
    // SiliconFlow expects voice in `model:voiceName` format.
    var voice = provider.voice;
    if (voice.isNotEmpty && !voice.contains(':')) {
      voice = '${provider.model}:$voice';
    }

    final isMossTTSD = provider.model == 'fnlp/MOSS-TTSD-v0.5';
    final isIndexTTS2 = provider.model == 'IndexTeam/IndexTTS-2';
    final hasAdvancedParams = isMossTTSD || isIndexTTS2;

    final audioFormat = provider.audioFormat.isNotEmpty
        ? provider.audioFormat
        : 'mp3';

    final body = <String, dynamic>{
      'model': provider.model,
      'input': text,
      'voice': voice,
      'response_format': audioFormat,
    };

    // speed and gain for MOSS-TTSD / IndexTTS-2 (official API range)
    if (hasAdvancedParams) {
      body['speed'] = provider.speed;
      body['gain'] = provider.gain;
    }

    // max_tokens for MOSS-TTSD only
    if (isMossTTSD) {
      body['max_tokens'] = provider.maxTokens > 0 ? provider.maxTokens : 1600;
    }

    // sample_rate (format-dependent)
    if (provider.sampleRate > 0) {
      body['sample_rate'] = provider.sampleRate;
    }

    final response = await dio.post<List<int>>(
      url,
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );

    final mimeType = switch (audioFormat) {
      'wav' => 'audio/wav',
      'pcm' => 'audio/pcm',
      'opus' => 'audio/opus',
      _ => 'audio/mpeg',
    };
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: mimeType,
    );
  }
}
