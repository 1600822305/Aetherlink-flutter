import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_audio_utils.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/engines/tts_engine.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// Fish Audio TTS — `POST /v1/tts` with a `model` **header** selecting the TTS
/// model (s1 / s2-pro / s2.1-pro / s2.1-pro-free) and a JSON body carrying the
/// voice `reference_id`, sampling (temperature / top_p), prosody
/// (speed / volume / normalize_loudness) and output format options.
class FishAudioTtsEngine extends TtsEngine {
  const FishAudioTtsEngine();

  @override
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  }) async {
    final baseUrl = provider.baseUrl.isNotEmpty
        ? provider.baseUrl
        : 'https://api.fish.audio';
    final model = provider.model.isNotEmpty ? provider.model : 's2.1-pro-free';
    final format = provider.fishFormat.isNotEmpty ? provider.fishFormat : 'mp3';

    final body = <String, dynamic>{
      'text': text,
      'temperature': provider.fishTemperature,
      'top_p': provider.fishTopP,
      'prosody': {
        'speed': provider.speed,
        'volume': provider.fishVolume,
        'normalize_loudness': provider.fishNormalizeLoudness,
      },
      'chunk_length': provider.fishChunkLength,
      'normalize': provider.fishNormalize,
      'format': format,
      'mp3_bitrate': provider.fishMp3Bitrate,
      'opus_bitrate': provider.fishOpusBitrate,
      'latency': provider.fishLatency,
      'max_new_tokens': provider.fishMaxNewTokens,
      'repetition_penalty': provider.fishRepetitionPenalty,
      'min_chunk_length': provider.fishMinChunkLength,
      'condition_on_previous_chunks': provider.fishConditionOnPreviousChunks,
      'early_stop_threshold': provider.fishEarlyStopThreshold,
    };
    if (provider.voice.trim().isNotEmpty) {
      body['reference_id'] = provider.voice.trim();
    }
    if (provider.fishSampleRate > 0) {
      body['sample_rate'] = provider.fishSampleRate;
    }

    final response = await dio.post<List<int>>(
      joinUrl(baseUrl, '/v1/tts'),
      data: body,
      options: Options(
        headers: {
          'Authorization': 'Bearer ${provider.apiKey}',
          'Content-Type': 'application/json',
          'model': model,
        },
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );

    var bytes = Uint8List.fromList(response.data!);
    // PCM comes back headerless (16-bit mono); wrap in WAV for playback.
    if (format == 'pcm') {
      bytes = pcmToWav(
        bytes,
        sampleRate: provider.fishSampleRate > 0
            ? provider.fishSampleRate
            : 44100,
      );
    }
    return TtsSynthesisResult(bytes: bytes, mimeType: _mimeType(format));
  }

  static String _mimeType(String format) => switch (format) {
    'wav' || 'pcm' => 'audio/wav',
    'opus' => 'audio/opus',
    _ => 'audio/mpeg',
  };
}
