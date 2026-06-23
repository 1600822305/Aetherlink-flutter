import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

/// HTTP-based ASR using OpenAI Whisper (or compatible) endpoint. Records audio,
/// then POSTs the file to `/audio/transcriptions` for a full transcript.
///
/// Supported models: whisper-1, gpt-4o-transcribe, gpt-4o-mini-transcribe.
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

    final format = provider.responseFormat.isNotEmpty
        ? provider.responseFormat
        : 'json';

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(audioBytes, filename: fileName),
      'model': provider.model.isNotEmpty ? provider.model : 'whisper-1',
      if (provider.language.isNotEmpty) 'language': provider.language,
      'response_format': format,
      'temperature': provider.temperature.toString(),
      if (provider.prompt.isNotEmpty) 'prompt': provider.prompt,
    });

    // When response_format is 'text', 'srt', or 'vtt', the API returns plain
    // text instead of JSON. We must handle both cases.
    final isPlainText = format == 'text' || format == 'srt' || format == 'vtt';

    final response = await _dio.post<dynamic>(
      url,
      data: formData,
      options: Options(
        headers: {'Authorization': 'Bearer ${provider.apiKey}'},
        responseType: isPlainText ? ResponseType.plain : ResponseType.json,
      ),
      cancelToken: cancelToken,
    );

    if (isPlainText) {
      return (response.data ?? '').toString().trim();
    }

    final json = response.data as Map<String, dynamic>;
    return (json['text'] ?? '').toString();
  }
}
