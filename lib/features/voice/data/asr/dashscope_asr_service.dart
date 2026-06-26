import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

/// Real-time streaming ASR using Alibaba DashScope (Qwen-ASR-Realtime) over
/// WebSocket.
///
/// Protocol reference:
/// https://www.alibabacloud.com/help/en/model-studio/qwen-asr-realtime-client-events
///
/// Flow:
/// 1. Connect with `Authorization: Bearer <apiKey>` header and `?model=` query.
/// 2. Send `session.update` to configure audio format, language, corpus and VAD.
/// 3. Stream audio via `input_audio_buffer.append` (Base64 PCM16).
/// 4. VAD mode: server triggers recognition automatically. Manual mode: send
///    `input_audio_buffer.commit` to trigger recognition.
/// 5. Send `session.finish` to end, then close after `session.finished`.
///
/// Server emits incremental `...transcription.text` (confirmed prefix `text` +
/// draft suffix `stash`) and final `...transcription.completed` (`transcript`).
class DashScopeAsrService {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _textController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// The accumulated final transcript across completed utterances.
  final _completed = <String>[];

  /// In-progress (not yet confirmed) text for the current utterance.
  String _partial = '';

  bool _useVad = true;

  /// A stream of the full recognized text so far (completed + partial).
  Stream<String> get textStream => _textController.stream;

  /// A stream of error messages from the server.
  Stream<String> get errorStream => _errorController.stream;

  /// The default endpoint when none is configured.
  static const String defaultEndpoint =
      'wss://dashscope.aliyuncs.com/api-ws/v1/realtime';

  static const String defaultModel = 'qwen3-asr-flash-realtime';

  /// Opens the WebSocket connection and configures the transcription session.
  Future<void> start(AsrProviderSetting provider) async {
    _completed.clear();
    _partial = '';
    _useVad = provider.useVad;

    final model = provider.model.isNotEmpty ? provider.model : defaultModel;
    final uri = _buildUri(provider.websocketUrl, model);

    _channel = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer ${provider.apiKey}'},
    );

    await _channel!.ready;

    _channel!.sink.add(jsonEncode(_sessionUpdateEvent(provider)));

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _handleEvent(json);
        } catch (_) {}
      },
      onError: (Object error) {
        _errorController.add(error.toString());
      },
    );
  }

  /// Sends raw PCM16 audio bytes to the server's input buffer.
  void sendAudio(List<int> pcm16Bytes) {
    if (_channel == null) return;
    final b64 = base64Encode(pcm16Bytes);
    _channel!.sink.add(
      jsonEncode({
        'event_id': _eventId(),
        'type': 'input_audio_buffer.append',
        'audio': b64,
      }),
    );
  }

  /// In manual mode, commits the buffered audio as one utterance to trigger
  /// recognition. No-op in VAD mode (the server triggers automatically).
  void commitAudioBuffer() {
    if (_channel == null || _useVad) return;
    _channel!.sink.add(
      jsonEncode({'event_id': _eventId(), 'type': 'input_audio_buffer.commit'}),
    );
  }

  /// Signals the server to finish the session and emit the final transcript.
  void finish() {
    if (_channel == null) return;
    _channel!.sink.add(
      jsonEncode({'event_id': _eventId(), 'type': 'session.finish'}),
    );
  }

  void _handleEvent(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      // Incremental result: confirmed prefix (text) + draft suffix (stash).
      case 'conversation.item.input_audio_transcription.text':
        final text = (json['text'] ?? '').toString();
        final stash = (json['stash'] ?? '').toString();
        _partial = (text + stash).trim();
        _publish();
      // Final result for the current utterance.
      case 'conversation.item.input_audio_transcription.completed':
        final transcript = (json['transcript'] ?? '').toString().trim();
        _partial = '';
        if (transcript.isNotEmpty) {
          _completed.add(transcript);
        }
        _publish();
      case 'conversation.item.input_audio_transcription.failed':
        final error = json['error'] as Map<String, dynamic>?;
        final message = (error?['message'] ?? 'transcription failed')
            .toString();
        _errorController.add(message);
      case 'error':
        final error = json['error'] as Map<String, dynamic>?;
        final message = (error?['message'] ?? 'Unknown error').toString();
        _errorController.add(message);
    }
  }

  /// Emits the full transcript (completed utterances + current partial).
  void _publish() {
    final parts = [
      ..._completed,
      if (_partial.isNotEmpty) _partial,
    ].where((s) => s.isNotEmpty).toList();
    _textController.add(parts.join(' '));
  }

  Map<String, dynamic> _sessionUpdateEvent(AsrProviderSetting provider) {
    final transcription = <String, dynamic>{
      if (provider.language.isNotEmpty) 'language': provider.language,
      if (provider.corpusText.isNotEmpty)
        'corpus': {'text': provider.corpusText},
    };

    final session = <String, dynamic>{
      'input_audio_format': provider.inputAudioFormat.isNotEmpty
          ? provider.inputAudioFormat
          : 'pcm',
      'sample_rate': provider.sampleRate,
      'input_audio_transcription': transcription,
      // VAD mode: server_vad config. Manual mode: null.
      'turn_detection': provider.useVad
          ? {
              'type': 'server_vad',
              'threshold': provider.vadThreshold,
              'silence_duration_ms': provider.silenceDurationMs,
            }
          : null,
    };

    return {
      'event_id': _eventId(),
      'type': 'session.update',
      'session': session,
    };
  }

  /// Builds the connection URI, appending the `model` query parameter if absent.
  static Uri _buildUri(String websocketUrl, String model) {
    final base = websocketUrl.trim().isNotEmpty
        ? websocketUrl.trim()
        : defaultEndpoint;
    final uri = Uri.parse(base);
    if (uri.queryParameters.containsKey('model')) return uri;
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'model': model},
    );
  }

  static String _eventId() => 'evt_${DateTime.now().microsecondsSinceEpoch}';

  /// Closes the WebSocket connection and cleans up resources.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await stop();
    await _textController.close();
    await _errorController.close();
  }
}
