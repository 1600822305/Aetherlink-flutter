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
        _synthesizeOpenAi(text, provider, cancelToken),
      TtsProviderKind.elevenlabs =>
        _synthesizeElevenLabs(text, provider, cancelToken),
      TtsProviderKind.azure => _synthesizeAzure(text, provider, cancelToken),
      TtsProviderKind.volcano =>
        _synthesizeOpenAi(text, provider, cancelToken),
      TtsProviderKind.system =>
        throw UnsupportedError('System TTS uses flutter_tts, not network'),
    };
  }

  /// OpenAI-compatible TTS (also works for SiliconFlow and Volcano which use
  /// the same `/audio/speech` endpoint format).
  Future<TtsSynthesisResult> _synthesizeOpenAi(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final url = _joinUrl(provider.baseUrl, '/audio/speech');
    final response = await _dio.post<List<int>>(
      url,
      data: {
        'model': provider.model,
        'input': text,
        'voice': provider.voice,
        if (provider.speed != 1.0) 'speed': provider.speed,
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

  /// MiniMax TTS via streaming SSE endpoint.
  Future<TtsSynthesisResult> _synthesizeMiniMax(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final url = _joinUrl(provider.baseUrl, '/t2a_v2');
    final response = await _dio.post<String>(
      url,
      data: {
        'model': provider.model,
        'text': text,
        'stream': false,
        'voice_setting': {
          'voice_id': provider.voice,
          'emotion': provider.emotion.isNotEmpty ? provider.emotion : 'calm',
          'speed': provider.speed,
        },
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.json,
      ),
      cancelToken: cancelToken,
    );

    final json = response.data is String
        ? jsonDecode(response.data as String) as Map<String, dynamic>
        : response.data as Map<String, dynamic>;
    final data = json['data'] as Map<String, dynamic>?;
    final audioHex = (data?['audio'] ?? '').toString();
    if (audioHex.isEmpty) throw Exception('MiniMax TTS: empty audio');
    return TtsSynthesisResult(
      bytes: _hexToBytes(audioHex),
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
