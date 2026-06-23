import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around `flutter_tts` for system (on-device) TTS. Used as the
/// fallback when no network TTS provider is configured or when offline.
class SystemTtsService {
  FlutterTts? _tts;
  bool _initialized = false;

  Future<FlutterTts> _ensureInit() async {
    if (_tts != null && _initialized) return _tts!;
    _tts = FlutterTts();
    await _tts!.awaitSpeakCompletion(true);
    // Let the system engine pick the best voice for the content; avoid
    // hardcoding a locale that may not be installed.
    await _tts!.setLanguage('zh-CN').catchError((_) {
      // Fallback — use whatever the device default is.
    });
    _initialized = true;
    return _tts!;
  }

  /// Speaks [text] using the device's built-in TTS engine. Returns a Future
  /// that completes when the utterance finishes.
  Future<void> speak(String text, {double speed = 1.0}) async {
    final tts = await _ensureInit();
    await tts.setSpeechRate(speed.clamp(0.1, 2.0));
    final result = await tts.speak(text);
    if (result != 1) {
      throw Exception('系统 TTS speak() 返回错误码: $result');
    }
  }

  Future<void> stop() async {
    await _tts?.stop();
  }

  Future<void> pause() async {
    await _tts?.pause();
  }

  Future<void> dispose() async {
    await _tts?.stop();
    _tts = null;
    _initialized = false;
  }
}
