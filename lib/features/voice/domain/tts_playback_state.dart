import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_provider_setting.dart';

part 'tts_playback_state.freezed.dart';

/// The playback status of the TTS controller.
enum TtsStatus {
  idle,
  loading,
  playing,
  paused,
  error,
}

/// The full playback state exposed by the TTS controller. Immutable so Riverpod
/// re-renders only on actual changes.
@freezed
abstract class TtsPlaybackState with _$TtsPlaybackState {
  const factory TtsPlaybackState({
    @Default(TtsStatus.idle) TtsStatus status,
    /// The message ID whose content is being spoken.
    String? messageId,
    /// Which provider is currently active.
    TtsProviderKind? activeProvider,
    /// Current chunk index (0-based).
    @Default(0) int currentChunk,
    /// Total number of chunks.
    @Default(0) int totalChunks,
    /// Playback speed multiplier.
    @Default(1.0) double speed,
    /// Error description when [status] is [TtsStatus.error].
    String? error,
  }) = _TtsPlaybackState;
}
