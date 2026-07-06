import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/selection_menu_panel.dart';
import 'package:aetherlink_flutter/features/settings/application/selection_menu_settings_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/selection_menu_settings.dart';

/// The "复制面板" sub-page (外观设置 → 界面定制 → this page): configures the
/// custom selection menu shown when long-pressing message text.
///
/// Two cards — 面板设置 (自定义开关 + per-action toggles + 恢复预设) and 实时预览
/// (renders the exact [SelectionMenuPanel] the chat uses, updating as toggles
/// change). Every change persists immediately through
/// [SelectionMenuSettingsController] and takes effect in the chat live.
class SelectionMenuSettingsPage extends ConsumerWidget {
  const SelectionMenuSettingsPage({super.key});

  static const String _title = '复制面板';

  static const Color _brandHue = Color(0xFF0EA5E9); // sky

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(selectionMenuSettingsControllerProvider);
    final controller = ref.read(
      selectionMenuSettingsControllerProvider.notifier,
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
          _ConfigCard(settings: settings, controller: controller),
          if (settings.useCustomMenu) _PreviewCard(settings: settings),
        ],
      ),
    );
  }
}

/// The enabled ids in canonical display order (unknown persisted ids dropped).
List<String> _enabledIds(SelectionMenuSettings settings) {
  final stored = settings.enabledItemIds ?? kDefaultSelectionMenuItemIds;
  return [
    for (final spec in kSelectionMenuItemSpecs)
      if (stored.contains(spec.id)) spec.id,
  ];
}

/// 面板设置 card: the 自定义面板 master switch, one toggle per action and a
/// 恢复预设 action.
class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.settings, required this.controller});

  final SelectionMenuSettings settings;
  final SelectionMenuSettingsController controller;

  void _toggle(String id, bool enabled) {
    final current = _enabledIds(settings).toSet();
    if (enabled) {
      current.add(id);
    } else {
      current.remove(id);
    }
    controller.setEnabledItemIds([
      for (final spec in kSelectionMenuItemSpecs)
        if (current.contains(spec.id)) spec.id,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = _enabledIds(settings).toSet();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.clipboardCopy,
            hue: SelectionMenuSettingsPage._brandHue,
            title: '面板设置',
            description: '长按选中消息文本时弹出的操作面板',
          ),
          const _CardDivider(),
          _DescribedSwitchRow(
            title: '使用自定义复制面板',
            description: '关闭后使用系统自带的选择菜单（含第三方项，如「问AI」）。',
            value: settings.useCustomMenu,
            onChanged: controller.setUseCustomMenu,
          ),
          if (settings.useCustomMenu) ...[
            const _CardDivider(),
            for (final spec in kSelectionMenuItemSpecs) ...[
              _DescribedSwitchRow(
                title: spec.label,
                description: _descriptions[spec.id] ?? '',
                value: enabled.contains(spec.id),
                onChanged: (v) => _toggle(spec.id, v),
              ),
              if (spec != kSelectionMenuItemSpecs.last)
                const SizedBox(height: 14),
            ],
            const _CardDivider(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => controller.setEnabledItemIds(
                  kDefaultSelectionMenuItemIds,
                ),
                icon: const Icon(LucideIcons.rotateCcw, size: 15),
                label: const Text('恢复预设'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  textStyle: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const Map<String, String> _descriptions = {
    kSelectionMenuCopy: '复制选中的文本到剪贴板。',
    kSelectionMenuSelectAll: '选中这条消息的全部文本。',
    kSelectionMenuQuote: '把选中的文本插入到输入框。',
    kSelectionMenuShare: '通过系统分享面板分享选中的文本。',
  };
}

/// 实时预览 card: the exact [SelectionMenuPanel] the chat renders, following
/// the toggles live.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.settings});

  final SelectionMenuSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ids = _enabledIds(settings);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: LucideIcons.eye,
            hue: SelectionMenuSettingsPage._brandHue,
            title: '实时预览',
            description: '长按选中文本后弹出的面板效果',
          ),
          const _CardDivider(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Center(
              child: ids.isEmpty
                  ? Text(
                      '没有启用任何操作',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : SelectionMenuPanel(itemIds: ids),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card scaffolding (mirrors `thinking_settings_page.dart`)
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

/// A card header: the tinted icon avatar plus the title over a description.
class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.hue,
    required this.title,
    this.description,
  });

  final IconData icon;
  final Color hue;
  final String title;
  final String? description;

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
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
      ],
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
