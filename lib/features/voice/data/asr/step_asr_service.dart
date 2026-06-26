import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

/// HTTP segmented + SSE streaming ASR using StepFun (stepaudio-2.5-asr).
///
/// Like MiMo, Step is a one-shot HTTP submit-and-recognize interface (no
/// WebSocket session). During recording, audio is buffered and segmented by
/// [AsrProviderSetting.segmentDurationSec] (or by a byte cap); each segment's
/// raw PCM16 is base64-encoded (no WAV header needed — `format.type=pcm`) and
/// POSTed to `{baseUrl}/v1/audio/asr/sse`. The server replies with a
/// `text/event-stream` whose `transcript.text.delta` / `transcript.text.done`
/// events are parsed into the segment's transcript, which is then accumulated.
///
/// Differs from MiMo: Bearer auth, SSE response, raw PCM payload.
///
/// Official docs:
/// https://platform.stepfun.com/docs/zh/api-reference/audio/asr-sse
class StepAsrService {
  StepAsrService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  final _textController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Flush early at 6MB to avoid an oversized single request.
  static const int maxSegmentBytes = 6 * 1024 * 1024;

  /// Skip segments shorter than 100ms (16kHz/16bit/mono → 3200 bytes); the
  /// server rejects ultra-short fragments with a 400.
  static const int minSegmentBytes = 3200;

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
    // Drop ultra-short fragments the server would reject.
    if (pcm.length < minSegmentBytes) return;
    try {
      final b64 = base64Encode(pcm);
      final rate = provider.sampleRate > 0 ? provider.sampleRate : sampleRate;

      final transcription = <String, dynamic>{
        'model': provider.model.isNotEmpty
            ? provider.model
            : 'stepaudio-2.5-asr',
        'enable_itn': provider.enableItn,
        'enable_timestamp': provider.enableTimestamp,
      };
      if (provider.language.isNotEmpty) {
        transcription['language'] = provider.language;
      }
      final hotwords = _parseHotwords(provider.corpusText);
      if (hotwords.isNotEmpty) {
        transcription['hotwords'] = hotwords;
      }

      final body = <String, dynamic>{
        'audio': {
          'data': b64,
          'input': {
            'transcription': transcription,
            'format': {
              'type': 'pcm',
              'codec': 'pcm_s16le',
              'rate': rate,
              'bits': 16,
              'channel': 1,
            },
          },
        },
      };

      final baseUrl = provider.baseUrl.trim().isNotEmpty
          ? provider.baseUrl.trim()
          : 'https://api.stepfun.com';
      final url = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/v1/audio/asr/sse';

      final response = await _dio.post<ResponseBody>(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${provider.apiKey}',
            'Accept': 'text/event-stream',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
      );

      final text = await _parseSse(response.data!);
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        _completed.add(trimmed);
        _publish();
      }
    } on DioException catch (e) {
      final detail = await _readErrorBody(e) ?? e.message;
      _errorController.add('Step ASR HTTP ${e.response?.statusCode}: $detail');
    } catch (e) {
      _errorController.add(e.toString());
    }
  }

  /// Parses the SSE byte stream into the segment transcript. Accumulates
  /// `transcript.text.delta` events; a `transcript.text.done` event replaces
  /// the partial with the authoritative full text.
  Future<String> _parseSse(ResponseBody body) async {
    final transcript = StringBuffer();
    String? eventType;
    final dataLines = <String>[];

    bool dispatch() {
      if (eventType == null && dataLines.isEmpty) return false;
      final data = dataLines.join('\n');
      final stop = _handleSseEvent(eventType, data, transcript);
      eventType = null;
      dataLines.clear();
      return stop;
    }

    final lines = body.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) {
        if (dispatch()) break;
        continue;
      }
      if (line.startsWith(':')) continue;

      final sep = line.indexOf(':');
      final field = sep == -1 ? line : line.substring(0, sep);
      final value = sep == -1
          ? ''
          : (line[sep + 1] == ' '
                ? line.substring(sep + 2)
                : line.substring(sep + 1));
      if (field == 'event') {
        eventType = value;
      } else if (field == 'data') {
        dataLines.add(value);
      }
    }
    dispatch();
    return transcript.toString().trim();
  }

  /// Returns true when the stream should stop. Throws on an `error` event.
  bool _handleSseEvent(
    String? eventType,
    String data,
    StringBuffer transcript,
  ) {
    if (data == '[DONE]') return true;

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }

    final type = (eventType != null && eventType.isNotEmpty)
        ? eventType
        : (json?['type'] as String?);

    switch (type) {
      case 'transcript.text.delta':
        transcript.write(_extractText(json, json == null ? data : ''));
        return false;
      case 'transcript.text.done':
        final finalText = _extractText(json, '');
        if (finalText.isNotEmpty) {
          transcript.clear();
          transcript.write(finalText);
        }
        return true;
      case 'error':
        throw Exception('Step ASR error: ${_extractError(json, data)}');
      default:
        final text = _extractText(json, '');
        if (text.isNotEmpty) transcript.write(text);
        return false;
    }
  }

  String _extractText(Map<String, dynamic>? json, String fallback) {
    if (json == null) return fallback;
    const directKeys = ['delta', 'text', 'content', 'transcript'];
    for (final key in directKeys) {
      final value = json[key];
      if (value == null) continue;
      if (value is Map<String, dynamic>) {
        final nested = _extractText(value, '');
        if (nested.isNotEmpty) return nested;
      } else {
        final text = value.toString();
        if (text.isNotEmpty) return text;
      }
    }
    const nestedKeys = ['data', 'result', 'transcript'];
    for (final key in nestedKeys) {
      final nested = json[key];
      if (nested is Map<String, dynamic>) {
        final value = _extractText(nested, '');
        if (value.isNotEmpty) return value;
      }
    }
    return fallback;
  }

  String _extractError(Map<String, dynamic>? json, String fallback) {
    if (json == null) return fallback;
    final error = json['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    final message = json['message'];
    if (message is String && message.isNotEmpty) return message;
    return fallback;
  }

  /// Splits a comma/newline-separated hotword string into a list.
  static List<String> _parseHotwords(String text) {
    return text
        .split(RegExp(r'[,，\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<String?> _readErrorBody(DioException e) async {
    final data = e.response?.data;
    if (data is ResponseBody) {
      try {
        final bytes = <int>[];
        await for (final chunk in data.stream) {
          bytes.addAll(chunk);
        }
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        return null;
      }
    }
    return data?.toString();
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
}
