import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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

/// A voice entry returned by Azure's `/cognitiveservices/voices/list` API.
class AzureRemoteVoice {
  const AzureRemoteVoice({
    required this.shortName,
    required this.displayName,
    this.localName = '',
    this.locale = '',
    this.gender = '',
    this.styleList = const [],
    this.rolePlayList = const [],
  });
  final String shortName;
  final String displayName;
  final String localName;
  final String locale;
  final String gender;
  final List<String> styleList;
  final List<String> rolePlayList;
}

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

/// The result of a network TTS synthesis call: raw audio bytes and their MIME
/// type so the player knows the codec.
class TtsSynthesisResult {
  const TtsSynthesisResult({required this.bytes, required this.mimeType});

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
      TtsProviderKind.minimax => _synthesizeMiniMax(
        text,
        provider,
        cancelToken,
      ),
      TtsProviderKind.siliconflow => _synthesizeSiliconFlow(
        text,
        provider,
        cancelToken,
      ),
      TtsProviderKind.elevenlabs => _synthesizeElevenLabs(
        text,
        provider,
        cancelToken,
      ),
      TtsProviderKind.azure => _synthesizeAzure(text, provider, cancelToken),
      TtsProviderKind.volcano => _synthesizeVolcano(
        text,
        provider,
        cancelToken,
      ),
      TtsProviderKind.mimo => _synthesizeMimo(text, provider, cancelToken),
      TtsProviderKind.qwen => _synthesizeQwen(text, provider, cancelToken),
      TtsProviderKind.groq => _synthesizeGroq(text, provider, cancelToken),
      TtsProviderKind.xai => _synthesizeXai(text, provider, cancelToken),
      TtsProviderKind.system => throw UnsupportedError(
        'System TTS uses flutter_tts, not network',
      ),
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
  /// Supports single-speaker, multi-speaker (up to 2), and style prompts.
  Future<TtsSynthesisResult> _synthesizeGemini(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final url = _joinUrl(
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

    final response = await _dio.post<Map<String, dynamic>>(
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
    final wav = _pcmToWav(Uint8List.fromList(pcm), sampleRate: 24000);
    return TtsSynthesisResult(bytes: wav, mimeType: 'audio/wav');
  }

  /// MiniMax TTS via T2A v2 endpoint.
  /// Sends voice_setting (voice_id, speed, vol, pitch, emotion),
  /// language_boost, and audio_setting (sample_rate, bitrate, format).
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

    final response = await _dio.post<Map<String, dynamic>>(
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
    return TtsSynthesisResult(bytes: _hexToBytes(audioHex), mimeType: mimeType);
  }

  /// Fetches available MiniMax voices from the `/v1/get_voice` API.
  /// Returns a list of [VoicePreset] items. Falls back to empty list on error.
  Future<List<MiniMaxRemoteVoice>> fetchMiniMaxVoices(
    TtsProviderSetting provider,
  ) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://api.minimaxi.chat';
    final groupId = provider.groupId;
    final path = groupId.isNotEmpty
        ? '/v1/get_voice?GroupId=$groupId'
        : '/v1/get_voice';
    final url = _joinUrl(baseUrl, path);
    final response = await _dio.post<Map<String, dynamic>>(
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

  /// SiliconFlow TTS — uses OpenAI-compatible `/audio/speech` endpoint.
  /// Builds model-specific request bodies for CosyVoice2 / Fish-Speech /
  /// IndexTTS-2 / MOSS-TTSD.
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

    final isMossTTSD = provider.model == 'fnlp/MOSS-TTSD-v0.5';
    final isIndexTTS2 = provider.model == 'IndexTeam/IndexTTS-2';
    final hasAdvancedParams = isMossTTSD || isIndexTTS2;

    final audioFormat = provider.audioFormat.isNotEmpty
        ? provider.audioFormat
        : 'mp3';

    final body = <String, dynamic>{
      'model': provider.model,
      'input': text,
      'voice': voice,
      'response_format': audioFormat,
    };

    // speed and gain for MOSS-TTSD / IndexTTS-2 (official API range)
    if (hasAdvancedParams) {
      body['speed'] = provider.speed;
      body['gain'] = provider.gain;
    }

    // max_tokens for MOSS-TTSD only
    if (isMossTTSD) {
      body['max_tokens'] = provider.maxTokens > 0 ? provider.maxTokens : 1600;
    }

    // sample_rate (format-dependent)
    if (provider.sampleRate > 0) {
      body['sample_rate'] = provider.sampleRate;
    }

    final response = await _dio.post<List<int>>(
      url,
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );

    final mimeType = switch (audioFormat) {
      'wav' => 'audio/wav',
      'pcm' => 'audio/pcm',
      'opus' => 'audio/opus',
      _ => 'audio/mpeg',
    };
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: mimeType,
    );
  }

  /// ElevenLabs TTS — `output_format` is a **URL query parameter** (not body).
  /// `voice_settings` controls stability / similarity / style / speed.
  Future<TtsSynthesisResult> _synthesizeElevenLabs(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final voiceId = provider.voice.isNotEmpty
        ? provider.voice
        : 'JBFqnCBsd6RMkjVDRZzb';
    final outputFmt = provider.outputFormat.isNotEmpty
        ? provider.outputFormat
        : 'mp3_44100_128';
    final url =
        '${_joinUrl(provider.baseUrl, '/v1/text-to-speech/$voiceId')}'
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

    final response = await _dio.post<List<int>>(
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
      mimeType: _elevenLabsMimeType(outputFmt),
    );
  }

  String _elevenLabsMimeType(String format) {
    if (format.startsWith('mp3_')) return 'audio/mpeg';
    if (format.startsWith('pcm_')) return 'audio/wav';
    if (format.startsWith('ulaw_')) return 'audio/basic';
    if (format.startsWith('alaw_')) return 'audio/basic';
    if (format.startsWith('opus_')) return 'audio/opus';
    if (format.startsWith('wav_')) return 'audio/wav';
    return 'audio/mpeg';
  }

  /// Fetch dynamic voice list from ElevenLabs `/v1/voices` API.
  Future<List<ElevenLabsRemoteVoice>> fetchElevenLabsVoices(
    TtsProviderSetting provider,
  ) async {
    final url = _joinUrl(provider.baseUrl, '/v1/voices');
    try {
      final response = await _dio.get<Map<String, dynamic>>(
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

  /// Azure Cognitive Services TTS — full SSML with prosody + express-as.
  Future<TtsSynthesisResult> _synthesizeAzure(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final region = provider.region.isNotEmpty ? provider.region : 'eastus';
    final url =
        'https://$region.tts.speech.microsoft.com/'
        'cognitiveservices/v1';
    final voiceName = provider.voice.isNotEmpty
        ? provider.voice
        : 'zh-CN-XiaoxiaoNeural';
    final lang = _azureLangFromVoice(voiceName);
    final outputFmt = provider.azureOutputFormat.isNotEmpty
        ? provider.azureOutputFormat
        : 'audio-16khz-128kbitrate-mono-mp3';

    final ssml = _buildAzureSsml(text, voiceName, lang, provider);

    final response = await _dio.post<List<int>>(
      url,
      data: ssml,
      options: Options(
        headers: {
          'Ocp-Apim-Subscription-Key': provider.apiKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': outputFmt,
          'User-Agent': 'AetherLink',
        },
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: _azureMimeType(outputFmt),
    );
  }

  String _buildAzureSsml(
    String text,
    String voiceName,
    String lang,
    TtsProviderSetting provider,
  ) {
    final buf = StringBuffer()
      ..write('<speak version="1.0" ')
      ..write('xmlns="http://www.w3.org/2001/10/synthesis" ')
      ..write('xmlns:mstts="https://www.w3.org/2001/mstts" ')
      ..write('xml:lang="$lang">')
      ..write('<voice name="$voiceName">');

    // Prosody
    final prosodyAttrs = <String>[];
    if (provider.azureRate != 'medium') {
      prosodyAttrs.add('rate="${provider.azureRate}"');
    }
    if (provider.azurePitch != 'medium') {
      prosodyAttrs.add('pitch="${provider.azurePitch}"');
    }
    if (provider.azureVolume != 'medium') {
      prosodyAttrs.add('volume="${provider.azureVolume}"');
    }
    if (prosodyAttrs.isNotEmpty) {
      buf.write('<prosody ${prosodyAttrs.join(' ')}>');
    }

    // Express-as (style / role)
    final hasStyle =
        provider.azureStyle.isNotEmpty && voiceName.contains('Neural');
    if (hasStyle) {
      buf.write('<mstts:express-as style="${provider.azureStyle}"');
      if (provider.azureStyleDegree != 1.0) {
        buf.write(' styledegree="${provider.azureStyleDegree}"');
      }
      if (provider.azureRole.isNotEmpty) {
        buf.write(' role="${provider.azureRole}"');
      }
      buf.write('>');
    }

    buf.write(_escapeXml(text));

    if (hasStyle) buf.write('</mstts:express-as>');
    if (prosodyAttrs.isNotEmpty) buf.write('</prosody>');
    buf.write('</voice></speak>');
    return buf.toString();
  }

  /// Extract language locale from Azure voice name (e.g. "zh-CN-XiaoxiaoNeural" → "zh-CN").
  String _azureLangFromVoice(String voiceName) {
    final parts = voiceName.split('-');
    if (parts.length >= 2) return '${parts[0]}-${parts[1]}';
    return 'zh-CN';
  }

  String _azureMimeType(String format) {
    if (format.contains('mp3')) return 'audio/mpeg';
    if (format.contains('opus')) return 'audio/ogg';
    if (format.startsWith('riff-')) return 'audio/wav';
    if (format.startsWith('raw-')) return 'audio/pcm';
    if (format.contains('webm')) return 'audio/webm';
    return 'audio/mpeg';
  }

  /// Fetch dynamic voice list from Azure `/cognitiveservices/voices/list` API.
  Future<List<AzureRemoteVoice>> fetchAzureVoices(
    TtsProviderSetting provider,
  ) async {
    final region = provider.region.isNotEmpty ? provider.region : 'eastus';
    final url =
        'https://$region.tts.speech.microsoft.com/'
        'cognitiveservices/voices/list';
    try {
      final response = await _dio.get<List<dynamic>>(
        url,
        options: Options(
          headers: {'Ocp-Apim-Subscription-Key': provider.apiKey},
        ),
      );
      final voices = response.data ?? [];
      return voices.map((v) {
        final m = v as Map<String, dynamic>;
        return AzureRemoteVoice(
          shortName: m['ShortName'] as String? ?? '',
          displayName: m['DisplayName'] as String? ?? '',
          localName: m['LocalName'] as String? ?? '',
          locale: m['Locale'] as String? ?? '',
          gender: m['Gender'] as String? ?? '',
          styleList:
              (m['StyleList'] as List<dynamic>?)
                  ?.map((s) => s.toString())
                  .toList() ??
              [],
          rolePlayList:
              (m['RolePlayList'] as List<dynamic>?)
                  ?.map((s) => s.toString())
                  .toList() ??
              [],
        );
      }).toList();
    } catch (_) {
      return [];
    }
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

  /// MiMo TTS via chat completions format (api.xiaomimimo.com).
  ///
  /// Three model variants:
  /// - mimo-v2.5-tts: Preset voice synthesis
  /// - mimo-v2.5-tts-voicedesign: Voice design from description
  /// - mimo-v2.5-tts-voiceclone: Clone from audio sample
  ///
  /// Auth: `api-key` header (not Authorization: Bearer)
  Future<TtsSynthesisResult> _synthesizeMimo(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://api.xiaomimimo.com/v1';
    final url = _joinUrl(baseUrl, '/chat/completions');

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

    final response = await _dio.post<Map<String, dynamic>>(
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

  // -- Qwen TTS --------------------------------------------------------------

  /// Qwen TTS (通义千问) via DashScope multimodal-generation endpoint.
  ///
  /// Two model variants:
  /// - qwen3-tts-flash: Basic text-to-speech synthesis
  /// - qwen3-tts-instruct-flash: Supports natural language instructions for
  ///   expressiveness control (speech rate, intonation, emotion)
  ///
  /// Uses SSE streaming: response returns base64-encoded PCM chunks which are
  /// concatenated and wrapped in a WAV header (24000Hz mono 16-bit).
  Future<TtsSynthesisResult> _synthesizeQwen(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://dashscope.aliyuncs.com/api/v1';
    final url = _joinUrl(
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
    final response = await _dio.post<String>(
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
      bytes: _pcmToWav(Uint8List.fromList(pcm), sampleRate: 24000),
      mimeType: 'audio/wav',
    );
  }

  // -- Helpers ---------------------------------------------------------------

  static String _joinUrl(String base, String path) {
    final trimmed = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
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

  // ─── Groq TTS ──────────────────────────────────────────────

  /// Groq PlayAI TTS — OpenAI-compatible endpoint.
  Future<TtsSynthesisResult> _synthesizeGroq(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final url = _joinUrl(provider.baseUrl, '/audio/speech');
    final format = provider.audioFormat.isNotEmpty
        ? provider.audioFormat
        : 'wav';
    final response = await _dio.post<List<int>>(
      url,
      data: {
        'model': provider.model,
        'input': text,
        'voice': provider.voice,
        'response_format': format,
        if (provider.groqSampleRate != 24000)
          'sample_rate': provider.groqSampleRate,
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
    final mimeType = switch (format) {
      'mp3' => 'audio/mpeg',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'mulaw' => 'audio/basic',
      _ => 'audio/wav',
    };
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: mimeType,
    );
  }

  // ─── xAI TTS ───────────────────────────────────────────────

  /// xAI (Grok) TTS — POST /v1/tts, returns raw audio bytes.
  Future<TtsSynthesisResult> _synthesizeXai(
    String text,
    TtsProviderSetting provider,
    CancelToken? cancelToken,
  ) async {
    final url = _joinUrl(provider.baseUrl, '/tts');
    final codec = provider.xaiCodec.isNotEmpty ? provider.xaiCodec : 'mp3';
    final response = await _dio.post<List<int>>(
      url,
      data: {
        'text': text,
        'voice_id': provider.voice,
        'language': provider.xaiLanguage,
        if (codec != 'mp3' ||
            provider.xaiSampleRate != 24000 ||
            provider.xaiBitRate != 128000)
          'output_format': {
            'codec': codec,
            'sample_rate': provider.xaiSampleRate,
            'bit_rate': provider.xaiBitRate,
          },
        if (provider.speed != 1.0) 'speed': provider.speed,
        if (provider.xaiTextNormalization) 'text_normalization': true,
        if (provider.xaiOptimizeStreamingLatency > 0)
          'optimize_streaming_latency': provider.xaiOptimizeStreamingLatency,
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
    final mimeType = switch (codec) {
      'wav' => 'audio/wav',
      'pcm' => 'audio/pcm',
      'mulaw' => 'audio/basic',
      'alaw' => 'audio/basic',
      _ => 'audio/mpeg',
    };
    return TtsSynthesisResult(
      bytes: Uint8List.fromList(response.data!),
      mimeType: mimeType,
    );
  }
}
