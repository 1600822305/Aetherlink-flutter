import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/voice/application/voice_settings_controller.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/dashscope_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/mimo_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/step_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/openai_realtime_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/system_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/volcengine_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/whisper_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

part 'asr_controller.g.dart';

/// ASR recording status.
enum AsrStatus { idle, recording, processing, error }

/// The ASR controller: manages microphone recording, speech recognition
/// (system native, real-time streaming, or batch Whisper), and exposes the
/// recognized text.
@riverpod
class AsrController extends _$AsrController {
  final AudioRecorder _recorder = AudioRecorder();
  final WhisperAsrService _whisper = WhisperAsrService();
  OpenaiRealtimeAsrService? _realtimeAsr;
  DashScopeAsrService? _dashscopeAsr;
  VolcengineAsrService? _volcengineAsr;
  MimoAsrService? _mimoAsr;
  StepAsrService? _stepAsr;
  SystemAsrService? _systemAsr;
  StreamSubscription<String>? _realtimeSub;
  StreamSubscription<String>? _realtimeErrorSub;
  StreamSubscription<String>? _dashscopeSub;
  StreamSubscription<String>? _dashscopeErrorSub;
  StreamSubscription<String>? _volcengineSub;
  StreamSubscription<String>? _volcengineErrorSub;
  StreamSubscription<String>? _mimoSub;
  StreamSubscription<String>? _mimoErrorSub;
  StreamSubscription<String>? _stepSub;
  StreamSubscription<String>? _stepErrorSub;
  StreamSubscription<String>? _systemTextSub;
  StreamSubscription<String>? _systemErrorSub;
  StreamSubscription<bool>? _systemStatusSub;
  StreamSubscription<RecordState>? _recorderSub;

  /// Accumulated audio bytes for Whisper mode.
  final _audioBuffer = <int>[];

  /// Stream subscription for audio data in streaming mode.
  StreamSubscription<Uint8List>? _audioStreamSub;

  /// Tracks the last final text from system ASR to avoid duplicates.
  String _lastSystemText = '';

  @override
  ({AsrStatus status, String text, String? error}) build() {
    ref.onDispose(_dispose);
    return (status: AsrStatus.idle, text: '', error: null);
  }

  /// Starts recording and ASR. The recognized text accumulates in [state.text].
  Future<void> startRecording() async {
    if (state.status == AsrStatus.recording) return;

    final provider = ref.read(activeAsrProviderProvider);
    if (provider == null) {
      state = (status: AsrStatus.error, text: state.text, error: '未配置语音识别服务');
      return;
    }

    // System ASR doesn't need the record package permission check.
    if (provider.kind != AsrProviderKind.system) {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = (status: AsrStatus.error, text: state.text, error: '需要麦克风权限');
        return;
      }
    }

    state = (status: AsrStatus.recording, text: '', error: null);
    _lastSystemText = '';

