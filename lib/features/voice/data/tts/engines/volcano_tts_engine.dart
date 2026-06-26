import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// Volcano TTS (ByteDance) — supports V1 (traditional BV voices) and V3
/// (big-model voices / seed-tts-2.0). API version is auto-detected from the
/// voice type unless explicitly set.
class VolcanoTtsEngine extends TtsEngine {
  const VolcanoTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final version = _resolveApiVersion(provider);
    if (version == 'v3') {
      return _synthesizeV3(text, provider, dio: dio, cancelToken: cancelToken);
    }
    return _synthesizeV1(text, provider, dio: dio, cancelToken: cancelToken);
  }

  /// V1 HTTP non-streaming: `https://openspeech.bytedance.com/api/v1/tts`
  Future<TtsSynthesisResult> _synthesizeV1(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    const url = 'https://openspeech.bytedance.com/api/v1/tts';
    final cluster = provider.cluster.isNotEmpty
        ? provider.cluster
        : 'volcano_tts';

    final body = {
      'app': {
        'appid': provider.appId,
        'token': provider.apiKey,
        'cluster': cluster,
      },
      'user': {'uid': 'aetherlink_user'},
      'audio': {
        'voice_type': provider.voice,
        'encoding': provider.encoding.isNotEmpty ? provider.encoding : 'mp3',
        'speed_ratio': provider.speed,
        'volume_ratio': provider.volume,
        'pitch_ratio': provider.pitch,
        if (provider.emotion.isNotEmpty) 'emotion': provider.emotion,
      },
      'request': {
        'reqid': generateUuid(),
        'text': text,
        'text_type': 'plain',
        'operation': 'query',
      },
    };

    final response = await dio.post<Map<String, dynamic>>(
      url,
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer;${provider.apiKey}',
        },
      ),
      cancelToken: cancelToken,
    );

    final json = response.data!;
    final code = json['code'] as int?;
    if (code != 3000) {
      throw Exception(
        '火山引擎 TTS V1 错误: ${json['message'] ?? '未知错误'} (code: $code)',
      );
    }

    final dataB64 = (json['data'] ?? '').toString();
    if (dataB64.isEmpty) throw Exception('火山引擎 TTS V1: 未收到音频数据');

    return TtsSynthesisResult(
      bytes: base64Decode(dataB64),
      mimeType: _mimeType(provider.encoding),
    );
  }

  /// V3 HTTP unidirectional streaming (big-model TTS):
  /// `https://openspeech.bytedance.com/api/v3/tts/unidirectional`
  /// Response is NDJSON; audio data in each line's `data` field (base64).
  Future<TtsSynthesisResult> _synthesizeV3(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    const url = 'https://openspeech.bytedance.com/api/v3/tts/unidirectional';

    int toRate(double ratio) => (((ratio - 1) * 100).clamp(-50, 100)).round();

    final audioParams = <String, dynamic>{
      'format': provider.encoding.isNotEmpty ? provider.encoding : 'mp3',
      'sample_rate': 24000,
      'speech_rate': toRate(provider.speed),
      'loudness_rate': toRate(provider.volume),
      if (provider.emotion.isNotEmpty) 'emotion': provider.emotion,
    };

    final reqParams = <String, dynamic>{
      'text': text,
      'speaker': provider.voice,
      'audio_params': audioParams,
      if (provider.model.isNotEmpty) 'model': provider.model,
    };

    final body = {
      'user': {'uid': 'aetherlink_user'},
      'req_params': reqParams,
    };

    final resourceId = _getResourceId(provider);

    final response = await dio.post<String>(
      url,
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Api-App-Id': provider.appId,
          'X-Api-Access-Key': provider.apiKey,
          'X-Api-Resource-Id': resourceId,
          'X-Api-Request-Id': generateUuid(),
        },
        responseType: ResponseType.plain,
      ),
      cancelToken: cancelToken,
    );

    final lines = (response.data ?? '').split('\n');
    final audioChunks = <Uint8List>[];
    String? errorMsg;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final chunk = jsonDecode(trimmed) as Map<String, dynamic>;
        final data = chunk['data'];
        if (data != null && data.toString().isNotEmpty) {
          audioChunks.add(base64Decode(data.toString()));
        } else {
          final code = chunk['code'];
          if (code != null && code != 0 && code != 20000000) {
            errorMsg =
                '火山引擎 TTS V3 错误: ${chunk['message'] ?? ''} (code: $code)';
          }
        }
      } catch (_) {
        // skip unparseable lines
      }
    }

    if (audioChunks.isEmpty) {
      throw Exception(errorMsg ?? '火山引擎 TTS V3: 未收到音频数据');
    }

    // Merge chunks.
    final totalLen = audioChunks.fold<int>(0, (s, c) => s + c.length);
    final merged = Uint8List(totalLen);
    var offset = 0;
    for (final chunk in audioChunks) {
      merged.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return TtsSynthesisResult(
      bytes: merged,
      mimeType: _mimeType(provider.encoding),
    );
  }

  static String _resolveApiVersion(TtsProviderSetting provider) {
    final v = provider.apiVersion;
    if (v == 'v1' || v == 'v3') return v;
    // Auto: big-model voices use V3, traditional BV voices use V1.
    final voice = provider.voice;
    if (voice.contains('_bigtts') ||
        voice.startsWith('ICL_') ||
        voice.startsWith('S_') ||
        voice.contains('_uranus_')) {
      return 'v3';
    }
    return 'v1';
  }

  static String _getResourceId(TtsProviderSetting provider) {
    if (provider.resourceId.isNotEmpty) return provider.resourceId;
    if (provider.voice.contains('_uranus_')) return 'seed-tts-2.0';
    return 'volc.service_type.10029';
  }

  static String _mimeType(String encoding) => switch (encoding) {
    'ogg_opus' => 'audio/ogg',
    'wav' => 'audio/wav',
    'pcm' => 'audio/pcm',
    _ => 'audio/mpeg',
  };
}
