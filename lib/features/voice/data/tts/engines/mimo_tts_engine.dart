import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// MiMo TTS via chat completions format (api.xiaomimimo.com).
///
/// Three model variants:
/// - mimo-v2.5-tts: Preset voice synthesis
/// - mimo-v2.5-tts-voicedesign: Voice design from description
/// - mimo-v2.5-tts-voiceclone: Clone from audio sample
///
/// Auth: `api-key` header (not Authorization: Bearer)
class MimoTtsEngine extends TtsEngine {
  const MimoTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://api.xiaomimimo.com/v1';
    final url = joinUrl(baseUrl, '/chat/completions');

    final model = provider.model.isNotEmpty ? provider.model : 'mimo-v2.5-tts';
    final voice = provider.voice.isNotEmpty ? provider.voice : 'mimo_default';
    final format = provider.audioFormat.isNotEmpty
        ? provider.audioFormat
        : 'wav';

    // Build messages array
    final messages = <Map<String, dynamic>>[];

    // For voicedesign model, a user message with voice description is required
    if (model.contains('voicedesign') &&
        provider.mimoVoiceDescription.isNotEmpty) {
      messages.add({'role': 'user', 'content': provider.mimoVoiceDescription});
    }

    // Assistant message contains the text to synthesize
    // Style prefix: (style)text format for emotion/style control
    String assistantContent = text;
    if (provider.stylePrompt.isNotEmpty) {
      assistantContent = '(${provider.stylePrompt})$text';
    }
    messages.add({'role': 'assistant', 'content': assistantContent});

    // Build audio settings
    final audioSettings = <String, dynamic>{'format': format};

    // Voice selection for preset model
    if (!model.contains('voicedesign') && !model.contains('voiceclone')) {
      audioSettings['voice'] = voice;
    }

    // Voice clone: attach audio reference
    if (model.contains('voiceclone') &&
        provider.mimoVoiceCloneAudio.isNotEmpty) {
      audioSettings['voice_clone_audio'] = provider.mimoVoiceCloneAudio;
    }

    // Sample rate (if non-default)
    if (provider.sampleRate > 0 && provider.sampleRate != 32000) {
      audioSettings['sample_rate'] = provider.sampleRate;
    }

    // Speed control
    if (provider.speed != 1.0) {
      audioSettings['speed'] = provider.speed;
    }

    // Build request body
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'audio': audioSettings,
      'stream': false,
    };

    // optimize_text_preview for voicedesign mode
    if (model.contains('voicedesign') && provider.mimoOptimizeTextPreview) {
      body['optimize_text_preview'] = true;
    }

    final response = await dio.post<Map<String, dynamic>>(
      url,
      data: body,
      options: Options(
        headers: {
          'api-key': provider.apiKey,
          'Content-Type': 'application/json',
        },
      ),
      cancelToken: cancelToken,
    );

    final json = response.data!;

    // Parse response: audio data is in choices[0].message.audio.data (base64)
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('MiMo TTS: empty choices in response');
    }
    final message =
        (choices[0] as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
    if (message == null) {
      throw Exception('MiMo TTS: no message in response');
    }
    final audio = message['audio'] as Map<String, dynamic>?;
    if (audio == null) {
      throw Exception('MiMo TTS: no audio in response');
    }
    final audioData = (audio['data'] ?? '').toString();
    if (audioData.isEmpty) {
      throw Exception('MiMo TTS: empty audio data');
    }

    // Decode base64 audio
    final audioBytes = base64Decode(audioData);

    // Determine MIME type based on format
    final mimeType = switch (format) {
      'wav' => 'audio/wav',
      'pcm16' => 'audio/pcm',
      'mp3' => 'audio/mpeg',
      _ => 'audio/wav',
    };

    return TtsSynthesisResult(
      bytes: Uint8List.fromList(audioBytes),
      mimeType: mimeType,
    );
  }
}
