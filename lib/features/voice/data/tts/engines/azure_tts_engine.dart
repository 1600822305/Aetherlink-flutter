import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

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

/// Azure Cognitive Services TTS — full SSML with prosody + express-as.
class AzureTtsEngine extends TtsEngine {
  const AzureTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final region = provider.region.isNotEmpty ? provider.region : 'eastus';
    final url =
        'https://$region.tts.speech.microsoft.com/'
        'cognitiveservices/v1';
    final voiceName = provider.voice.isNotEmpty
        ? provider.voice
        : 'zh-CN-XiaoxiaoNeural';
    final lang = _langFromVoice(voiceName);
    final outputFmt = provider.azureOutputFormat.isNotEmpty
        ? provider.azureOutputFormat
        : 'audio-16khz-128kbitrate-mono-mp3';

    final ssml = _buildSsml(text, voiceName, lang, provider);

    final response = await dio.post<List<int>>(
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
      mimeType: _mimeType(outputFmt),
    );
  }

  String _buildSsml(
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

    buf.write(escapeXml(text));

    if (hasStyle) buf.write('</mstts:express-as>');
    if (prosodyAttrs.isNotEmpty) buf.write('</prosody>');
    buf.write('</voice></speak>');
    return buf.toString();
  }

  /// Extract language locale from Azure voice name
  /// (e.g. "zh-CN-XiaoxiaoNeural" → "zh-CN").
  String _langFromVoice(String voiceName) {
    final parts = voiceName.split('-');
    if (parts.length >= 2) return '${parts[0]}-${parts[1]}';
    return 'zh-CN';
  }

  String _mimeType(String format) {
    if (format.contains('mp3')) return 'audio/mpeg';
    if (format.contains('opus')) return 'audio/ogg';
    if (format.startsWith('riff-')) return 'audio/wav';
    if (format.startsWith('raw-')) return 'audio/pcm';
    if (format.contains('webm')) return 'audio/webm';
    return 'audio/mpeg';
  }

  /// Fetch dynamic voice list from Azure `/cognitiveservices/voices/list` API.
  Future<List<AzureRemoteVoice>> fetchVoices(
    TtsProviderSetting provider, {
    required Dio dio,
  }) async {
    final region = provider.region.isNotEmpty ? provider.region : 'eastus';
    final url =
        'https://$region.tts.speech.microsoft.com/'
        'cognitiveservices/voices/list';
    try {
      final response = await dio.get<List<dynamic>>(
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
}
