import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// OpenAI-compatible TTS (`/audio/speech`).
class OpenAiTtsEngine extends TtsEngine {
  const OpenAiTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final url = joinUrl(provider.baseUrl, '/audio/speech');
    final format = provider.outputFormat.isNotEmpty
        ? provider.outputFormat
        : 'mp3';
    final response = await dio.post<List<int>>(
      url,
      data: {
        'model': provider.model,
        'input': text,
        'voice': provider.voice,
        if (provider.speed != 1.0) 'speed': provider.speed,
        'response_format': format,
        if (provider.instructions.isNotEmpty)
          'instructions': provider.instructions,
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
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: _mimeType(format),
    );
  }

  static String _mimeType(String format) => switch (format) {
    'opus' => 'audio/ogg',
    'aac' => 'audio/aac',
    'flac' => 'audio/flac',
    'wav' => 'audio/wav',
    'pcm' => 'audio/pcm',
    _ => 'audio/mpeg',
  };
}
