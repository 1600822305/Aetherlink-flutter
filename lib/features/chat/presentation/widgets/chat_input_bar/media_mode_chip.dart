import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/media_model_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';

/// Chip shown above the composer while a media mode (图像生成 / 视频生成 /
/// 音频生成) is armed: names the configured media model and opens a
/// capability-filtered selector to switch it. Shows a "未配置" state instead
/// when the slot is empty, so the user learns where the generation call will go.
class MediaModeChip extends ConsumerWidget {
  const MediaModeChip({super.key, required this.mode});

  final InputMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slotProvider = switch (mode) {
      InputMode.image => appMediaImageModelProvider,
      InputMode.video => appMediaVideoModelProvider,
      _ => appMediaAudioModelProvider,
    };
    final slot = ref.watch(slotProvider).value;
    final label = switch (mode) {
      InputMode.image => '图像生成',
      InputMode.video => '视频生成',
      _ => '音频生成',
    };
    final modelName = slot?.model.name ?? '未配置模型';

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _select(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  switch (mode) {
                    InputMode.image => LucideIcons.image,
                    InputMode.video => LucideIcons.video,
                    _ => LucideIcons.audioLines,
                  },
                  size: 13,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    '$label · $modelName',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  LucideIcons.chevronDown,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _select(BuildContext context, WidgetRef ref) {
    final slotProvider = switch (mode) {
      InputMode.image => appMediaImageModelProvider,
      InputMode.video => appMediaVideoModelProvider,
      _ => appMediaAudioModelProvider,
    };
    final filter = switch (mode) {
      InputMode.image => isGenerateImageModel,
      InputMode.video => isGenerateVideoModel,
      _ => isGenerateAudioModel,
    };
    final current = ref.read(slotProvider).value;
    final ctrl = ref.read(mediaModelControllerProvider.notifier);
    showModelSelectorDialog(
      context,
      filter: filter,
      selectedProviderId: current?.provider.id,
      selectedModelId: current?.model.id,
      onSelect: (provider, model) {
        switch (mode) {
          case InputMode.image:
            ctrl.setImageModel(provider.id, model.id);
          case InputMode.video:
            ctrl.setVideoModel(provider.id, model.id);
          case InputMode.audio:
            ctrl.setAudioModel(provider.id, model.id);
          default:
        }
      },
    );
  }
}
