import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_chat_background.dart';

// ── 基础 ─────────────────────────────────────────────────────────────────────

class BasicTab extends StatelessWidget {
  const BasicTab({
    super.key,
    required this.assistant,
    required this.nameController,
    required this.avatarDisplayText,
    required this.hasAvatarImage,
    required this.onEditAvatar,
    required this.chatBackground,
    required this.onChatBackgroundChanged,
    required this.onPickWallpaper,
    this.avatarImage,
  });

  final Assistant? assistant;
  final TextEditingController nameController;
  final String avatarDisplayText;
  final bool hasAvatarImage;
  final MemoryImage? avatarImage;
  final VoidCallback onEditAvatar;
  final AssistantChatBackground chatBackground;
  final ValueChanged<AssistantChatBackground> onChatBackgroundChanged;
  final Future<void> Function() onPickWallpaper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final image = avatarImage;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onEditAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    backgroundImage: hasAvatarImage && image != null
                        ? image
                        : null,
                    child: hasAvatarImage && image != null
                        ? null
                        : Text(
                            avatarDisplayText,
                            style: TextStyle(
                              fontSize: 22,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.pencil,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(theme, '助手名称'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameController,
                    autofocus: false,
                    style: TextStyle(fontSize: isMobile ? 16 : 14),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '示例助手',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(theme, '聊天壁纸'),
                  const SizedBox(height: 4),
                  Text(
                    '助手壁纸优先级高于全局设置',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CustomSwitch(
              value: chatBackground.enabled,
              onChanged: (v) =>
                  onChatBackgroundChanged(chatBackground.copyWith(enabled: v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WallpaperArea(
          imageUrl: chatBackground.imageUrl,
          onPick: onPickWallpaper,
          onRemove: () => onChatBackgroundChanged(
            chatBackground.copyWith(imageUrl: '', enabled: false),
          ),
        ),
        if (chatBackground.enabled && chatBackground.imageUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          _label(
            theme,
            '背景透明度  ${((chatBackground.opacity ?? 0.7) * 100).round()}%',
          ),
          Slider(
            min: 0.1,
            max: 1,
            divisions: 9,
            value: (chatBackground.opacity ?? 0.7).clamp(0.1, 1),
            label: '${((chatBackground.opacity ?? 0.7) * 100).round()}%',
            onChanged: (v) =>
                onChatBackgroundChanged(chatBackground.copyWith(opacity: v)),
          ),
          Row(
            children: [
              Expanded(
                child: Text('显示渐变遮罩', style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(width: 12),
              CustomSwitch(
                value: chatBackground.showOverlay ?? true,
                onChanged: (v) => onChatBackgroundChanged(
                  chatBackground.copyWith(showOverlay: v),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

Widget _label(ThemeData theme, String text) => Text(
  text,
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: theme.colorScheme.onSurfaceVariant,
  ),
);

/// The assistant wallpaper picker: a tap-to-upload dropzone, or a preview with
/// a remove affordance once an image is set (mirrors the global 聊天背景设置
/// `_ImageArea`).
class _WallpaperArea extends StatelessWidget {
  const _WallpaperArea({
    required this.imageUrl,
    required this.onPick,
    required this.onRemove,
  });

  final String imageUrl;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;

  MemoryImage? _decode() {
    final marker = imageUrl.indexOf('base64,');
    if (marker < 0) return null;
    try {
      return MemoryImage(base64Decode(imageUrl.substring(marker + 7)));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = _decode();

    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image(
              image: image,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(LucideIcons.x, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor, width: 2),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.imagePlus,
              size: 26,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              '点击上传壁纸',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
