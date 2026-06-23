import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/voice/application/voice_settings_controller.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/openai_realtime_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/data/asr/whisper_asr_service.dart';
import 'package:aetherlink_flutter/features/voice/domain/asr_provider_setting.dart';

part 'asr_controller.g.dart';

/// ASR recording status.
enum AsrStatus {
  idle,
  recording,
  processing,
  error,
}

/// The ASR controller: manages microphone recording, speech recognition
/// (real-time streaming or batch Whisper), and exposes the recognized text.
///
/// Architecture follows RikkaHub's `ASRController` pattern but uses Riverpod
/// `Notifier`.
@riverpod
class AsrController extends _$AsrController {
  final AudioRecorder _recorder = AudioRecorder();
  final WhisperAsrService _whisper = WhisperAsrService();
  OpenaiRealtimeAsrService? _realtimeAsr;
  StreamSubscription<String>? _realtimeSub;
  StreamSubscription<RecordState>? _recorderSub;

  /// Accumulated audio bytes for Whisper mode.
  final _audioBuffer = <int>[];

  /// Stream subscription for audio data in streaming mode.
  StreamSubscription<Uint8List>? _audioStreamSub;

  @override
  ({AsrStatus status, String text, String? error}) build() {
    ref.onDispose(_dispose);
    return (status: AsrStatus.idle, text: '', error: null);
  }

  /// Starts recording and ASR. The recognized text accumulates in [state.text].
  Future<void> startRecording() async {
    if (state.status == AsrStatus.recording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      state = (
        status: AsrStatus.error,
        text: state.text,
        error: '需要麦克风权限',
      );
      return;
    }

    final provider = ref.read(activeAsrProviderProvider);
    if (provider == null) {
      state = (
        status: AsrStatus.error,
        text: state.text,
        error: '未配置语音识别服务',
      );
      return;
    }

    state = (status: AsrStatus.recording, text: '', error: null);

    try {
      if (provider.kind == AsrProviderKind.openaiRealtime) {
        await _startRealtimeRecording(provider);
      } else {
        await _startBatchRecording();
      }
    } catch (e) {
      state = (
        status: AsrStatus.error,
        text: state.text,
        error: '录音启动失败: $e',
      );
    }
  }

  /// Stops recording and (for batch mode) triggers transcription.
  Future<void> stopRecording() async {
    if (state.status != AsrStatus.recording) return;

    final provider = ref.read(activeAsrProviderProvider);

    if (provider?.kind == AsrProviderKind.openaiRealtime) {
      await _stopRealtimeRecording();
    } else {
      await _stopBatchRecording(provider);
    }
  }

  /// Cancels recording without processing.
  Future<void> cancelRecording() async {
    await _audioStreamSub?.cancel();
    _audioStreamSub = null;
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await _realtimeAsr?.stop();
    await _recorder.cancel();
    _audioBuffer.clear();
    state = (status: AsrStatus.idle, text: '', error: null);
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

    // Start recording and stream PCM16 audio to the WebSocket.
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
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

    // Give a short delay for final transcription events.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await _realtimeAsr?.stop();
    _realtimeAsr = null;

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
      state = (
        status: AsrStatus.error,
        text: state.text,
        error: '语音识别失败: $e',
      );
    } finally {
      _audioBuffer.clear();
    }
  }

  void _dispose() {
    _audioStreamSub?.cancel();
    _realtimeSub?.cancel();
    _recorderSub?.cancel();
    _realtimeAsr?.dispose();
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
