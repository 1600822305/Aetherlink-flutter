import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Robust wrapper around `flutter_tts` for system (on-device) TTS.
///
/// Mirrors Kelivo's engine initialization strategy:
/// 1. Create FlutterTts and "kick" the engine (getLanguages/getEngines)
/// 2. Poll until the engine is bound (getLanguages returns non-null)
/// 3. Select the best engine (prefer Google)
/// 4. Apply config (rate, pitch, volume, language, queue mode)
/// 5. On speak failure: retry → re-select engine → recreate engine
class SystemTtsService {
  FlutterTts? _tts;
  bool _initialized = false;
  bool _engineReady = false;

  static const int _maxRetries = 5;
  static const Duration _retryDelay = Duration(milliseconds: 180);
  static const Duration _bindTimeout = Duration(seconds: 5);
  static const Duration _rebindTimeout = Duration(seconds: 2);

  Completer<void>? _speakingCompleter;

  VoidCallback? onStart;
  VoidCallback? onComplete;
  VoidCallback? onPause;
  VoidCallback? onContinue;
  void Function(String)? onError;

  /// Initializes the TTS engine. Must be called before [speak].
  Future<void> init() async {
    if (_initialized) return;
    _tts = FlutterTts();
    _bindHandlers();
    await _kickEngine();
    await _ensureBound(timeout: _bindTimeout);
    await _selectEngine();
    await _applyConfig();
    _initialized = true;
  }

  /// Speaks [text] using the device's built-in TTS engine.
  Future<void> speak(String text, {double speed = 1.0}) async {
    await init();
    try {
      await _tts!.setSpeechRate(speed.clamp(0.1, 1.0));
    } catch (_) {}
    if (!await _trySpeak(text)) {
      throw Exception('系统 TTS 引擎无法朗读，请检查设备 TTS 设置');
    }
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
      } catch (_) {}
    }
    if (languageTag != null && languageTag.isNotEmpty) {
      try {
        await _tts!.setLanguage(languageTag);
      } catch (_) {}
    }
    if (speechRate != null) {
      try {
        await _tts!.setSpeechRate(speechRate.clamp(0.1, 1.0));
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
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _tts?.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      // flutter_tts doesn't have a resume method; Kelivo restarts the chunk.
      // We rely on TtsController to handle resume by replaying the chunk.
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
  // Engine lifecycle (mirrors Kelivo's _kickEngine / _ensureBound / _selectEngine)
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

  /// Wake up the engine by calling getLanguages/getEngines.
  Future<void> _kickEngine() async {
    try {
      await _tts!.getLanguages;
    } catch (_) {}
    try {
      await _tts!.getEngines;
    } catch (_) {}
  }

  /// Poll until the engine reports available languages.
  Future<void> _ensureBound({Duration timeout = const Duration(seconds: 3)}) async {
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
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  /// Select the best engine — prefer Google TTS.
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

  /// Apply configuration: rate, pitch, volume, language, queue mode.
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

    // Pick language based on device locale
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
      await _tts!.setQueueMode(1);
    } catch (_) {}
  }

  /// Recreate the engine from scratch (last resort).
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
  // Speak with retry (mirrors Kelivo's _trySpeak)
  // ---------------------------------------------------------------------------

  /// Try to speak, with escalating retry strategies.
  Future<bool> _trySpeak(String text) async {
    await _ensureBound();

    // Attempt 1: just speak
    if (_speakOk(await _doSpeak(text))) return true;

    // Attempt 2: re-select engine, retry up to _maxRetries times
    await _selectEngine();
    for (var i = 0; i < _maxRetries; i++) {
      await Future<void>.delayed(_retryDelay);
      if (_speakOk(await _doSpeak(text))) return true;
    }

    // Attempt 3: completely recreate engine, retry up to _maxRetries times
    await _recreateEngine();
    for (var i = 0; i < _maxRetries; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_speakOk(await _doSpeak(text))) return true;
    }

    return false;
  }

  Future<dynamic> _doSpeak(String text) async {
    try {
      return await _tts!.speak(text, focus: true);
    } catch (_) {
      return null;
    }
  }

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

  static String _localeToTag(ui.Locale l) {
    final lang = l.languageCode;
    final country = l.countryCode;
    if (country != null && country.isNotEmpty) return '$lang-$country';
    return lang;
  }
}
