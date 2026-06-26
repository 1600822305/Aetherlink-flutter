import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// Qwen TTS (通义千问) via DashScope multimodal-generation endpoint.
///
/// Two model variants:
/// - qwen3-tts-flash: Basic text-to-speech synthesis
/// - qwen3-tts-instruct-flash: Supports natural language instructions for
///   expressiveness control (speech rate, intonation, emotion)
///
/// Uses SSE streaming: response returns base64-encoded PCM chunks which are
/// concatenated and wrapped in a WAV header (24000Hz mono 16-bit).
class QwenTtsEngine extends TtsEngine {
  const QwenTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://dashscope.aliyuncs.com/api/v1';
    final url = joinUrl(
      baseUrl,
      '/services/aigc/multimodal-generation/generation',
    );

    final model = provider.model.isNotEmpty
        ? provider.model
        : 'qwen3-tts-flash';
    final voice = provider.voice.isNotEmpty ? provider.voice : 'Cherry';
    final languageType = provider.qwenLanguageType.isNotEmpty
        ? provider.qwenLanguageType
        : 'Auto';

    // Build input parameters
    final input = <String, dynamic>{
      'text': text,
      'voice': voice,
      'language_type': languageType,
    };

    // Instructions and optimize_instructions only for instruct models
    if (model.contains('instruct') && provider.qwenInstructions.isNotEmpty) {
      input['instructions'] = provider.qwenInstructions;
      if (provider.qwenOptimizeInstructions) {
        input['optimize_instructions'] = true;
      }
    }

    // Speed control (Qwen supports speed via the API)
    if (provider.speed != 1.0) {
      input['speed'] = provider.speed;
    }

    final body = <String, dynamic>{'model': model, 'input': input};

    // Use SSE streaming mode
    final response = await dio.post<String>(
      url,
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
          'X-DashScope-SSE': 'enable',
        },
        responseType: ResponseType.plain,
      ),
      cancelToken: cancelToken,
    );

    final responseText = response.data ?? '';
    if (responseText.isEmpty) {
      throw Exception('Qwen TTS: 未收到响应数据');
    }

    // Parse SSE stream: lines starting with "data:" contain JSON payloads
    final buf = BytesBuilder(copy: false);
    final lines = responseText.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      try {
        final obj = jsonDecode(payload) as Map<String, dynamic>;
        // Check for API errors
        final code = obj['code'] as String?;
        if (code != null && code.isNotEmpty) {
          final message = obj['message'] ?? 'unknown error';
          throw Exception('Qwen TTS 错误: $message (code: $code)');
        }
        final output = obj['output'] as Map<String, dynamic>?;
        final audio = output?['audio'] as Map<String, dynamic>?;
        final dataB64 = (audio?['data'] ?? '').toString();
        if (dataB64.isNotEmpty) {
          buf.add(base64Decode(dataB64));
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('Qwen TTS')) {
          rethrow;
        }
        // Skip unparseable lines
      }
    }

    final pcm = buf.takeBytes();
    if (pcm.isEmpty) {
      throw Exception('Qwen TTS: 未收到音频数据');
    }

    // Convert PCM to WAV at 24000Hz sample rate
    return TtsSynthesisResult(
      bytes: pcmToWav(Uint8List.fromList(pcm), sampleRate: 24000),
      mimeType: 'audio/wav',
    );
  }
}
