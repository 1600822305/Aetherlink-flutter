import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/settings/application/chat_interface_settings_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';

/// The "聊天界面设置" sub-page (外观设置 → this page), a compact port of the
/// original `src/pages/Settings/ChatInterfaceSettings.tsx`.
///
/// Mirrors the original's icon-tinted Paper cards (24px radius, 1px divider
/// border, no shadow), the `CustomSwitch`, dropdowns and the collapsible chat
/// background block. Every option is persisted via
/// [ChatInterfaceSettingsController]. The behaviours that drive the chat view
/// (multi-model layout, tool / citation details, the wallpaper render) are not
/// wired into the chat page yet, so the page shows an "即将支持" note and only
/// saves the configuration for now.
class ChatInterfaceSettingsPage extends ConsumerWidget {
  const ChatInterfaceSettingsPage({super.key});

  static const String _title = '聊天界面设置';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(chatInterfaceSettingsControllerProvider);
    final controller = ref.read(
      chatInterfaceSettingsControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.appearancePath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(_title),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const _PendingNote(),
          const SizedBox(height: 16),
          _MultiModelCard(
            value: settings.multiModelDisplayStyle,
            onChanged: controller.setMultiModelDisplayStyle,
          ),
          _SwitchCard(
            icon: LucideIcons.messageSquare,
            hue: const Color(0xFF6366F1),
            title: '工具调用设置',
            description: '控制是否显示工具调用的详细信息，包括调用参数和返回结果。',
            value: settings.showToolDetails,
            onChanged: controller.setShowToolDetails,
          ),
          _SwitchCard(
            icon: LucideIcons.quote,
            hue: const Color(0xFF10B981),
            title: '引用设置',
            description: '控制是否显示引用的详细信息，包括引用来源和相关内容。',
            value: settings.showCitationDetails,
            onChanged: controller.setShowCitationDetails,
          ),
          _SwitchCard(
            icon: LucideIcons.fileText,
            hue: const Color(0xFFF59E0B),
            title: '系统提示词气泡设置',
            description: '控制是否在聊天界面顶部显示系统提示词气泡。系统提示词气泡可以帮助您查看和编辑当前会话的系统提示词。',
            value: settings.showSystemPromptBubble,
            onChanged: controller.setShowSystemPromptBubble,
          ),
          _BackgroundCard(
            value: settings.background,
            onChanged: controller.setBackground,
          ),
        ],
      ),
    );
  }
}

/// `ChatInterfaceSettings.tsx` `cardStyle`: `mb:2` (16px) gap, `p:2.5` (20px)
/// padding, `borderRadius:3` (24px), a 1px divider border, the paper surface and
/// no shadow.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  static const double _radius = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

/// The original `getIconSize(20)` avatar: a `p:1` (8px) `borderRadius:2` (16px)
/// box tinted with `alpha(hue, 0.1)`, holding the `hue`-colored glyph.
class _IconAvatar extends StatelessWidget {
  const _IconAvatar({required this.icon, required this.hue});

  final IconData icon;
  final Color hue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 20, color: hue),
    );
  }
}

/// A title (subtitle1 / weight 600) optionally followed by a muted Info glyph
/// carrying [tooltip], over a `body2` `text.secondary` [description].
class _CardText extends StatelessWidget {
  const _CardText({required this.title, this.tooltip, this.description});

