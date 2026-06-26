import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// Groq PlayAI TTS — OpenAI-compatible endpoint.
class GroqTtsEngine extends TtsEngine {
  const GroqTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final url = joinUrl(provider.baseUrl, '/audio/speech');
    final format = provider.audioFormat.isNotEmpty
        ? provider.audioFormat
        : 'wav';
    final response = await dio.post<List<int>>(
      url,
      data: {
        'model': provider.model,
        'input': text,
        'voice': provider.voice,
        'response_format': format,
        if (provider.groqSampleRate != 24000)
          'sample_rate': provider.groqSampleRate,
        if (provider.speed != 1.0) 'speed': provider.speed,
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
    final mimeType = switch (format) {
      'mp3' => 'audio/mpeg',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'mulaw' => 'audio/basic',
      _ => 'audio/wav',
    };
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: mimeType,
    );
  }
}
