import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/multi_model/multi_model_entry.dart';

class MultiModelMenuBar extends ConsumerWidget {
  const MultiModelMenuBar({
    super.key,
    required this.style,
    required this.members,
    required this.selectedId,
    required this.expandedModelList,
    required this.onStyleChanged,
    required this.onToggleModelListMode,
    required this.onSelect,
  });

  final MultiModelMessageStyle style;
  final List<String> members;
  final String? selectedId;
  final bool expandedModelList;
  final ValueChanged<MultiModelMessageStyle> onStyleChanged;
  final VoidCallback onToggleModelListMode;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFold = style == MultiModelMessageStyle.fold;
    final hasFailed = ref.watch(
      chatControllerProvider.select(
        (a) => members.any(
          (id) => a.messageById(id)?.status == MessageStatus.error,
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          StyleToggle(current: style, onChanged: onStyleChanged),
          if (isFold && members.length >= 2) ...[
            const SizedBox(width: 4),
            BarIconButton(
              icon: expandedModelList
                  ? LucideIcons.minimize2
                  : LucideIcons.maximize2,
              tooltip: expandedModelList ? '压缩' : '展开',
              onPressed: onToggleModelListMode,
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      for (final id in members)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: MultiModelEntry(
                            messageId: id,
                            selected: id == selectedId,
                            expanded: expandedModelList,
                            onTap: () => onSelect(id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (hasFailed)
            BarIconButton(
              icon: LucideIcons.rotateCcw,
              tooltip: '重试失败',
              color: theme.colorScheme.tertiary,
              onPressed: () => ref
                  .read(chatControllerProvider.notifier)
                  .retryFailedSiblings(members),
            ),
          BarIconButton(
            icon: LucideIcons.trash2,
            tooltip: '删除分组',
            color: theme.colorScheme.error,
            onPressed: () => _confirmDeleteGroup(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGroup(BuildContext context, WidgetRef ref) async {
    final askId = members.isEmpty
        ? null
        : ref.read(chatControllerProvider).messageById(members.first)?.askId;
    if (askId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: const Text('将删除该提问及其全部多模型回复，且不可恢复。确定删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(chatControllerProvider.notifier)
        .deleteMultiModelGroup(askId);
  }
}

/// A small ghost icon button matching the menu bar's compact controls.
class BarIconButton extends StatelessWidget {
  const BarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 15,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The four-way layout toggle: 折叠 / 水平 / 垂直 / 网格 — a segmented row of icon
/// buttons highlighting the active layout (the web `ToggleButtonGroup`), using
/// the project's Lucide icons to match the web's lucide-react set.
class StyleToggle extends StatelessWidget {
  const StyleToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final MultiModelMessageStyle current;
  final ValueChanged<MultiModelMessageStyle> onChanged;

  static const _items = <(MultiModelMessageStyle, IconData, String)>[
    (MultiModelMessageStyle.fold, LucideIcons.folderClosed, '折叠'),
    (MultiModelMessageStyle.horizontal, LucideIcons.columns2, '水平'),
    (MultiModelMessageStyle.vertical, LucideIcons.rows3, '垂直'),
    (MultiModelMessageStyle.grid, LucideIcons.layoutGrid, '网格'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, icon, tooltip) in _items)
            _segment(theme, value, icon, tooltip),
        ],
      ),
    );
  }

  Widget _segment(
    ThemeData theme,
    MultiModelMessageStyle value,
    IconData icon,
    String tooltip,
  ) {
    final active = current == value;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A single grouped reply rendered as the real [ChatMessageBubble], framed by
/// [style]: bordered scrollable cards for 水平/垂直, a fixed-height tappable
/// preview for 网格, a plain bubble for 折叠.
