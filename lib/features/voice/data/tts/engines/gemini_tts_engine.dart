import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// Gemini TTS via generateContent with audio modality.
/// Supports single-speaker, multi-speaker (up to 2), and style prompts.
class GeminiTtsEngine extends TtsEngine {
  const GeminiTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final url = joinUrl(
      provider.baseUrl,
      '/models/${provider.model}:generateContent',
    );

    // Build the input text — prepend style prompt if present.
    final inputText = provider.stylePrompt.isNotEmpty
        ? '${provider.stylePrompt}\n$text'
        : text;

    // Build speechConfig — multi-speaker or single-speaker.
    final Map<String, dynamic> speechConfig;
    if (provider.useMultiSpeaker &&
        provider.speaker1Name.isNotEmpty &&
        provider.speaker1Voice.isNotEmpty) {
      final speakers = <Map<String, dynamic>>[
        {
          'speaker': provider.speaker1Name,
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': provider.speaker1Voice},
          },
        },
      ];
      if (provider.speaker2Name.isNotEmpty &&
          provider.speaker2Voice.isNotEmpty) {
        speakers.add({
          'speaker': provider.speaker2Name,
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': provider.speaker2Voice},
          },
        });
      }
      speechConfig = {
        'multiSpeakerVoiceConfig': {'speakerVoiceConfigs': speakers},
      };
    } else {
      speechConfig = {
        'voiceConfig': {
          'prebuiltVoiceConfig': {
            'voiceName': provider.voiceName.isNotEmpty
                ? provider.voiceName
                : 'Kore',
          },
        },
      };
    }

    final response = await dio.post<Map<String, dynamic>>(
      url,
      data: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': inputText},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': speechConfig,
        },
        'model': provider.model,
      },
      options: Options(
        headers: {
          'x-goog-api-key': provider.apiKey,
          'Content-Type': 'application/json',
        },
      ),
      cancelToken: cancelToken,
    );

    final json = response.data!;
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini TTS: empty candidates');
    }
    final parts =
        ((candidates[0] as Map<String, dynamic>)['content']
                as Map<String, dynamic>)['parts']
            as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini TTS: empty audio parts');
    }
    final inline =
        (parts[0] as Map<String, dynamic>)['inlineData']
            as Map<String, dynamic>?;
    if (inline == null) throw Exception('Gemini TTS: no inlineData');
    final dataB64 = (inline['data'] ?? '').toString();
    if (dataB64.isEmpty) throw Exception('Gemini TTS: empty audio data');
    final pcm = base64Decode(dataB64);
    final wav = pcmToWav(Uint8List.fromList(pcm), sampleRate: 24000);
    return TtsSynthesisResult(bytes: wav, mimeType: 'audio/wav');
  }
}
