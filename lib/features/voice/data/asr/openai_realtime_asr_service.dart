import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

/// Real-time streaming ASR using OpenAI Realtime API over WebSocket.
/// Adapted from RikkaHub's `OpenAIRealtimeASR` pattern: opens a WebSocket,
/// streams audio chunks, and receives partial/final transcription events.
class OpenaiRealtimeAsrService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _textController = StreamController<String>.broadcast();

  /// A stream of incremental transcription text. Consumers should listen
  /// before calling [start].
  Stream<String> get textStream => _textController.stream;

  /// Opens the WebSocket connection and configures the transcription session.
  Future<void> start(AsrProviderSetting provider) async {
    final wsUrl = provider.websocketUrl.isNotEmpty
        ? provider.websocketUrl
        : 'wss://api.openai.com/v1/realtime?intent=transcription';

    final model = provider.model.isNotEmpty ? provider.model : 'gpt-4o-transcribe';
    final uri = Uri.parse('$wsUrl&model=$model');

    _channel = WebSocketChannel.connect(
      uri,
      protocols: ['realtime', 'openai-insecure-api-key.${provider.apiKey}'],
    );

    await _channel!.ready;

    // Configure the transcription session.
    _channel!.sink.add(jsonEncode({
      'type': 'transcription_session.update',
      'session': {
        'input_audio_format': 'pcm16',
        'input_audio_transcription': {
          'model': model,
          if (provider.language.isNotEmpty) 'language': provider.language,
        },
        'turn_detection': {
          'type': 'server_vad',
          'threshold': provider.vadThreshold,
          'silence_duration_ms': provider.silenceDurationMs,
        },
      },
    }));

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _handleEvent(json);
        } catch (_) {}
      },
      onError: (Object error) {
        _textController.addError(error);
      },
    );
  }

  /// Sends raw PCM16 audio bytes to the WebSocket.
  void sendAudio(List<int> pcm16Bytes) {
    if (_channel == null) return;
    final b64 = base64Encode(pcm16Bytes);
    _channel!.sink.add(jsonEncode({
      'type': 'input_audio_buffer.append',
      'audio': b64,
    }));
  }

  void _handleEvent(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == 'conversation.item.input_audio_transcription.delta') {
      final delta = (json['delta'] ?? '').toString();
      if (delta.isNotEmpty) {
        _textController.add(delta);
      }
    } else if (type == 'conversation.item.input_audio_transcription.completed') {
      final transcript = (json['transcript'] ?? '').toString();
      if (transcript.isNotEmpty) {
        _textController.add(transcript);
      }
    }
  }

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
  }
}
