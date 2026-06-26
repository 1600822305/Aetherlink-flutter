import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// A voice entry returned by ElevenLabs' `/v1/voices` API.
class ElevenLabsRemoteVoice {
  const ElevenLabsRemoteVoice({
    required this.id,
    required this.name,
    this.category = 'premade',
  });
  final String id;
  final String name;
  final String category; // premade, cloned, generated, professional
}

/// ElevenLabs TTS — `output_format` is a **URL query parameter** (not body).
/// `voice_settings` controls stability / similarity / style / speed.
class ElevenLabsTtsEngine extends TtsEngine {
  const ElevenLabsTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final voiceId = provider.voice.isNotEmpty
        ? provider.voice
        : 'JBFqnCBsd6RMkjVDRZzb';
    final outputFmt = provider.outputFormat.isNotEmpty
        ? provider.outputFormat
        : 'mp3_44100_128';
    final url =
        '${joinUrl(provider.baseUrl, '/v1/text-to-speech/$voiceId')}'
        '?output_format=$outputFmt';

    final voiceSettings = <String, dynamic>{
      'stability': provider.stability,
      'similarity_boost': provider.similarityBoost,
      'style': provider.elStyle,
      'use_speaker_boost': provider.useSpeakerBoost,
    };
    if (provider.speed != 1.0) {
      voiceSettings['speed'] = provider.speed;
    }

    final response = await dio.post<List<int>>(
      url,
      data: {
        'text': text,
        'model_id': provider.model.isNotEmpty
            ? provider.model
            : 'eleven_multilingual_v2',
        'voice_settings': voiceSettings,
      },
      options: Options(
        headers: {
          'xi-api-key': provider.apiKey,
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: _mimeType(outputFmt),
    );
  }

  /// Fetch dynamic voice list from ElevenLabs `/v1/voices` API.
  Future<List<ElevenLabsRemoteVoice>> fetchVoices(
    TtsProviderSetting provider, {
    required Dio dio,
  }) async {
    final url = joinUrl(provider.baseUrl, '/v1/voices');
    try {
      final response = await dio.get<Map<String, dynamic>>(
        url,
        options: Options(headers: {'xi-api-key': provider.apiKey}),
      );
      final voices = response.data?['voices'] as List<dynamic>? ?? [];
      return voices.map((v) {
        final m = v as Map<String, dynamic>;
        return ElevenLabsRemoteVoice(
          id: m['voice_id'] as String? ?? '',
          name: m['name'] as String? ?? '',
          category: m['category'] as String? ?? 'premade',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static String _mimeType(String format) {
    if (format.startsWith('mp3_')) return 'audio/mpeg';
    if (format.startsWith('pcm_')) return 'audio/wav';
    if (format.startsWith('ulaw_')) return 'audio/basic';
    if (format.startsWith('alaw_')) return 'audio/basic';
    if (format.startsWith('opus_')) return 'audio/opus';
    if (format.startsWith('wav_')) return 'audio/wav';
    return 'audio/mpeg';
  }
}
