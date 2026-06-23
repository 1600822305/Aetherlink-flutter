import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// The result of a network TTS synthesis call: raw audio bytes and their MIME
/// type so the player knows the codec.
class TtsSynthesisResult {
  const TtsSynthesisResult({
    required this.bytes,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String mimeType;
}

/// Network TTS service that calls cloud TTS APIs. Supports multiple providers
/// (OpenAI, Gemini, MiniMax, SiliconFlow, etc.). Each provider has a dedicated
/// `_synthesizeXxx` method that builds the correct request format.
///
/// Architecture adapted from Kelivo's `NetworkTtsService` but uses Dio (the
/// project's HTTP client) instead of `package:http`.
class NetworkTtsService {
  NetworkTtsService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Synthesizes [text] using the given [provider] configuration. Returns raw
  /// audio bytes. Throws on network or API errors.
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    CancelToken? cancelToken,
  }) async {
    return switch (provider.kind) {
      TtsProviderKind.openai => _synthesizeOpenAi(text, provider, cancelToken),
      TtsProviderKind.gemini => _synthesizeGemini(text, provider, cancelToken),
      TtsProviderKind.minimax => _synthesizeMiniMax(text, provider, cancelToken),
      TtsProviderKind.siliconflow =>
        _synthesizeSiliconFlow(text, provider, cancelToken),
      TtsProviderKind.elevenlabs =>
        _synthesizeElevenLabs(text, provider, cancelToken),
      TtsProviderKind.azure => _synthesizeAzure(text, provider, cancelToken),
      TtsProviderKind.volcano =>
        _synthesizeVolcano(text, provider, cancelToken),
      TtsProviderKind.system =>
        throw UnsupportedError('System TTS uses flutter_tts, not network'),
    };
  }

  /// OpenAI-compatible TTS.
  Future<TtsSynthesisResult> _synthesizeOpenAi(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final url = _joinUrl(provider.baseUrl, '/audio/speech');
    final format = provider.outputFormat.isNotEmpty
        ? provider.outputFormat
        : 'mp3';
    final response = await _dio.post<List<int>>(
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
      mimeType: _openAiMimeType(format),
    );
  }