  final String title;
  final String? tooltip;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (tooltip != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip!,
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(
                  LucideIcons.info,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// A small "saved-only" banner explaining the effects are not wired to the chat
/// view yet (the project's convention for UI-complete-but-unwired settings).
class _PendingNote extends StatelessWidget {
  const _PendingNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hue = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: hue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '以下设置会立即保存，部分效果将在聊天页接入后生效（即将支持）。',
              style: theme.textTheme.bodySmall?.copyWith(color: hue),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 多模型对比显示 card: icon + title + tooltip over a full-width layout select.
class _MultiModelCard extends StatelessWidget {
  const _MultiModelCard({required this.value, required this.onChanged});

  final MultiModelDisplayStyle value;
  final ValueChanged<MultiModelDisplayStyle> onChanged;

  static const Map<MultiModelDisplayStyle, String> _labels = {
    MultiModelDisplayStyle.horizontal: '水平布局（默认）',
    MultiModelDisplayStyle.vertical: '垂直布局（并排显示）',
    MultiModelDisplayStyle.single: '单独布局（堆叠显示）',
  };

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconAvatar(
                icon: LucideIcons.layout,
                hue: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _CardText(
                  title: '多模型对比显示',
                  tooltip: '配置多模型对比时的布局方式',
                  description:
                      '设置多模型对比时的布局方式。水平布局将模型响应并排显示，垂直布局将模型响应上下排列，单独布局将模型响应堆叠显示。',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Select<MultiModelDisplayStyle>(
            label: '布局方式',
            value: value,
            items: _labels,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// The tool-call / citation / system-prompt cards: icon + text on the left, a
/// [CustomSwitch] on the right (the original `settingRowStyle`).
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.icon,
    required this.hue,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconAvatar(icon: icon, hue: hue),
          const SizedBox(width: 12),
          Expanded(
            child: _CardText(title: title, description: description),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CustomSwitch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// The 聊天背景设置 card: the enable switch plus, when on, the collapsible
/// image / opacity / overlay / size / position / repeat controls.
class _BackgroundCard extends ConsumerWidget {
  const _BackgroundCard({required this.value, required this.onChanged});

  final ChatBackgroundSettings value;
  final ValueChanged<ChatBackgroundSettings> onChanged;

  static const Map<ChatBackgroundSize, String> _sizes = {
    ChatBackgroundSize.cover: '覆盖',
    ChatBackgroundSize.contain: '包含',
    ChatBackgroundSize.auto: '原始大小',
  };
  static const Map<ChatBackgroundPosition, String> _positions = {
    ChatBackgroundPosition.center: '居中',
    ChatBackgroundPosition.top: '顶部',
    ChatBackgroundPosition.bottom: '底部',
    ChatBackgroundPosition.left: '左侧',
    ChatBackgroundPosition.right: '右侧',
  };
  static const Map<ChatBackgroundRepeat, String> _repeats = {
    ChatBackgroundRepeat.noRepeat: '不重复',
    ChatBackgroundRepeat.repeat: '重复',
    ChatBackgroundRepeat.repeatX: '水平重复',
    ChatBackgroundRepeat.repeatY: '垂直重复',
  };

  Future<void> _pickImage(WidgetRef ref) async {
    final picked = await ref.read(imagePickerApiProvider).pickFromGallery();
    if (picked == null) return;
    final mime = _mimeFor(picked.name);
    final dataUrl = 'data:$mime;base64,${base64Encode(picked.bytes)}';
    onChanged(value.copyWith(imageUrl: dataUrl));
  }

  static String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _IconAvatar(
                icon: LucideIcons.image,
                hue: Color(0xFFEC4899),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: _CardText(
                  title: '聊天背景设置',
                  description: '自定义聊天界面背景图片。背景只会显示在聊天消息区域，不会影响顶部工具栏和侧边栏。',
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: CustomSwitch(
                  value: value.enabled,
                  onChanged: (v) => onChanged(value.copyWith(enabled: v)),
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: value.enabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '背景图片',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ImageArea(
                    imageUrl: value.imageUrl,
                    onPick: () => _pickImage(ref),
                    onRemove: () => onChanged(value.copyWith(imageUrl: '')),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '背景透明度  ${(value.opacity * 100).round()}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Slider(
                    min: 0.1,
                    max: 1,
                    divisions: 9,
                    value: value.opacity.clamp(0.1, 1),
                    label: '${(value.opacity * 100).round()}%',
                    onChanged: (v) => onChanged(value.copyWith(opacity: v)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.04,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: _CardText(
                            title: '显示渐变遮罩',
                            description:
                                '在背景上方添加白色渐变遮罩，提高文字可读性。关闭后可直接通过透明度控制背景。',
                          ),
                        ),
                        const SizedBox(width: 12),
                        CustomSwitch(
                          value: value.showOverlay,
                          onChanged: (v) =>
                              onChanged(value.copyWith(showOverlay: v)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Select<ChatBackgroundSize>(
                    label: '背景尺寸',
                    value: value.size,
                    items: _sizes,
                    onChanged: (v) => onChanged(value.copyWith(size: v)),
                  ),
                  const SizedBox(height: 12),
                  _Select<ChatBackgroundPosition>(
                    label: '背景位置',
                    value: value.position,
                    items: _positions,
                    onChanged: (v) => onChanged(value.copyWith(position: v)),
                  ),
                  const SizedBox(height: 12),
                  _Select<ChatBackgroundRepeat>(
                    label: '背景重复',
                    value: value.repeat,
                    items: _repeats,
                    onChanged: (v) => onChanged(value.copyWith(repeat: v)),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The background image preview (200×120 with a remove button) or, when unset,
/// the dashed upload prompt.
class _ImageArea extends StatelessWidget {
  const _ImageArea({
    required this.imageUrl,
    required this.onPick,
    required this.onRemove,
  });

  final String imageUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  Uint8List? _decode() {
    final i = imageUrl.indexOf('base64,');
    if (i < 0) return null;
    try {
      return base64Decode(imageUrl.substring(i + 7));
    } on FormatException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = imageUrl.isEmpty ? null : _decode();

    if (bytes != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 200,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: theme.colorScheme.error,
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.dividerColor,
            style: BorderStyle.solid,
          ),
          color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.imagePlus,
              size: 28,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              '点击上传背景图片',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '支持 JPG、PNG、GIF、WebP 格式，最大 5MB',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labelled outlined dropdown (the original MUI `Select size="small"`),
/// mapping each [T] to a display label via [items].
class _Select<T> extends StatelessWidget {
  const _Select({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(LucideIcons.chevronDown, size: 18),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
      ),
      items: [
        for (final entry in items.entries)
          DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
