import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around `flutter_tts` for system (on-device) TTS. Used as the
/// fallback when no network TTS provider is configured or when offline.
class SystemTtsService {
  SystemTtsService() {
    _tts.setCompletionHandler(() {
      _completers.removeFirst()?.complete();
    });
    _tts.setErrorHandler((msg) {
      _completers.removeFirst()?.completeError(Exception(msg));
    });
  }

  final FlutterTts _tts = FlutterTts();
  final _CompletionQueue _completers = _CompletionQueue();

  /// Speaks [text] using the device's built-in TTS engine. Returns a Future
  /// that completes when the utterance finishes.
  Future<void> speak(String text, {double speed = 1.0}) async {
    await _tts.setLanguage('zh-CN');
    await _tts.setSpeechRate(speed.clamp(0.1, 2.0));
    final c = Completer<void>();
    _completers.add(c);
    await _tts.speak(text);
    await c.future;
  }

  Future<void> stop() async {
    await _tts.stop();
    _completers.drainAll();
  }

  Future<void> pause() => _tts.pause();

  Future<void> dispose() async {
    await _tts.stop();
    _completers.drainAll();
  }
}

/// Simple FIFO queue for completion tracking.
class _CompletionQueue {
  final _queue = <Completer<void>>[];
  void add(Completer<void> c) => _queue.add(c);
  Completer<void>? removeFirst() =>
      _queue.isNotEmpty ? _queue.removeAt(0) : null;
  void drainAll() {
    for (final c in _queue) {
      if (!c.isCompleted) c.complete();
    }
    _queue.clear();
  }
}
