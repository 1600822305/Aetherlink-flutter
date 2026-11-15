import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/media_model_access.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';

/// Chip shown above the composer while a media mode (图像生成 / 视频生成) is
/// armed: names the configured media model and opens a capability-filtered
/// selector to switch it. Shows a "未配置" state instead when the slot is
/// empty, so the user learns where the generation call will go.
class MediaModeChip extends ConsumerWidget {
  const MediaModeChip({super.key, required this.mode});

  final InputMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isImage = mode == InputMode.image;
    final slot = ref
        .watch(
          isImage ? appMediaImageModelProvider : appMediaVideoModelProvider,
        )
        .value;
    final label = isImage ? '图像生成' : '视频生成';
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
                  isImage ? LucideIcons.image : LucideIcons.video,
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
    final isImage = mode == InputMode.image;
    final current = ref
        .read(isImage ? appMediaImageModelProvider : appMediaVideoModelProvider)
        .value;
    final ctrl = ref.read(mediaModelControllerProvider.notifier);
    showModelSelectorDialog(
      context,
      filter: isImage ? isGenerateImageModel : isGenerateVideoModel,
      selectedProviderId: current?.provider.id,
      selectedModelId: current?.model.id,
      onSelect: (provider, model) {
        if (isImage) {
          ctrl.setImageModel(provider.id, model.id);
        } else {
          ctrl.setVideoModel(provider.id, model.id);
        }
      },
    );
  }
}