    try {
      switch (provider.kind) {
        case AsrProviderKind.system:
          await _startSystemRecording(provider);
        case AsrProviderKind.openaiRealtime:
          await _startRealtimeRecording(provider);
        case AsrProviderKind.dashscope:
          await _startDashscopeRecording(provider);
        case AsrProviderKind.volcengine:
          await _startVolcengineRecording(provider);
        case AsrProviderKind.mimo:
          await _startMimoRecording(provider);
        case AsrProviderKind.step:
          await _startStepRecording(provider);
        case AsrProviderKind.whisper:
          await _startBatchRecording();
      }
    } catch (e) {
      state = (status: AsrStatus.error, text: state.text, error: '录音启动失败: $e');
    }
  }

  /// Stops recording and (for batch mode) triggers transcription.
  Future<void> stopRecording() async {
    if (state.status != AsrStatus.recording) return;

    final provider = ref.read(activeAsrProviderProvider);

    switch (provider?.kind) {
      case AsrProviderKind.system:
        await _stopSystemRecording();
      case AsrProviderKind.openaiRealtime:
        await _stopRealtimeRecording();
      case AsrProviderKind.dashscope:
        await _stopDashscopeRecording();
      case AsrProviderKind.volcengine:
        await _stopVolcengineRecording();
      case AsrProviderKind.mimo:
        await _stopMimoRecording();
      case AsrProviderKind.step:
        await _stopStepRecording();
      case AsrProviderKind.whisper:
      case null:
        await _stopBatchRecording(provider);
    }
  }

  /// Cancels recording without processing.
  Future<void> cancelRecording() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await _realtimeErrorSub?.cancel();
    _realtimeErrorSub = null;
    await _realtimeAsr?.stop();
    await _dashscopeSub?.cancel();
    _dashscopeSub = null;
    await _dashscopeErrorSub?.cancel();
    _dashscopeErrorSub = null;
    await _dashscopeAsr?.stop();
    await _volcengineSub?.cancel();
    _volcengineSub = null;
    await _volcengineErrorSub?.cancel();
    _volcengineErrorSub = null;
    await _volcengineAsr?.stop();
    await _mimoSub?.cancel();
    _mimoSub = null;
    await _mimoErrorSub?.cancel();
    _mimoErrorSub = null;
    await _mimoAsr?.stop();
    await _stepSub?.cancel();
    _stepSub = null;
    await _stepErrorSub?.cancel();
    _stepErrorSub = null;
    await _stepAsr?.stop();
    await _systemTextSub?.cancel();
    _systemTextSub = null;
    await _systemErrorSub?.cancel();
    _systemErrorSub = null;
    await _systemStatusSub?.cancel();
    _systemStatusSub = null;
    await _systemAsr?.cancel();
    await _recorder.cancel();
    _audioBuffer.clear();
    _lastSystemText = '';
    state = (status: AsrStatus.idle, text: '', error: null);
  }

  // -- System native ASR (speech_to_text) ------------------------------------

  Future<void> _startSystemRecording(AsrProviderSetting provider) async {
    _systemAsr = SystemAsrService();
    final available = await _systemAsr!.initialize();
    if (!available) {
      _systemAsr = null;
      state = (
        status: AsrStatus.error,
        text: state.text,
        error: '系统语音识别不可用，请检查设备是否支持',
      );
      return;
    }

    _systemTextSub = _systemAsr!.textStream.listen((text) {
      // speech_to_text emits the full recognized text each time (not deltas),
      // so we replace the state text directly.
      if (text.isNotEmpty) {
        _lastSystemText = text;
        state = (status: AsrStatus.recording, text: text, error: null);
      }
    });

    _systemErrorSub = _systemAsr!.errorStream.listen((err) {
      // "error_speech_timeout" / "error_no_match" are transient — don't
      // override good text the user already got.
      if (err.contains('timeout') || err.contains('no_match')) return;
      state = (status: AsrStatus.error, text: state.text, error: '识别错误: $err');
    });

    _systemStatusSub = _systemAsr!.statusStream.listen((listening) {
      // When the engine stops on its own (e.g. silence timeout), update state.
      if (!listening && state.status == AsrStatus.recording) {
        state = (status: AsrStatus.idle, text: _lastSystemText, error: null);
      }
    });

    await _systemAsr!.start(
      localeId: provider.language.isNotEmpty ? provider.language : '',
      partialResults: true,
    );
  }

  Future<void> _stopSystemRecording() async {
    await _systemAsr?.stop();
    await _systemTextSub?.cancel();
    _systemTextSub = null;
    await _systemErrorSub?.cancel();
    _systemErrorSub = null;
    await _systemStatusSub?.cancel();
    _systemStatusSub = null;
    _systemAsr = null;
    state = (status: AsrStatus.idle, text: _lastSystemText, error: null);
  }

  // -- Real-time streaming ASR -----------------------------------------------

  Future<void> _startRealtimeRecording(AsrProviderSetting provider) async {
    _realtimeAsr = OpenaiRealtimeAsrService();
    await _realtimeAsr!.start(provider);

    _realtimeSub = _realtimeAsr!.textStream.listen(
      (delta) {
        state = (
          status: AsrStatus.recording,
          text: state.text + delta,
          error: null,
        );
      },
      onError: (Object error) {
        state = (
          status: AsrStatus.error,
          text: state.text,
          error: '识别错误: $error',
        );
      },
    );

    // Listen for server-side errors.
    _realtimeErrorSub = _realtimeAsr!.errorStream.listen((err) {
      state = (status: AsrStatus.error, text: state.text, error: '识别错误: $err');
    });

    // Stream PCM16 audio at 24 kHz (official Realtime API requirement).
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: OpenaiRealtimeAsrService.sampleRate,
        numChannels: 1,
      ),
    );
    _audioStreamSub = stream.listen((bytes) {
      _realtimeAsr?.sendAudio(bytes);
    });
  }

  Future<void> _stopRealtimeRecording() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _recorder.stop();

    // For gpt-realtime-whisper (no server VAD), manually commit the buffer
    // so that transcription of the final audio is triggered.
    _realtimeAsr?.commitAudioBuffer();

    // Give a short delay for final transcription events.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await _realtimeErrorSub?.cancel();
    _realtimeErrorSub = null;
    await _realtimeAsr?.stop();
    _realtimeAsr = null;

    state = (status: AsrStatus.idle, text: state.text, error: null);
  }

  // -- DashScope (Qwen-ASR-Realtime) streaming ASR ---------------------------

  Future<void> _startDashscopeRecording(AsrProviderSetting provider) async {
    _dashscopeAsr = DashScopeAsrService();
    await _dashscopeAsr!.start(provider);

    // DashScope emits the full transcript each time, so replace state text.
    _dashscopeSub = _dashscopeAsr!.textStream.listen(
      (text) {
        state = (status: AsrStatus.recording, text: text, error: null);
      },
      onError: (Object error) {
        state = (
          status: AsrStatus.error,
          text: state.text,
          error: '识别错误: $error',
        );
      },
    );

    _dashscopeErrorSub = _dashscopeAsr!.errorStream.listen((err) {
      state = (status: AsrStatus.error, text: state.text, error: '识别错误: $err');
    });

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: provider.sampleRate,
        numChannels: 1,
      ),
    );
    _audioStreamSub = stream.listen((bytes) {
      _dashscopeAsr?.sendAudio(bytes);
    });
  }

  Future<void> _stopDashscopeRecording() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _recorder.stop();

    // In manual mode, commit the buffered audio to trigger final recognition.
    _dashscopeAsr?.commitAudioBuffer();
    _dashscopeAsr?.finish();

    // Give a short delay for final transcription events.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    await _dashscopeSub?.cancel();
    _dashscopeSub = null;
    await _dashscopeErrorSub?.cancel();
    _dashscopeErrorSub = null;
    await _dashscopeAsr?.stop();
    _dashscopeAsr = null;

    state = (status: AsrStatus.idle, text: state.text, error: null);
  }

  // -- Volcengine (字节火山引擎) streaming ASR ----------------------------------

  Future<void> _startVolcengineRecording(AsrProviderSetting provider) async {
    _volcengineAsr = VolcengineAsrService();
    await _volcengineAsr!.start(provider);

    // Volcengine emits the full transcript each time, so replace state text.
    _volcengineSub = _volcengineAsr!.textStream.listen(
      (text) {
        state = (status: AsrStatus.recording, text: text, error: null);
      },
      onError: (Object error) {
        state = (
          status: AsrStatus.error,
          text: state.text,
          error: '识别错误: $error',
        );
      },
    );

    _volcengineErrorSub = _volcengineAsr!.errorStream.listen((err) {
      state = (status: AsrStatus.error, text: state.text, error: '识别错误: $err');
    });

    // Volcengine only supports 16 kHz PCM16 mono input.
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: VolcengineAsrService.sampleRate,
        numChannels: 1,
      ),
    );
    _audioStreamSub = stream.listen((bytes) {
      _volcengineAsr?.sendAudio(bytes);
    });
  }

  Future<void> _stopVolcengineRecording() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _recorder.stop();

    // Signal end-of-stream so the server returns the final result.
    _volcengineAsr?.finish();

    // Give a short delay for final transcription frames.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    await _volcengineSub?.cancel();
    _volcengineSub = null;
    await _volcengineErrorSub?.cancel();
    _volcengineErrorSub = null;
    await _volcengineAsr?.stop();
    _volcengineAsr = null;

    state = (status: AsrStatus.idle, text: state.text, error: null);
  }

  // -- MiMo (小米) HTTP segmented ASR -----------------------------------------

  Future<void> _startMimoRecording(AsrProviderSetting provider) async {
    _mimoAsr = MimoAsrService();
    _mimoAsr!.start(provider);

    // MiMo emits the full accumulated transcript each time, so replace text.
    _mimoSub = _mimoAsr!.textStream.listen(
      (text) {
        state = (status: AsrStatus.recording, text: text, error: null);
      },
      onError: (Object error) {
        state = (
          status: AsrStatus.error,
          text: state.text,
          error: '识别错误: $error',
        );
      },
    );

    _mimoErrorSub = _mimoAsr!.errorStream.listen((err) {
      state = (status: AsrStatus.error, text: state.text, error: '识别错误: $err');
    });

    // MiMo expects 16 kHz PCM16 mono input.
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: MimoAsrService.sampleRate,
        numChannels: 1,
      ),
    );
    _audioStreamSub = stream.listen((bytes) {
      _mimoAsr?.sendAudio(bytes);
    });
  }

  Future<void> _stopMimoRecording() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _recorder.stop();

    state = (status: AsrStatus.processing, text: state.text, error: null);

    // Upload the remaining buffered audio and wait for all segments.
    await _mimoAsr?.finish();

    await _mimoSub?.cancel();
    _mimoSub = null;
    await _mimoErrorSub?.cancel();
    _mimoErrorSub = null;
    await _mimoAsr?.stop();
    _mimoAsr = null;

    state = (status: AsrStatus.idle, text: state.text, error: null);
  }

  // -- Step (阶跃星辰) HTTP segmented + SSE streaming ASR -------------------

  Future<void> _startStepRecording(AsrProviderSetting provider) async {
    _stepAsr = StepAsrService();
    _stepAsr!.start(provider);

    // Step emits the full accumulated transcript each time, so replace text.
    _stepSub = _stepAsr!.textStream.listen(
      (text) {
        state = (status: AsrStatus.recording, text: text, error: null);
      },
      onError: (Object error) {
        state = (
          status: AsrStatus.error,
          text: state.text,
          error: '识别错误: $error',
        );
      },
    );

    _stepErrorSub = _stepAsr!.errorStream.listen((err) {
      state = (status: AsrStatus.error, text: state.text, error: '识别错误: $err');
    });

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: StepAsrService.sampleRate,
        numChannels: 1,
      ),
    );
    _audioStreamSub = stream.listen((bytes) {
      _stepAsr?.sendAudio(bytes);
    });
  }

  Future<void> _stopStepRecording() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _recorder.stop();

    state = (status: AsrStatus.processing, text: state.text, error: null);

    // Upload the remaining buffered audio and wait for all segments.
    await _stepAsr?.finish();

    await _stepSub?.cancel();
    _stepSub = null;
    await _stepErrorSub?.cancel();
    _stepErrorSub = null;
    await _stepAsr?.stop();
    _stepAsr = null;

    state = (status: AsrStatus.idle, text: state.text, error: null);
  }

  // -- Batch (Whisper) ASR ---------------------------------------------------

  Future<void> _startBatchRecording() async {
    _audioBuffer.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _audioStreamSub = stream.listen((bytes) {
      _audioBuffer.addAll(bytes);
    });
  }

  Future<void> _stopBatchRecording(AsrProviderSetting? provider) async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _recorder.stop();

    if (_audioBuffer.isEmpty || provider == null) {
      state = (status: AsrStatus.idle, text: state.text, error: null);
      return;
    }

    state = (status: AsrStatus.processing, text: state.text, error: null);

    try {
      // Wrap raw PCM in WAV header for the Whisper API.
      final wavBytes = _pcm16ToWav(
        Uint8List.fromList(_audioBuffer),
        sampleRate: 16000,
      );
      final text = await _whisper.transcribe(wavBytes, provider);
      state = (status: AsrStatus.idle, text: text, error: null);
    } catch (e) {
      state = (status: AsrStatus.error, text: state.text, error: '语音识别失败: $e');
    } finally {
      _audioBuffer.clear();
    }
  }

  void _dispose() {
    _audioStreamSub?.cancel();
    _realtimeSub?.cancel();
    _realtimeErrorSub?.cancel();
    _dashscopeSub?.cancel();
    _dashscopeErrorSub?.cancel();
    _volcengineSub?.cancel();
    _volcengineErrorSub?.cancel();
    _mimoSub?.cancel();
    _mimoErrorSub?.cancel();
    _stepSub?.cancel();
    _stepErrorSub?.cancel();
    _recorderSub?.cancel();
    _systemTextSub?.cancel();
    _systemErrorSub?.cancel();
    _systemStatusSub?.cancel();
    _realtimeAsr?.dispose();
    _dashscopeAsr?.dispose();
    _volcengineAsr?.dispose();
    _mimoAsr?.dispose();
    _stepAsr?.dispose();
    _systemAsr?.dispose();
    _recorder.dispose();
  }

  /// Wraps raw PCM16 data in a minimal WAV header.
  static Uint8List _pcm16ToWav(
    Uint8List pcm, {
    int sampleRate = 16000,
    int channels = 1,
    int bitsPerSample = 16,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcm.length;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    // RIFF
    buffer.setUint8(0, 0x52);
    buffer.setUint8(1, 0x49);
    buffer.setUint8(2, 0x46);
    buffer.setUint8(3, 0x46);
    buffer.setUint32(4, fileSize, Endian.little);
    // WAVE
    buffer.setUint8(8, 0x57);
    buffer.setUint8(9, 0x41);
    buffer.setUint8(10, 0x56);
    buffer.setUint8(11, 0x45);
    // fmt
    buffer.setUint8(12, 0x66);
    buffer.setUint8(13, 0x6d);
    buffer.setUint8(14, 0x74);
    buffer.setUint8(15, 0x20);
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, channels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    // data
    buffer.setUint8(36, 0x64);
    buffer.setUint8(37, 0x61);
    buffer.setUint8(38, 0x74);
    buffer.setUint8(39, 0x61);
    buffer.setUint32(40, dataSize, Endian.little);
    final bytes = buffer.buffer.asUint8List();
    bytes.setRange(44, 44 + dataSize, pcm);
    return bytes;
  }
}