  /// Gemini TTS via generateContent with audio modality.
  Future<TtsSynthesisResult> _synthesizeGemini(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final url = _joinUrl(
      provider.baseUrl,
      '/models/${provider.model}:generateContent',
    );
    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': provider.voiceName.isNotEmpty
                    ? provider.voiceName
                    : 'Kore',
              },
            },
          },
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
    final parts = ((candidates[0] as Map<String, dynamic>)['content']
        as Map<String, dynamic>)['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini TTS: empty audio parts');
    }
    final inline =
        (parts[0] as Map<String, dynamic>)['inlineData'] as Map<String, dynamic>?;
    if (inline == null) throw Exception('Gemini TTS: no inlineData');
    final dataB64 = (inline['data'] ?? '').toString();
    if (dataB64.isEmpty) throw Exception('Gemini TTS: empty audio data');
    final pcm = base64Decode(dataB64);
    final wav = _pcmToWav(Uint8List.fromList(pcm), sampleRate: 24000);
    return TtsSynthesisResult(bytes: wav, mimeType: 'audio/wav');
  }

  /// MiniMax TTS via T2A v2 endpoint.
  Future<TtsSynthesisResult> _synthesizeMiniMax(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final groupId = provider.groupId;
    final path = groupId.isNotEmpty
        ? '/v1/t2a_v2?GroupId=$groupId'
        : '/v1/t2a_v2';
    final url = _joinUrl(provider.baseUrl, path);
    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: {
        'model': provider.model,
        'text': text,
        'stream': false,
        'voice_setting': {
          'voice_id': provider.voice,
          'emotion': provider.emotion.isNotEmpty ? provider.emotion : 'neutral',
          'speed': provider.speed,
        },
      },
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
      throw Exception('MiniMax TTS: ${baseResp['status_msg'] ?? 'unknown error'}');
    }
    final data = json['data'] as Map<String, dynamic>?;
    final audioHex = (data?['audio'] ?? '').toString();
    if (audioHex.isEmpty) throw Exception('MiniMax TTS: empty audio');
    return TtsSynthesisResult(
      bytes: _hexToBytes(audioHex),
      mimeType: 'audio/mpeg',
    );
  }

  /// SiliconFlow TTS — uses OpenAI-compatible `/audio/speech` endpoint but
  /// requires `model:voiceName` format for the `voice` field.
  Future<TtsSynthesisResult> _synthesizeSiliconFlow(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final url = _joinUrl(provider.baseUrl, '/audio/speech');
    // SiliconFlow expects voice in `model:voiceName` format.
    var voice = provider.voice;
    if (voice.isNotEmpty && !voice.contains(':')) {
      voice = '${provider.model}:$voice';
    }
    final response = await _dio.post<List<int>>(
      url,
      data: {
        'model': provider.model,
        'input': text,
        'voice': voice,
        'response_format': 'mp3',
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
      mimeType: 'audio/mpeg',
    );
  }

  /// ElevenLabs TTS.
  Future<TtsSynthesisResult> _synthesizeElevenLabs(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final voiceId = provider.voice.isNotEmpty ? provider.voice : '21m00Tcm4TlvDq8ikWAM';
    final url = _joinUrl(
      provider.baseUrl,
      '/v1/text-to-speech/$voiceId',
    );
    final response = await _dio.post<List<int>>(
      url,
      data: {
        'text': text,
        'model_id': provider.model.isNotEmpty ? provider.model : 'eleven_multilingual_v2',
        'output_format': provider.outputFormat.isNotEmpty
            ? provider.outputFormat
            : 'mp3_44100_128',
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
      mimeType: 'audio/mpeg',
    );
  }

  /// Azure Cognitive Services TTS.
  Future<TtsSynthesisResult> _synthesizeAzure(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final region = provider.region.isNotEmpty ? provider.region : 'eastus';
    final url = 'https://$region.tts.speech.microsoft.com/'
        'cognitiveservices/v1';
    final voiceName = provider.voice.isNotEmpty
        ? provider.voice
        : 'zh-CN-XiaoxiaoMultilingualNeural';
    final ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
        'xml:lang="zh-CN">'
        '<voice name="$voiceName">${_escapeXml(text)}</voice></speak>';
    final response = await _dio.post<List<int>>(
      url,
      data: ssml,
      options: Options(
        headers: {
          'Ocp-Apim-Subscription-Key': provider.apiKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        },
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: 'audio/mpeg',
    );
  }

  // -- Volcano Engine --------------------------------------------------------

  /// Volcano TTS (ByteDance) — supports V1 (traditional BV voices) and V3
  /// (big-model voices / seed-tts-2.0). API version is auto-detected from the
  /// voice type unless explicitly set.
  Future<TtsSynthesisResult> _synthesizeVolcano(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final version = _resolveVolcanoApiVersion(provider);
    if (version == 'v3') {
      return _synthesizeVolcanoV3(text, provider, cancelToken);
    }
    return _synthesizeVolcanoV1(text, provider, cancelToken);
  }

  /// V1 HTTP non-streaming: `https://openspeech.bytedance.com/api/v1/tts`
  Future<TtsSynthesisResult> _synthesizeVolcanoV1(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
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
        'reqid': _generateUuid(),
        'text': text,
        'text_type': 'plain',
        'operation': 'query',
      },
    };

    final response = await _dio.post<Map<String, dynamic>>(
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
      mimeType: _volcanoMimeType(provider.encoding),
    );
  }

  /// V3 HTTP unidirectional streaming (big-model TTS):
  /// `https://openspeech.bytedance.com/api/v3/tts/unidirectional`
  /// Response is NDJSON; audio data in each line's `data` field (base64).
  Future<TtsSynthesisResult> _synthesizeVolcanoV3(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    const url = 'https://openspeech.bytedance.com/api/v3/tts/unidirectional';

    int toRate(double ratio) =>
        (((ratio - 1) * 100).clamp(-50, 100)).round();

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

    final resourceId = _getVolcanoResourceId(provider);

    final response = await _dio.post<String>(
      url,
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-Api-App-Id': provider.appId,
          'X-Api-Access-Key': provider.apiKey,
          'X-Api-Resource-Id': resourceId,
          'X-Api-Request-Id': _generateUuid(),
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
            errorMsg = '火山引擎 TTS V3 错误: ${chunk['message'] ?? ''} (code: $code)';
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
      mimeType: _volcanoMimeType(provider.encoding),
    );
  }

  static String _resolveVolcanoApiVersion(TtsProviderSetting provider) {
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

  static String _getVolcanoResourceId(TtsProviderSetting provider) {
    if (provider.resourceId.isNotEmpty) return provider.resourceId;
    if (provider.voice.contains('_uranus_')) return 'seed-tts-2.0';
    return 'volc.service_type.10029';
  }

  static String _openAiMimeType(String format) => switch (format) {
    'opus' => 'audio/ogg',
    'aac' => 'audio/aac',
    'flac' => 'audio/flac',
    'wav' => 'audio/wav',
    'pcm' => 'audio/pcm',
    _ => 'audio/mpeg',
  };

  static String _volcanoMimeType(String encoding) => switch (encoding) {
    'ogg_opus' => 'audio/ogg',
    'wav' => 'audio/wav',
    'pcm' => 'audio/pcm',
    _ => 'audio/mpeg',
  };

  static String _generateUuid() {
    final r = DateTime.now().microsecondsSinceEpoch;
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
      RegExp('[xy]'),
      (m) {
        final c = m.group(0)!;
        final v = (r + (DateTime.now().microsecond * 16)).abs() % 16;
        final d = c == 'x' ? v : (v & 0x3 | 0x8);
        return d.toRadixString(16);
      },
    );
  }

  // -- Helpers ---------------------------------------------------------------

  static String _joinUrl(String base, String path) {
    final trimmed = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$trimmed$path';
  }

  static String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  /// Wraps raw PCM data in a WAV header.
  static Uint8List _pcmToWav(
    Uint8List pcm, {
    int sampleRate = 24000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    // RIFF header
    buffer.setUint8(0, 0x52); // R
    buffer.setUint8(1, 0x49); // I
    buffer.setUint8(2, 0x46); // F
    buffer.setUint8(3, 0x46); // F
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // W
    buffer.setUint8(9, 0x41); // A
    buffer.setUint8(10, 0x56); // V
    buffer.setUint8(11, 0x45); // E
    // fmt sub-chunk
    buffer.setUint8(12, 0x66); // f
    buffer.setUint8(13, 0x6d); // m
    buffer.setUint8(14, 0x74); // t
    buffer.setUint8(15, 0x20); // (space)
    buffer.setUint32(16, 16, Endian.little); // sub-chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    // data sub-chunk
    buffer.setUint8(36, 0x64); // d
    buffer.setUint8(37, 0x61); // a
    buffer.setUint8(38, 0x74); // t
    buffer.setUint8(39, 0x61); // a
    buffer.setUint32(40, dataSize, Endian.little);
    // PCM data
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(44, 44 + dataSize, pcm);
    return bytes;
  }
}
