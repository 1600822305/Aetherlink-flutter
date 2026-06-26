import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// xAI (Grok) TTS — POST /v1/tts, returns raw audio bytes.
class XaiTtsEngine extends TtsEngine {
  const XaiTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final url = joinUrl(provider.baseUrl, '/tts');
    final codec = provider.xaiCodec.isNotEmpty ? provider.xaiCodec : 'mp3';
    final response = await dio.post<List<int>>(
      url,
      data: {
        'text': text,
        'voice_id': provider.voice,
        'language': provider.xaiLanguage,
        if (codec != 'mp3' ||
            provider.xaiSampleRate != 24000 ||
            provider.xaiBitRate != 128000)
          'output_format': {
            'codec': codec,
            'sample_rate': provider.xaiSampleRate,
            'bit_rate': provider.xaiBitRate,
          },
        if (provider.speed != 1.0) 'speed': provider.speed,
        if (provider.xaiTextNormalization) 'text_normalization': true,
        if (provider.xaiOptimizeStreamingLatency > 0)
          'optimize_streaming_latency': provider.xaiOptimizeStreamingLatency,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );
    final mimeType = switch (codec) {
      'wav' => 'audio/wav',
      'pcm' => 'audio/pcm',
      'mulaw' => 'audio/basic',
      'alaw' => 'audio/basic',
      _ => 'audio/mpeg',
    };
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: mimeType,
    );
  }
}
