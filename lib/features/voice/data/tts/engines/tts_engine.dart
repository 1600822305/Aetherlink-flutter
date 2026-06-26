import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

/// The result of a network TTS synthesis call: raw audio bytes and their MIME
/// type so the player knows the codec.
class TtsSynthesisResult {
  const TtsSynthesisResult({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

/// Contract for a single network TTS provider.
///
/// Each provider lives in its own file under `engines/` and implements this
/// interface, building the correct request format and parsing the response.
/// The shared [Dio] client is injected by the dispatcher ([NetworkTtsService])
/// so all engines reuse the project's HTTP client.
abstract class TtsEngine {
  const TtsEngine();

  /// Synthesizes [text] using the given [provider] configuration. Returns raw
  /// audio bytes. Throws on network or API errors.
  Future<TtsSynthesisResult> synthesize(
    String text,
    TtsProviderSetting provider, {
    required Dio dio,
    CancelToken? cancelToken,
  });
}
