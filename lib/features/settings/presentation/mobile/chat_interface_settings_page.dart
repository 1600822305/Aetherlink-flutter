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
import 'package:aetherlink_flutter/shared/widgets/app_select_field.dart';

/// The "聊天界面设置" sub-page (外观设置 → this page), a compact port of the
/// original `src/pages/Settings/ChatInterfaceSettings.tsx`.
///
/// Uses the shared 外观设置 card scaffolding (`_Card` / `_CardHeader` /
/// `_CardDivider` / `_DescribedSwitchRow` / `_Select`, mirroring
/// `thinking_settings_page.dart` and `message_bubble_settings_page.dart`) so the
/// three sub-pages stay visually consistent and compact: related options share a
/// single card instead of each option owning a large card.
///
/// Wiring status (consumed by the chat view): 多模型对比布局 drives
/// `multi_model_message_group.dart`, 系统提示词气泡 and 聊天背景 drive
/// `chat_page.dart`. 工具调用详情 / 引用详情 are persisted but not yet read by the
/// block renderer (parity with the web original, where they were also unwired).
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
          _MultiModelCard(
            value: settings.multiModelDisplayStyle,
            onChanged: controller.setMultiModelDisplayStyle,
          ),
          _DisplayCard(settings: settings, controller: controller),
          _BackgroundCard(
            value: settings.background,
            onChanged: controller.setBackground,
          ),
        ],
      ),
    );
  }
}

/// The 多模型对比显示 card: a tinted header (with the layouts in its tooltip)
/// over the full-width layout select.
class _MultiModelCard extends StatelessWidget {
  const _MultiModelCard({required this.value, required this.onChanged});

  final MultiModelDisplayStyle value;
  final ValueChanged<MultiModelDisplayStyle> onChanged;

  static const Map<MultiModelDisplayStyle, String> _labels = {
    MultiModelDisplayStyle.horizontal: '水平布局（默认）',
    MultiModelDisplayStyle.vertical: '垂直布局（并排显示）',
    MultiModelDisplayStyle.single: '单独布局（堆叠显示）',
    MultiModelDisplayStyle.grid: '网格布局（卡片平铺）',
  };

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: LucideIcons.layout,
            hue: Theme.of(context).colorScheme.primary,
            title: '多模型对比显示',
            tooltip:
                '水平：模型响应并排显示；垂直：上下排列；单独：堆叠切换；网格：卡片平铺。',
            description: '设置多模型对比时的布局方式。',
          ),
          const _CardDivider(),
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

/// The 消息显示 card: groups the 工具调用详情 / 引用详情 / 系统提示词气泡 toggles
/// (the web original's "开关类设置组") under a single header.
class _DisplayCard extends StatelessWidget {
  const _DisplayCard({required this.settings, required this.controller});

  final ChatInterfaceSettings settings;
  final ChatInterfaceSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.messageSquare,
            hue: Color(0xFF6366F1),
            title: '消息显示',
            tooltip: '控制聊天消息中工具调用、引用与系统提示词的显示',
            description: '控制工具调用、引用详情与系统提示词气泡的显示。',
          ),
          const _CardDivider(),
          _DescribedSwitchRow(
            title: '工具调用详情',
            description: '显示工具调用的调用参数与返回结果。',
            value: settings.showToolDetails,
            onChanged: controller.setShowToolDetails,
          ),
          const SizedBox(height: 14),
          _DescribedSwitchRow(
            title: '引用详情',
            description: '显示引用的来源与相关内容。',
            value: settings.showCitationDetails,
            onChanged: controller.setShowCitationDetails,
          ),
          const SizedBox(height: 14),
          _DescribedSwitchRow(
            title: '系统提示词气泡',
            description: '在聊天顶部显示系统提示词气泡，便于查看和编辑当前会话的系统提示词。',
            value: settings.showSystemPromptBubble,
            onChanged: controller.setShowSystemPromptBubble,
          ),
        ],
      ),
    );
  }
}

/// The 聊天背景 card: the enable switch sits inline in the header; when on, the
/// collapsible image / opacity / overlay / size / position / repeat controls
/// fade in below.
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
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            icon: LucideIcons.image,
            hue: const Color(0xFFEC4899),
            title: '聊天背景',
            description: '自定义聊天消息区域的背景图片，不影响顶栏与侧边栏。',
            trailing: CustomSwitch(
              value: value.enabled,
              onChanged: (v) => onChanged(value.copyWith(enabled: v)),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: value.enabled
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CardDivider(),
                const _FieldLabel('背景图片'),
                const SizedBox(height: 8),
                _ImageArea(
                  imageUrl: value.imageUrl,
                  onPick: () => _pickImage(ref),
                  onRemove: () => onChanged(value.copyWith(imageUrl: '')),
                ),
                const SizedBox(height: 16),
                _FieldLabel('背景透明度  ${(value.opacity * 100).round()}%'),
                Slider(
                  min: 0.1,
                  max: 1,
                  divisions: 9,
                  value: value.opacity.clamp(0.1, 1),
                  label: '${(value.opacity * 100).round()}%',
                  onChanged: (v) => onChanged(value.copyWith(opacity: v)),
                ),
                const SizedBox(height: 8),
                _DescribedSwitchRow(
                  title: '显示渐变遮罩',
                  description: '在背景上方添加白色渐变遮罩，提高文字可读性。',
                  value: value.showOverlay,
                  onChanged: (v) => onChanged(value.copyWith(showOverlay: v)),
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

// ---------------------------------------------------------------------------
// Shared card scaffolding (mirrors `thinking_settings_page.dart` /
// `message_bubble_settings_page.dart`)
// ---------------------------------------------------------------------------

/// A 12px-gap, 16px-padded, 18px-radius card with a 1px divider border.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: child,
    );
  }
}

/// A 12px-vertical hairline divider marking a card section break.
class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(height: 1, color: Theme.of(context).dividerColor),
    );
  }
}

/// A card header: the tinted icon avatar plus the title (with optional Info
/// tooltip) over an optional description, and an optional [trailing] widget
/// (e.g. the section's enable switch) pinned to the right.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.hue,
    required this.title,
    this.tooltip,
    this.description,
    this.trailing,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String? tooltip;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: hue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: hue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
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
                const SizedBox(height: 2),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 2), child: trailing!),
        ],
      ],
    );
  }
}

/// A bold, slightly-muted field label used above an input control.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// A switch row with a title and a muted sub-description.
class _DescribedSwitchRow extends StatelessWidget {
  const _DescribedSwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: CustomSwitch(value: value, onChanged: onChanged),
        ),
      ],
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
    return AppSelectField<T>(
      label: label,
      value: value,
      options: [
        for (final entry in items.entries)
          AppSelectOption<T>(value: entry.key, label: entry.value),
      ],
      onChanged: onChanged,
    );
  }
}
