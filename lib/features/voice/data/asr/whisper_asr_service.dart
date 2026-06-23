import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

/// HTTP-based ASR using OpenAI Whisper (or compatible) endpoint. Records audio,
/// then POSTs the file to `/audio/transcriptions` for a full transcript.
/// Ported from AetherLink original's `OpenAIWhisperService`.
class WhisperAsrService {
  WhisperAsrService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Transcribes [audioBytes] (expected to be in WAV/MP3/M4A format) using the
  /// given [provider] configuration. Returns the recognized text.
  Future<String> transcribe(
    Uint8List audioBytes,
    AsrProviderSetting provider, {
    String fileName = 'audio.wav',
    CancelToken? cancelToken,
  }) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://api.openai.com/v1';
    final url = baseUrl.endsWith('/')
        ? '${baseUrl}audio/transcriptions'
        : '$baseUrl/audio/transcriptions';

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(audioBytes, filename: fileName),
      'model': provider.model.isNotEmpty ? provider.model : 'whisper-1',
      if (provider.language.isNotEmpty) 'language': provider.language,
      'response_format': provider.responseFormat.isNotEmpty
          ? provider.responseFormat
          : 'json',
    });

    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
        },
      ),
      cancelToken: cancelToken,
    );

    final json = response.data!;
    return (json['text'] ?? '').toString();
  }
}
