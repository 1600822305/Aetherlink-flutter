import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

/// Real-time streaming ASR using Volcengine (ByteDance / 字节火山引擎) "大模型流式
/// 语音识别" over WebSocket with the custom binary frame protocol.
///
/// Protocol reference (official docs):
/// https://www.volcengine.com/docs/6561/1354869
///
/// Binary frame layout (all integers are big-endian):
///   byte 0: (protocol version << 4) | header size   -> 0x11 (v1, header=4B)
///   byte 1: (message type << 4) | message type flags
///   byte 2: (serialization << 4) | compression
///   byte 3: reserved (0x00)
///   [4B] payload size (uint32, only for client/full-server frames)
///   [N]  payload (gzip-compressed when compression == gzip)
///
/// Message types: 0x01 full client request, 0x02 audio-only request,
/// 0x09 full server response, 0x0F error response.
///
/// Flow:
/// 1. Connect with auth headers (new console: X-Api-Key; old console:
///    X-Api-App-Key + X-Api-Access-Key) plus X-Api-Resource-Id.
/// 2. Send a full client request (0x01) with gzipped JSON config.
/// 3. Stream audio via audio-only requests (0x02) with raw PCM16 bytes.
/// 4. On stop, send a final audio-only frame flagged as the last packet.
///
/// The server emits the full accumulated transcript in `result.text` each time,
/// so the controller replaces (not appends) the recognized text.
class VolcengineAsrService {
  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _textController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  String _lastText = '';

  /// A stream of the full recognized text so far.
  Stream<String> get textStream => _textController.stream;

  /// A stream of error messages from the server.
  Stream<String> get errorStream => _errorController.stream;

  /// The default endpoint when none is configured.
  static const String defaultEndpoint =
      'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel';

  /// Volcengine only supports 16 kHz PCM16 mono input.
  static const int sampleRate = 16000;

  // Frame protocol constants.
  static const int _msgFullClientRequest = 0x01;
  static const int _msgAudioOnly = 0x02;
  static const int _serNone = 0x00;
  static const int _serJson = 0x01;
  static const int _compNone = 0x00;
  static const int _compGzip = 0x01;
  static const int _flagLastPacket = 0x02;

  /// Opens the WebSocket connection and sends the full client request.
  Future<void> start(AsrProviderSetting provider) async {
    _lastText = '';

    final url = provider.websocketUrl.trim().isNotEmpty
        ? provider.websocketUrl.trim()
        : defaultEndpoint;

    _channel = IOWebSocketChannel.connect(
      Uri.parse(url),
      headers: _buildHeaders(provider),
    );

    await _channel!.ready;

    // First frame: full client request (JSON config, gzip-compressed).
    final payload = utf8.encode(jsonEncode(_buildRequestPayload(provider)));
    final frame = _buildFrame(
      messageType: _msgFullClientRequest,
      flags: 0x00,
      serialization: _serJson,
      compression: _compGzip,
      payload: gzip.encode(payload),
    );
    _channel!.sink.add(frame);

    _subscription = _channel!.stream.listen(
      (data) {
        if (data is List<int>) {
          _handleBinaryResponse(Uint8List.fromList(data));
        }
      },
      onError: (Object error) {
        _errorController.add(error.toString());
      },
    );
  }

  /// Sends one chunk of raw PCM16 audio as an audio-only request.
  void sendAudio(List<int> pcm16Bytes) {
    if (_channel == null || pcm16Bytes.isEmpty) return;
    final frame = _buildFrame(
      messageType: _msgAudioOnly,
      flags: 0x00,
      serialization: _serNone,
      compression: _compGzip,
      payload: gzip.encode(pcm16Bytes),
    );
    _channel!.sink.add(frame);
  }

  /// Sends an empty final audio packet to signal the end of the stream.
  void finish() {
    if (_channel == null) return;
    final frame = _buildFrame(
      messageType: _msgAudioOnly,
      flags: _flagLastPacket,
      serialization: _serNone,
      compression: _compNone,
      payload: const <int>[],
    );
    _channel!.sink.add(frame);
  }

