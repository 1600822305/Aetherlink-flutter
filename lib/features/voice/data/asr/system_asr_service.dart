import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Native platform speech recognition using [SpeechToText].
/// Android: SpeechRecognizer
/// iOS: SFSpeechRecognizer
class SystemAsrService {
  SystemAsrService() : _speech = SpeechToText();

  final SpeechToText _speech;

  final _textController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _statusController = StreamController<bool>.broadcast();

  /// Emits recognized text (partial + final).
  Stream<String> get textStream => _textController.stream;

  /// Emits error messages.
  Stream<String> get errorStream => _errorController.stream;

  /// Emits listening state changes (true = listening).
  Stream<bool> get statusStream => _statusController.stream;

  bool get isListening => _speech.isListening;
  bool get isAvailable => _speech.isAvailable;

  /// Initialize the speech engine. Must be called before [start].
  /// Returns false if speech recognition is not available on this device.
  Future<bool> initialize() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      return available;
    } catch (e) {
      _errorController.add('初始化失败: $e');
      return false;
    }
  }

  /// Fetch available locales from the platform.
  Future<List<LocaleName>> getLocales() async {
    try {
      return await _speech.locales();
    } catch (_) {
      return [];
    }
  }

  /// Start listening. [localeId] e.g. "zh_CN", "en_US".
  /// [listenMode] controls partial vs final results.
  Future<void> start({
    String localeId = '',
    bool partialResults = true,
  }) async {
    if (_speech.isListening) {
      await _speech.stop();
    }

    if (!_speech.isAvailable) {
      final ok = await initialize();
      if (!ok) {
        _errorController.add('语音识别不可用');
        return;
      }
    }

    await _speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: localeId.isNotEmpty ? localeId : null,
        listenMode: partialResults
            ? ListenMode.dictation
            : ListenMode.confirmation,
        cancelOnError: false,
        partialResults: partialResults,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
    _statusController.add(true);
  }

  /// Stop listening.
  Future<void> stop() async {
    await _speech.stop();
    _statusController.add(false);
  }

  /// Cancel listening (discards partial results).
  Future<void> cancel() async {
    await _speech.cancel();
    _statusController.add(false);
  }

  void _onResult(SpeechRecognitionResult result) {
    _textController.add(result.recognizedWords);
  }

  void _onStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      _statusController.add(false);
    }
  }

  void _onError(SpeechRecognitionError error) {
    _errorController.add(error.errorMsg);
    _statusController.add(false);
  }

  Future<void> dispose() async {
    await _speech.stop();
    await _textController.close();
    await _errorController.close();
    await _statusController.close();
  }
}
