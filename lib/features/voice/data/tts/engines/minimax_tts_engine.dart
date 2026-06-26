import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// A voice entry returned by MiniMax's `/v1/get_voice` API.
class MiniMaxRemoteVoice {
  const MiniMaxRemoteVoice({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'system',
  });
  final String id;
  final String name;
  final String description;
  final String category; // system, cloned, generated
}

/// MiniMax TTS via T2A v2 endpoint.
/// Sends voice_setting (voice_id, speed, vol, pitch, emotion),
/// language_boost, and audio_setting (sample_rate, bitrate, format).
class MiniMaxTtsEngine extends TtsEngine {
  const MiniMaxTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final groupId = provider.groupId;
    final path = groupId.isNotEmpty
        ? '/v1/t2a_v2?GroupId=$groupId'
        : '/v1/t2a_v2';
    final url = joinUrl(provider.baseUrl, path);

    // Build voice_setting with all official parameters.
    final voiceSetting = <String, dynamic>{
      'voice_id': provider.voice,
      'speed': provider.speed,
      'vol': provider.volume,
      'pitch': provider.pitch.round(),
    };
    if (provider.emotion.isNotEmpty) {
      voiceSetting['emotion'] = provider.emotion;
    }

    // Build audio_setting.
    final audioFormat = provider.audioFormat.isNotEmpty
        ? provider.audioFormat
        : 'mp3';
    final audioSetting = <String, dynamic>{
      'sample_rate': provider.sampleRate > 0 ? provider.sampleRate : 32000,
      'bitrate': provider.bitrate > 0 ? provider.bitrate : 128000,
      'format': audioFormat,
      'channel': 1,
    };

    final body = <String, dynamic>{
      'model': provider.model,
      'text': text,
      'stream': false,
      'voice_setting': voiceSetting,
      'audio_setting': audioSetting,
      'output_format': 'hex',
    };

    // language_boost
    if (provider.languageBoost.isNotEmpty) {
      body['language_boost'] = provider.languageBoost;
    }

    final response = await dio.post<Map<String, dynamic>>(
      url,
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
      cancelToken: cancelToken,
    );

    final json = response.data!;
    final baseResp = json['base_resp'] as Map<String, dynamic>?;
    if (baseResp != null && baseResp['status_code'] != 0) {
      throw Exception(
        'MiniMax TTS: ${baseResp['status_msg'] ?? 'unknown error'}',
      );
    }
    final data = json['data'] as Map<String, dynamic>?;
    final audioHex = (data?['audio'] ?? '').toString();
    if (audioHex.isEmpty) throw Exception('MiniMax TTS: empty audio');

    // Determine MIME type based on audio format.
    final mimeType = switch (audioFormat) {
      'wav' => 'audio/wav',
      'pcm' => 'audio/pcm',
      'flac' => 'audio/flac',
      'opus' => 'audio/opus',
      _ => 'audio/mpeg',
    };
    return TtsSynthesisResult(bytes: hexToBytes(audioHex), mimeType: mimeType);
  }

  /// Fetches available MiniMax voices from the `/v1/get_voice` API.
  Future<List<MiniMaxRemoteVoice>> fetchVoices(
    TtsProviderSetting provider, {
    required Dio dio,
  }) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://api.minimaxi.chat';
    final groupId = provider.groupId;
    final path = groupId.isNotEmpty
        ? '/v1/get_voice?GroupId=$groupId'
        : '/v1/get_voice';
    final url = joinUrl(baseUrl, path);
    final response = await dio.post<Map<String, dynamic>>(
      url,
      data: {'voice_type': 'all'},
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        },
      ),
    );
    final json = response.data!;
    final baseResp = json['base_resp'] as Map<String, dynamic>?;
    if (baseResp != null && baseResp['status_code'] != 0) {
      throw Exception(
        'MiniMax get_voice: ${baseResp['status_msg'] ?? 'unknown error'}',
      );
    }
    final results = <MiniMaxRemoteVoice>[];
    // System voices
    final systemVoices = json['system_voice'] as List<dynamic>? ?? [];
    for (final v in systemVoices) {
      final m = v as Map<String, dynamic>;
      final id = (m['voice_id'] ?? '').toString();
      if (id.isEmpty) continue;
      final name = (m['voice_name'] ?? id).toString();
      final desc =
          (m['description'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .join('; ') ??
          '';
      results.add(
        MiniMaxRemoteVoice(
          id: id,
          name: name,
          description: desc,
          category: 'system',
        ),
      );
    }
    // Cloned voices
    final clonedVoices = json['voice_cloning'] as List<dynamic>? ?? [];
    for (final v in clonedVoices) {
      final m = v as Map<String, dynamic>;
      final id = (m['voice_id'] ?? '').toString();
      if (id.isEmpty) continue;
      results.add(
        MiniMaxRemoteVoice(
          id: id,
          name: id,
          description: '克隆音色',
          category: 'cloned',
        ),
      );
    }
    // Generated voices
    final genVoices = json['voice_generation'] as List<dynamic>? ?? [];
    for (final v in genVoices) {
      final m = v as Map<String, dynamic>;
      final id = (m['voice_id'] ?? '').toString();
      if (id.isEmpty) continue;
      results.add(
        MiniMaxRemoteVoice(
          id: id,
          name: id,
          description: '生成音色',
          category: 'generated',
        ),
      );
    }
    return results;
  }
}
