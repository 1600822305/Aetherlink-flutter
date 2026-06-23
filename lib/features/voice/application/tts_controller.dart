import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/voice/application/voice_settings_controller.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/network_tts_service.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/system_tts_service.dart';
import 'package:aetherlink_flutter/features/voice/data/tts/tts_text_chunker.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_text_chunk.dart';

part 'tts_controller.g.dart';

/// The central TTS controller: manages text chunking, synthesis (network or
/// system), audio playback, prefetching, and exposes an immutable
/// [TtsPlaybackState] for the UI.
///
/// Architecture follows Kelivo's `TtsProvider` (chunked playback + prefetch)
/// but uses Riverpod `Notifier` (the project's standard) instead of
/// `ChangeNotifier`.
@Riverpod(keepAlive: true)
class TtsController extends _$TtsController {
  final NetworkTtsService _networkTts = NetworkTtsService();
  SystemTtsService? _systemTts;
  final AudioPlayer _player = AudioPlayer();

  List<TtsTextChunk> _chunks = const [];
  final Map<int, Uint8List> _cache = {};
  CancelToken? _cancelToken;
  StreamSubscription<PlayerState>? _playerSub;

  @override
  TtsPlaybackState build() {
    ref.onDispose(_dispose);
    _playerSub = _player.onPlayerStateChanged.listen(_onPlayerStateChanged);
    return const TtsPlaybackState();
  }

  /// Starts speaking [text] for the given [messageId]. If already speaking the
  /// same message, toggles pause/resume. If speaking a different message, stops
  /// the current and starts the new one.
  Future<void> speak(String text, {required String messageId}) async {
    // Toggle pause/resume for the same message.
    if (state.messageId == messageId) {
      if (state.status == TtsStatus.playing) {
        await pause();
        return;
      }
      if (state.status == TtsStatus.paused) {
        await resume();
        return;
      }
    }

    await stop();

    final provider = ref.read(activeTtsProviderProvider);
    if (provider == null) {
      state = state.copyWith(
        status: TtsStatus.error,
        error: '未配置语音服务，请在设置中配置 TTS',
      );
      return;
    }

    _chunks = TtsTextChunker.split(text);
    if (_chunks.isEmpty) return;

    final speed = ref.read(voiceSettingsControllerProvider).defaultSpeed;

    state = TtsPlaybackState(
      status: TtsStatus.loading,
      messageId: messageId,
      activeProvider: provider.kind,
      totalChunks: _chunks.length,
      speed: speed,
    );

    await _playChunk(0, provider);
  }

  Future<void> pause() async {
    if (state.status != TtsStatus.playing) return;
    if (state.activeProvider == TtsProviderKind.system) {
      await _systemTts?.pause();
    } else {
      await _player.pause();
    }
    state = state.copyWith(status: TtsStatus.paused);
  }

  Future<void> resume() async {
    if (state.status != TtsStatus.paused) return;
    if (state.activeProvider == TtsProviderKind.system) {
      // System TTS doesn't support resume; replay current chunk.
      final provider = ref.read(activeTtsProviderProvider);
      if (provider != null && state.currentChunk < _chunks.length) {
        await _playChunk(state.currentChunk, provider);
      }
    } else {
      await _player.resume();
      state = state.copyWith(status: TtsStatus.playing);
    }
  }

  Future<void> stop() async {
    _cancelToken?.cancel();
    _cancelToken = null;
    await _systemTts?.stop();
    await _player.stop();
    _cache.clear();
    _chunks = const [];
    state = const TtsPlaybackState();
  }

  /// Skips to the next chunk.
  Future<void> skipForward() async {
    if (state.currentChunk + 1 >= _chunks.length) {
      await stop();
      return;
    }
    final provider = ref.read(activeTtsProviderProvider);
    if (provider == null) return;
    await _player.stop();
    await _playChunk(state.currentChunk + 1, provider);
  }

  /// Skips to the previous chunk.
  Future<void> skipBackward() async {
    if (state.currentChunk <= 0) return;
    final provider = ref.read(activeTtsProviderProvider);
    if (provider == null) return;
    await _player.stop();
    await _playChunk(state.currentChunk - 1, provider);
  }

  /// Sets playback speed.
  void setSpeed(double speed) {
    final clamped = speed.clamp(0.5, 2.0);
    _player.setPlaybackRate(clamped);
    state = state.copyWith(speed: clamped);
  }

  // -- Private ---------------------------------------------------------------

  Future<void> _playChunk(int index, TtsProviderSetting provider) async {
    if (index >= _chunks.length) {
      await stop();
      return;
    }

    state = state.copyWith(
      status: TtsStatus.loading,
      currentChunk: index,
    );

    try {
      if (provider.kind == TtsProviderKind.system) {
        _systemTts ??= SystemTtsService();
        state = state.copyWith(status: TtsStatus.playing);
        await _systemTts!.speak(_chunks[index].text, speed: state.speed);
        // System TTS completion — play next chunk.
        if (state.status == TtsStatus.playing) {
          await _playChunk(index + 1, provider);
        }
        return;
      }

      // Network TTS: synthesize (or use cache), then play via AudioPlayer.
      final bytes = await _synthesizeWithCache(index, provider);

      state = state.copyWith(status: TtsStatus.playing);
      await _player.setPlaybackRate(state.speed);
      await _player.play(BytesSource(bytes));

      // Prefetch the next few chunks.
      _prefetch(index + 1, provider, count: 3);
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) return;
      state = state.copyWith(
        status: TtsStatus.error,
        error: '语音合成失败: $e',
      );
    }
  }

  Future<Uint8List> _synthesizeWithCache(
    int index,
    TtsProviderSetting provider,
  ) async {
    if (_cache.containsKey(index)) return _cache[index]!;
    _cancelToken = CancelToken();
    final result = await _networkTts.synthesize(
      _chunks[index].text,
      provider,
      cancelToken: _cancelToken,
    );
    _cache[index] = result.bytes;
    return result.bytes;
  }

  void _prefetch(int startIndex, TtsProviderSetting provider, {int count = 3}) {
    for (var i = startIndex; i < startIndex + count && i < _chunks.length; i++) {
      if (_cache.containsKey(i)) continue;
      final idx = i;
      // Fire-and-forget prefetch.
      _networkTts
          .synthesize(_chunks[idx].text, provider)
          .then((result) => _cache[idx] = result.bytes)
          .catchError((Object _) => Uint8List(0));
    }
  }

  void _onPlayerStateChanged(PlayerState playerState) {
    if (playerState == PlayerState.completed && state.status == TtsStatus.playing) {
      // Current chunk finished — play next.
      final next = state.currentChunk + 1;
      if (next < _chunks.length) {
        final provider = ref.read(activeTtsProviderProvider);
        if (provider != null) {
          _playChunk(next, provider);
        }
      } else {
        state = const TtsPlaybackState();
      }
    }
  }

  void _dispose() {
    _cancelToken?.cancel();
    _playerSub?.cancel();
    _player.dispose();
    _systemTts?.dispose();
  }
}
