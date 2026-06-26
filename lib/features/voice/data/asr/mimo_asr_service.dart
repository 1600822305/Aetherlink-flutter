import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

/// HTTP segmented ASR using Xiaomi MiMo (mimo-v2.5-asr).
///
/// Unlike the WebSocket streaming providers (OpenAI Realtime / DashScope /
/// Volcengine), MiMo ASR is an OpenAI-compatible `chat/completions` one-shot
/// recognition endpoint. During recording, audio is buffered and segmented by
/// [AsrProviderSetting.segmentDurationSec] (or by a byte cap), each segment is
/// wrapped into a WAV container, base64-embedded into
/// `messages[].content[].input_audio.data`, and POSTed to
/// `{baseUrl}/chat/completions`. The recognized text from each segment
/// (`choices[0].message.content`) is accumulated and emitted.
///
/// Official docs:
/// https://platform.xiaomimimo.com/docs/zh-CN/api/audio/Speech-Recognition
class MimoAsrService {
  MimoAsrService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  final _textController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// MiMo limits a single request's base64 payload to ~10MB (≈7.5MB raw).
  /// 16kHz / 16bit / mono → 7.5MB ≈ 234s. Auto-flush early at 6MB for headroom.
  static const int maxSegmentBytes = 6 * 1024 * 1024;

  static const int sampleRate = 16000;

  AsrProviderSetting? _provider;

  /// Buffer for the current (not-yet-uploaded) segment.
  final _buffer = BytesBuilder(copy: false);
  DateTime _segmentStart = DateTime.now();

  /// Final recognized text from completed segments, in order.
  final _completed = <String>[];

  /// Ensures only one flush runs at a time so results stay ordered.
  Future<void> _flushChain = Future<void>.value();

  Stream<String> get textStream => _textController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Begins a new recognition session.
  void start(AsrProviderSetting provider) {
    _provider = provider;
    _buffer.clear();
    _segmentStart = DateTime.now();
    _completed.clear();
  }

  /// Feeds raw PCM16 audio bytes; flushes a segment when the time or byte
  /// threshold is reached.
  void sendAudio(List<int> pcm16Bytes) {
    final provider = _provider;
    if (provider == null) return;
    _buffer.add(pcm16Bytes);

    final segmentMs = provider.segmentDurationSec * 1000;
    final elapsedMs = DateTime.now().difference(_segmentStart).inMilliseconds;
    final shouldFlush =
        _buffer.length >= maxSegmentBytes ||
        (segmentMs > 0 && elapsedMs >= segmentMs);
    if (shouldFlush) {
      _enqueueFlush();
    }
  }

  /// Uploads any remaining buffered audio and waits for all flushes to finish.
  Future<void> finish() async {
    _enqueueFlush();
    await _flushChain;
  }

  void _enqueueFlush() {
    final provider = _provider;
    if (provider == null) return;
    if (_buffer.isEmpty) return;

    final pcm = _buffer.takeBytes();
    _segmentStart = DateTime.now();

    _flushChain = _flushChain.then((_) => _uploadSegment(pcm, provider));
  }

  Future<void> _uploadSegment(
    Uint8List pcm,
    AsrProviderSetting provider,
  ) async {
    if (pcm.isEmpty) return;
    try {
      final wav = _pcm16ToWav(pcm, sampleRate: provider.sampleRate);
      final b64 = base64Encode(wav);

      final baseUrl = provider.baseUrl.trim().isNotEmpty
          ? provider.baseUrl.trim()
          : 'https://api.xiaomimimo.com/v1';
      final url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions';

      final body = <String, dynamic>{
        'model': provider.model.isNotEmpty ? provider.model : 'mimo-v2.5-asr',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_audio',
                'input_audio': {'data': 'data:audio/wav;base64,$b64'},
              },
            ],
          },
        ],
        'asr_options': {
          'language': provider.language.isNotEmpty ? provider.language : 'auto',
        },
      };

      final response = await _dio.post<dynamic>(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'api-key': provider.apiKey,
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.json,
        ),
      );

      final data = response.data;
      final json = data is String
          ? jsonDecode(data) as Map<String, dynamic>
          : data as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      final message = choices != null && choices.isNotEmpty
          ? (choices.first as Map<String, dynamic>)['message']
                as Map<String, dynamic>?
          : null;
      final text = (message?['content'] ?? '').toString().trim();
      if (text.isNotEmpty) {
        _completed.add(text);
        _publish();
      }
    } on DioException catch (e) {
      final detail = e.response?.data ?? e.message;
      _errorController.add('MiMo ASR HTTP ${e.response?.statusCode}: $detail');
    } catch (e) {
      _errorController.add(e.toString());
    }
  }

  void _publish() {
    final transcript = _completed.where((s) => s.isNotEmpty).join(' ').trim();
    _textController.add(transcript);
  }

  Future<void> stop() async {
    _provider = null;
    _buffer.clear();
  }

  Future<void> dispose() async {
    await stop();
    await _textController.close();
    await _errorController.close();
  }

  /// Wraps raw PCM16 little-endian data into a minimal WAV container.
  /// MiMo only accepts WAV/MP3, so the raw PCM must be given a WAV header.
  static Uint8List _pcm16ToWav(
    Uint8List pcm, {
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    // RIFF
    buffer.setUint8(0, 0x52);
    buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x46);
    buffer.setUint8(3, 0x46);
    buffer.setUint32(4, fileSize, Endian.little);
    // WAVE
    buffer.setUint8(8, 0x57);
    buffer.setUint8(9, 0x41);
    buffer.setUint8(10, 0x56);
    buffer.setUint8(11, 0x45);
    // fmt
    buffer.setUint8(12, 0x66);
    buffer.setUint8(13, 0x6d);
    buffer.setUint8(14, 0x74);
    buffer.setUint8(15, 0x20);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    // data
    buffer.setUint8(36, 0x64);
    buffer.setUint8(37, 0x61);
    buffer.setUint8(38, 0x74);
    buffer.setUint8(39, 0x61);
    buffer.setUint32(40, dataSize, Endian.little);
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(44, 44 + dataSize, pcm);
    return bytes;
  }
}
