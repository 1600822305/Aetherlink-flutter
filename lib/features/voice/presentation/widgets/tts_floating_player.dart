import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/voice/application/tts_controller.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';

/// A floating TTS playback controller that appears at the bottom of the chat
/// page when TTS is active. Shows play/pause, skip, speed controls, and chunk
/// progress. Inspired by Kelivo's `TtsFloatingPlayer`.
class TtsFloatingPlayer extends ConsumerWidget {
  const TtsFloatingPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TtsPlaybackState playback;
    try {
      playback = ref.watch(ttsControllerProvider);
    } catch (_) {
      return const SizedBox.shrink();
    }

    // Only show when TTS is active.
    if (playback.status == TtsStatus.idle) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isPlaying = playback.status == TtsStatus.playing;
    final isLoading = playback.status == TtsStatus.loading;
    final isError = playback.status == TtsStatus.error;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Chunk progress indicator.
                  if (!isError)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${playback.currentChunk + 1}/${playback.totalChunks}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),

                  // Loading spinner or error icon.
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  if (isError)
                    Expanded(
                      child: Text(
                        playback.error ?? '语音合成失败',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  if (!isError) const Spacer(),

                  // Skip backward.
                  _PlayerButton(
                    icon: LucideIcons.skipBack,
                    onTap: playback.currentChunk > 0
                        ? () => ref.read(ttsControllerProvider.notifier).skipBackward()
                        : null,
                  ),
                  const SizedBox(width: 4),

                  // Play / Pause.
                  _PlayerButton(
                    icon: isPlaying ? LucideIcons.pause : LucideIcons.play,
                    size: 28,
                    onTap: isLoading
                        ? null
                        : () {
                            final ctrl = ref.read(ttsControllerProvider.notifier);
                            if (isPlaying) {
                              ctrl.pause();
                            } else {
                              ctrl.resume();
                            }
                          },
                  ),
                  const SizedBox(width: 4),

                  // Skip forward.
                  _PlayerButton(
                    icon: LucideIcons.skipForward,
                    onTap: playback.currentChunk + 1 < playback.totalChunks
                        ? () => ref.read(ttsControllerProvider.notifier).skipForward()
                        : null,
                  ),
                  const SizedBox(width: 8),

                  // Speed button.
                  _SpeedChip(
                    speed: playback.speed,
                    onTap: () {
                      final next = _nextSpeed(playback.speed);
                      ref.read(ttsControllerProvider.notifier).setSpeed(next);
                    },
                  ),
                  const SizedBox(width: 8),

                  // Stop button.
                  _PlayerButton(
                    icon: LucideIcons.x,
                    onTap: () => ref.read(ttsControllerProvider.notifier).stop(),
                  ),
                ],
              ),

              // Progress bar.
              if (!isError && playback.totalChunks > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: playback.totalChunks > 0
                          ? (playback.currentChunk + (isPlaying ? 0.5 : 0)) /
                              playback.totalChunks
                          : 0,
                      minHeight: 3,
                      backgroundColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static double _nextSpeed(double current) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final idx = speeds.indexWhere((s) => s >= current);
    if (idx < 0 || idx + 1 >= speeds.length) return speeds[0];
    return speeds[idx + 1];
  }
}

class _PlayerButton extends StatelessWidget {
  const _PlayerButton({
    required this.icon,
    this.onTap,
    this.size = 20,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: size,
          color: onTap != null
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.speed,
    required this.onTap,
  });

  final double speed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        ),
        child: Text(
          '${speed}x',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
