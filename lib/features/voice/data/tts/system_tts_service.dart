import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// System (on-device) TTS service — closely mirrors Kelivo's TtsProvider.
///
/// Architecture (matching kelivo):
/// - Uses QUEUE_ADD (1) so native `speak()` returns immediately with a status
///   code. This avoids the fatal hang that QUEUE_FLUSH causes when the engine
///   isn't bound (the native plugin queues the call and never returns a result).
/// - Relies on the completion handler callback to know when speech finishes.
/// - Uses a [Completer] so callers can `await speak(text)` and only continue
///   after the utterance completes.
/// - Retry escalation: speak → re-select engine → recreate engine.
class SystemTtsService {
  FlutterTts? _tts;
  bool _initialized = false;
  bool _engineReady = false;

  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(milliseconds: 180);
  static const Duration _bindTimeout = Duration(seconds: 5);
  static const Duration _rebindTimeout = Duration(seconds: 2);

  Completer<void>? _speakingCompleter;
  Future<void>? _initFuture;

  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onPause;
  VoidCallback? onContinue;
  void Function(String)? onError;

  /// Initializes the TTS engine. Must be called before [speak].
  /// Concurrent calls share the same initialization future (no double-init).
  Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _doInit();
    await _initFuture;
  }

  Future<void> _doInit() async {
    try {
      _tts = FlutterTts();
      _bindHandlers();
      await _kickEngine();
      await _ensureBound(timeout: _bindTimeout);
      await _selectEngine();
      await _applyConfig();
    } catch (_) {
      // Best-effort init. Even if binding fails here (common on MIUI),
      // _trySpeak's retry logic will handle it when speak is actually called.
    }
    _initialized = true;
  }

  /// Speaks [text] and waits until the utterance finishes.
  ///
  /// The speech rate / pitch should be pre-configured via [applyUserConfig].
  /// Internally uses kelivo's retry escalation if the first attempt fails.
  Future<void> speak(String text) async {
    await init();
    await _ensureBound();

    final ok = await _trySpeak(text);
    if (!ok) {
      throw Exception('系统 TTS 引擎无法朗读，请检查设备 TTS 设置');
    }

    // speak was queued successfully — wait for the completion handler to fire.
    // Completer is created here (after success) to avoid error callbacks during
    // retries from prematurely resolving it.
    //
    // Timeout guard: if the native engine silently fails (e.g. "speak failed:
    // not bound" is logged but the Kotlin plugin returned success anyway because
    // ismServiceConnectionUsable passed), no completion callback fires. Without
    // a timeout we'd hang forever. 30s is generous for any utterance chunk.
    _speakingCompleter = Completer<void>();
    await _speakingCompleter!.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _completeSpeaking();
      },
    );
  }

  /// Applies user-configured settings (engine, language, rate, pitch).
  Future<void> applyUserConfig({
    String? engineId,
    String? languageTag,
    double? speechRate,
    double? pitch,
  }) async {
    await init();
    if (engineId != null && engineId.isNotEmpty) {
      try {
        await _tts!.setEngine(engineId);
        // setEngine() on native side recreates the TextToSpeech instance.
        // The await above already blocks until the new engine's init listener
        // fires (engineResult.success is called in onInitListenerWithCallback).
      } catch (_) {}
    }
    if (languageTag != null && languageTag.isNotEmpty) {
      try {
        await _tts!.setLanguage(languageTag);
      } catch (_) {}
    }
    if (speechRate != null) {
      _currentRate = speechRate.clamp(0.1, 1.0);
      try {
        await _tts!.setSpeechRate(_currentRate);
      } catch (_) {}
    }
    if (pitch != null) {
      try {
        await _tts!.setPitch(pitch.clamp(0.5, 2.0));
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    _completeSpeaking();
    if (!_initialized) return;
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _tts?.pause();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _completeSpeaking();
    try {
      await _tts?.stop();
    } catch (_) {}
    _tts = null;
    _initialized = false;
    _engineReady = false;
  }

  Future<List<String>> listEngines() async {
    await init();
    try {
      final res = await _tts!.getEngines;
      if (res is List) return res.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  Future<List<String>> listLanguages() async {
    await init();
    try {
      final res = await _tts!.getLanguages;
      if (res is List) return res.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  // ---------------------------------------------------------------------------
  // Engine lifecycle (mirrors Kelivo exactly)
  // ---------------------------------------------------------------------------

  void _bindHandlers() {
    _tts!.setStartHandler(() {
      onStart?.call();
    });
    _tts!.setCompletionHandler(() {
      _completeSpeaking();
      onComplete?.call();
    });
    _tts!.setPauseHandler(() {
      onPause?.call();
    });
    _tts!.setContinueHandler(() {
      onContinue?.call();
    });
    _tts!.setCancelHandler(() {
      _completeSpeaking();
    });
    _tts!.setErrorHandler((msg) {
      _completeSpeaking();
      onError?.call(msg?.toString() ?? 'Unknown TTS error');
    });
  }

  /// Wake up the engine — getLanguages/getEngines will block (via native
  /// method channel queueing) until the TextToSpeech init listener fires.
  Future<void> _kickEngine() async {
    try {
      await _tts!.getLanguages;
    } catch (_) {}
    try {
      await _tts!.getEngines;
    } catch (_) {}
  }

  /// Poll until the engine reports available languages (matching kelivo).
  ///
  /// Note: on the native side, when ttsStatus is null (during init), method
  /// calls are queued and never return until init completes. So the first
  /// `getLanguages` call after init will naturally block until ready. This
  /// polling loop handles the edge case where the engine returns empty
  /// languages briefly after initialization.
  Future<void> _ensureBound({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_engineReady) return;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final langs = await _tts!.getLanguages;
        if (langs != null) {
          _engineReady = true;
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  /// Select the best engine — prefer Google TTS (matching kelivo).
  Future<void> _selectEngine() async {
    try {
      final engines = await _tts!.getEngines;
      if (engines is List && engines.isNotEmpty) {
        String? chosen;
        for (final e in engines) {
          final s = e.toString();
          if (s.toLowerCase().contains('google')) {
            chosen = s;
            break;
          }
        }
        chosen ??= engines.first.toString();
        try {
          await _tts!.setEngine(chosen);
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Apply default configuration (matching kelivo's _applyConfig).
  Future<void> _applyConfig() async {
    try {
      await _tts!.setSpeechRate(0.5);
    } catch (_) {}
    try {
      await _tts!.setPitch(1.0);
    } catch (_) {}
    try {
      await _tts!.setVolume(1.0);
    } catch (_) {}

    // Pick language based on device locale (matching kelivo)
    final loc = ui.PlatformDispatcher.instance.locale;
    final defaultTag = _localeToTag(loc);
    try {
      final res = await _tts!.isLanguageAvailable(defaultTag);
      if (res == true) {
        await _tts!.setLanguage(defaultTag);
      } else {
        final zh = loc.languageCode.toLowerCase().startsWith('zh');
        final fb = zh ? 'zh-CN' : 'en-US';
        final ok = await _tts!.isLanguageAvailable(fb);
        if (ok == true) {
          await _tts!.setLanguage(fb);
        }
      }
    } catch (_) {}

    try {
      await _tts!.awaitSpeakCompletion(true);
    } catch (_) {}
    try {
      await _tts!.awaitSynthCompletion(true);
    } catch (_) {}
    // QUEUE_ADD (1) — matching kelivo. With QUEUE_ADD, native speak() returns
    // immediately with a success/failure code. We use the completion handler
    // callback to know when speech actually finishes.
    // DO NOT use QUEUE_FLUSH (0): it causes speak() to hang forever if the
    // engine's service connection is not usable (native queues the call in
    // pendingMethodCalls and never returns a result).
    try {
      await _tts!.setQueueMode(1);
    } catch (_) {}
  }

  /// Recreate the engine from scratch (last resort, matching kelivo).
  Future<void> _recreateEngine() async {
    try {
      await _tts?.stop();
    } catch (_) {}
    _engineReady = false;
    _tts = FlutterTts();
    _bindHandlers();
    await _kickEngine();
    await _ensureBound(timeout: _rebindTimeout);
    await _selectEngine();
    await _applyConfig();
  }

  // ---------------------------------------------------------------------------
  // Speak with retry (mirrors Kelivo's _trySpeak exactly)
  // ---------------------------------------------------------------------------

  /// Try to speak with escalating retry strategies (matching kelivo).
  ///
  /// With QUEUE_ADD, `_tts.speak()` returns immediately with a status code:
  /// - 1 (or true): speak was successfully queued to the TTS engine
  /// - 0/null/false: speak failed (engine not bound, etc.)
  ///
  /// This does NOT mean speech has finished — only that it was accepted.
  /// The completion handler fires when the utterance actually completes.
  Future<bool> _trySpeak(String text) async {
    await _ensureBound();

    // Set speech rate before each speak (matching kelivo's _trySpeak)
    try {
      await _tts!.setSpeechRate(_currentRate);
    } catch (_) {}

    // Attempt 1: just speak
    dynamic res;
    try {
      res = await _tts!.speak(text, focus: true);
    } catch (_) {}
    if (_speakOk(res)) return true;

    // Attempt 2: re-select engine, retry
    await _selectEngine();
    for (var i = 0; i < _maxRetries; i++) {
      await Future<void>.delayed(_retryDelay);
      try {
        res = await _tts!.speak(text, focus: true);
      } catch (_) {}
      if (_speakOk(res)) return true;
    }

    // Attempt 3: completely recreate engine, retry
    await _recreateEngine();
    for (var i = 0; i < _maxRetries; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        res = await _tts!.speak(text, focus: true);
      } catch (_) {}
      if (_speakOk(res)) return true;
    }

    return false;
  }

  /// Check if the native speak() result indicates success (matching kelivo).
  bool _speakOk(dynamic res) {
    if (res == null) return false;
    if (res is int) return res == 1;
    if (res is bool) return res;
    final s = res.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'success';
  }

  void _completeSpeaking() {
    final c = _speakingCompleter;
    if (c != null && !c.isCompleted) c.complete();
    _speakingCompleter = null;
  }

  /// Current speech rate to apply before each speak call.
  double _currentRate = 0.5;

  /// Sets the speech rate for subsequent speak calls.
  void setSpeechRate(double rate) {
    _currentRate = rate.clamp(0.1, 1.0);
  }

  static String _localeToTag(ui.Locale l) {
    final lang = l.languageCode;
    final country = l.countryCode;
    if (country != null && country.isNotEmpty) return '$lang-$country';
    return lang;
  }
}
