import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

/// Real-time streaming ASR using OpenAI Realtime API over WebSocket.
///
/// Uses the latest session structure (`session.update` with
/// `session.audio.input.transcription`) and supports:
/// - `gpt-4o-transcribe` / `gpt-4o-mini-transcribe` / `gpt-realtime-whisper`
/// - `delay` parameter (latency/accuracy tradeoff for gpt-realtime-whisper)
/// - `prompt` for domain vocabulary guidance
/// - `prefix_padding_ms` for VAD tuning
/// - 24 kHz PCM16 audio input (official recommendation)
class OpenaiRealtimeAsrService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _textController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// A stream of incremental transcription text.
  Stream<String> get textStream => _textController.stream;

  /// A stream of error messages from the server.
  Stream<String> get errorStream => _errorController.stream;

  /// The sample rate expected by the Realtime API.
  static const int sampleRate = 24000;

  /// Opens the WebSocket connection and configures the transcription session.
  Future<void> start(AsrProviderSetting provider) async {
    final wsUrl = provider.websocketUrl.isNotEmpty
        ? provider.websocketUrl
        : 'wss://api.openai.com/v1/realtime?intent=transcription';

    final model = provider.model.isNotEmpty
        ? provider.model
        : 'gpt-4o-transcribe';
    final uri = Uri.parse('$wsUrl&model=$model');

    _channel = WebSocketChannel.connect(
      uri,
      protocols: ['realtime', 'openai-insecure-api-key.${provider.apiKey}'],
    );

    await _channel!.ready;

    // Build transcription config.
    final transcriptionConfig = <String, dynamic>{
      'model': model,
      if (provider.language.isNotEmpty) 'language': provider.language,
      if (provider.prompt.isNotEmpty) 'prompt': provider.prompt,
      if (provider.realtimeDelay.isNotEmpty) 'delay': provider.realtimeDelay,
    };

    // Build turn detection config (only for models that support it).
    // gpt-realtime-whisper requires turn_detection to be null.
    final bool isRealtimeWhisper = model.contains('realtime-whisper');
    final turnDetection = isRealtimeWhisper
        ? null
        : <String, dynamic>{
            'type': 'server_vad',
            'threshold': provider.vadThreshold,
            'silence_duration_ms': provider.silenceDurationMs,
            'prefix_padding_ms': provider.prefixPaddingMs,
          };

    // Send session.update with the latest API structure.
    _channel!.sink.add(
      jsonEncode({
        'type': 'session.update',
        'session': {
          'type': 'transcription',
          'audio': {
            'input': {
              'format': {'type': 'audio/pcm', 'rate': sampleRate},
              'transcription': transcriptionConfig,
              if (turnDetection != null) 'turn_detection': turnDetection,
            },
          },
        },
      }),
    );

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
    _channel!.sink.add(
      jsonEncode({'type': 'input_audio_buffer.append', 'audio': b64}),
    );
  }

  /// Manually commits the audio buffer (needed when turn_detection is null,
  /// e.g. gpt-realtime-whisper).
  void commitAudioBuffer() {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'input_audio_buffer.commit'}));
  }

  void _handleEvent(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == 'conversation.item.input_audio_transcription.delta') {
      final delta = (json['delta'] ?? '').toString();
      if (delta.isNotEmpty) {
        _textController.add(delta);
      }
    } else if (type ==
        'conversation.item.input_audio_transcription.completed') {
      final transcript = (json['transcript'] ?? '').toString();
      if (transcript.isNotEmpty) {
        _textController.add(transcript);
      }
    } else if (type == 'error') {
      final error = json['error'] as Map<String, dynamic>?;
      final message = (error?['message'] ?? 'Unknown error').toString();
      _errorController.add(message);
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
    await _errorController.close();
  }
}