  Map<String, String> _buildHeaders(AsrProviderSetting provider) {
    final headers = <String, String>{
      'X-Api-Resource-Id': provider.resourceId.isNotEmpty
          ? provider.resourceId
          : 'volc.bigasr.sauc.duration',
      'X-Api-Request-Id': _uuid(),
      'X-Api-Connect-Id': _uuid(),
      'X-Api-Sequence': '-1',
    };
    // Old console uses X-Api-App-Key + X-Api-Access-Key; new console only
    // needs X-Api-Key.
    if (provider.appKey.isNotEmpty && provider.accessKey.isNotEmpty) {
      headers['X-Api-App-Key'] = provider.appKey;
      headers['X-Api-Access-Key'] = provider.accessKey;
    } else {
      headers['X-Api-Key'] = provider.apiKey;
    }
    return headers;
  }

  Map<String, dynamic> _buildRequestPayload(AsrProviderSetting provider) {
    final audio = <String, dynamic>{
      'format': 'pcm',
      'codec': 'raw',
      'rate': provider.sampleRate > 0 ? provider.sampleRate : sampleRate,
      'bits': 16,
      'channel': 1,
      if (provider.language.isNotEmpty) 'language': provider.language,
    };

    final request = <String, dynamic>{
      'model_name': provider.model.isNotEmpty ? provider.model : 'bigmodel',
      'enable_itn': provider.enableItn,
      'enable_punc': provider.enablePunc,
      'enable_ddc': provider.enableDdc,
      'show_utterances': true,
      'result_type': 'full',
      'end_window_size': provider.endWindowSize,
      if (provider.outputZhVariant.isNotEmpty)
        'output_zh_variant': provider.outputZhVariant,
      if (provider.corpusText.isNotEmpty) 'corpus': _buildCorpus(provider),
    };

    return {
      'user': {'uid': 'aetherlink'},
      'audio': audio,
      'request': request,
    };
  }

  /// Builds the corpus block from comma/line-separated hotwords.
  Map<String, dynamic> _buildCorpus(AsrProviderSetting provider) {
    final words = provider.corpusText
        .split(RegExp(r'[,，\n]'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .map((w) => {'word': w})
        .toList();
    return {
      'context': jsonEncode({'hotwords': words}),
    };
  }

  void _handleBinaryResponse(Uint8List data) {
    if (data.length < 4) return;

    final byte1 = data[1] & 0xFF;
    final byte2 = data[2] & 0xFF;
    final messageType = (byte1 >> 4) & 0x0F;
    final messageFlags = byte1 & 0x0F;
    final compression = byte2 & 0x0F;

    final view = ByteData.sublistView(data);
    var offset = 4;

    switch (messageType) {
      // Full server response (recognition result).
      case 0x09:
        final hasSequence = (messageFlags & 0x01) != 0;
        if (hasSequence) offset += 4;
        if (offset + 4 > data.length) return;
        final payloadSize = view.getUint32(offset, Endian.big);
        offset += 4;
        if (payloadSize <= 0 || offset + payloadSize > data.length) return;

        var payload = data.sublist(offset, offset + payloadSize);
        if (compression == _compGzip) {
          try {
            payload = Uint8List.fromList(gzip.decode(payload));
          } catch (_) {
            return;
          }
        }

        Map<String, dynamic> json;
        try {
          json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
        } catch (_) {
          return;
        }

        final result = json['result'];
        final text = result is Map<String, dynamic>
            ? (result['text'] ?? '').toString()
            : '';
        if (text.isNotEmpty && text != _lastText) {
          _lastText = text;
          _textController.add(text);
        }

      // Error response.
      case 0x0F:
        if (offset + 8 > data.length) {
          _errorController.add('Volcengine ASR error');
          return;
        }
        offset += 4; // skip error code
        final msgSize = view.getUint32(offset, Endian.big);
        offset += 4;
        final message = (msgSize > 0 && offset + msgSize <= data.length)
            ? utf8.decode(data.sublist(offset, offset + msgSize))
            : 'Volcengine ASR error';
        _errorController.add(message);
    }
  }

  /// Builds the 4-byte header + 4-byte big-endian payload size + payload.
  static Uint8List _buildFrame({
    required int messageType,
    required int flags,
    required int serialization,
    required int compression,
    required List<int> payload,
  }) {
    final frame = BytesBuilder();
    frame.add([
      0x11,
      ((messageType << 4) | (flags & 0x0F)) & 0xFF,
      ((serialization << 4) | (compression & 0x0F)) & 0xFF,
      0x00,
    ]);
    final size = ByteData(4)..setUint32(0, payload.length, Endian.big);
    frame.add(size.buffer.asUint8List());
    frame.add(payload);
    return frame.toBytes();
  }

  /// Generates a random UUID v4 string (no external dependency).
  static String _uuid() {
    final rnd = Random();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
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
