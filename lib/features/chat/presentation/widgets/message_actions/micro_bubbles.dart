import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/tts_access.dart';
import 'package:aetherlink_flutter/features/voice/domain/tts_playback_state.dart';

class MicroBubble extends StatelessWidget {
  const MicroBubble({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      ),
    );
  }
}

/// The 语音播放 micro-bubble: swaps icon/background with live playback state.
class TtsMicroBubble extends ConsumerWidget {
  const TtsMicroBubble({
    super.key,
    required this.messageId,
    required this.baseColor,
    required this.pillColor,
    required this.onTap,
  });

  final String messageId;
  final Color baseColor;
  final Color pillColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TtsPlaybackState? ttsState;
    try {
      ttsState = ref.watch(ttsPlaybackProvider);
    } catch (_) {
      // Provider not ready — show default icon.
    }
    final isPlayingThis =
        ttsState != null &&
        ttsState.messageId == messageId &&
        (ttsState.status == TtsStatus.playing ||
            ttsState.status == TtsStatus.loading);
    // Original web 播放 chip: idle shows the muted icon + 「播放」, while playing
    // shows the speaker icon + 「播放中」. Like the web Chip, the icon/text keep
    // the 文本主色 and only the background switches to the 气泡激活色 — it never
    // recolors to the primary swatch.
    return LabeledBubble(
      icon: isPlayingThis ? LucideIcons.volume2 : LucideIcons.volumeX,
      label: isPlayingThis ? '播放中' : '播放',
      tooltip: isPlayingThis ? '停止播放' : '语音播放',
      color: baseColor,
      backgroundColor: isPlayingThis
          ? _activeColor(pillColor, baseColor)
          : pillColor,
      onTap: onTap,
    );
  }
}

/// A small pill-shaped 功能气泡 carrying an icon **and** a text label, mirroring
/// the original web Chip (e.g. the 播放/播放中 chip).
class LabeledBubble extends StatelessWidget {
  const LabeledBubble({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: kPillShadowColor,
        elevation: 1,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft drop shadow matching the original web chip's `0 1px 2px rgba(0,0,0,0.1)`.
const Color kPillShadowColor = Color(0x66000000);

/// The 气泡激活色: the original web swaps a chip to `--theme-msg-*-bg-active`
/// when active. We approximate it by nudging the 气泡底色 toward the 文本主色.
Color _activeColor(Color base, Color toward) =>
    Color.alphaBlend(toward.withValues(alpha: 0.14), base);

/// The 版本切换 control. In [VersionSwitchStyle.popup] it shows a pill with the
/// current index that opens the 版本历史 sheet; in [VersionSwitchStyle.arrows] it
/// shows `‹ n/total ›` arrows that step between versions (the final slot is the
/// 最新版本, like the history sheet).
