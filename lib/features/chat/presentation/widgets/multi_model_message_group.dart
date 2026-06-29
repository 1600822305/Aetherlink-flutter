import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';

/// Lays out a multi-model 兄弟组 (assistant replies sharing one `siblingsGroupId`)
/// as a comparison block — a faithful Flutter port of the web original's
/// `MultiModelMessageGroup` (`Aetherlink-original`).
///
/// Four layouts ([MultiModelMessageStyle]): 折叠 `fold` (only the selected reply
/// shows, with a model picker), 水平 `horizontal` (cards scroll side by side), 垂直
/// `vertical` (cards stacked) and 网格 `grid` (responsive fixed-height cards, tap
/// to expand). The layout toggle, the fold model list (with an 展开/压缩 toggle
/// that switches the list between 完整名称 chips and 图标 avatars) and the group
/// actions (重试失败 / 删除分组) live in a **bottom menu bar**.
///
/// The chosen layout is persisted onto every member (`multiModelMessageStyle`)
/// so it survives a reload, defaulting to the first member's saved style, then
/// the global 多模型布局 setting, then `fold`.
class MultiModelMessageGroup extends ConsumerStatefulWidget {
  const MultiModelMessageGroup({super.key, required this.memberIds});

  /// The grouped assistant message ids, in display (chronological) order.
  final List<String> memberIds;

  @override
  ConsumerState<MultiModelMessageGroup> createState() =>
      _MultiModelMessageGroupState();
}

class _MultiModelMessageGroupState
    extends ConsumerState<MultiModelMessageGroup> {
  /// Per-group layout override (null = follow the persisted/global style).
  MultiModelMessageStyle? _style;

  /// Model list rendering in 折叠 mode: `true` = 完整名称 chips (expanded),
  /// `false` = 图标 avatars (compact). Mirrors the web `modelListMode`.
  bool _expandedModelList = true;

  /// Maps the global 多模型布局 setting onto the four-value layout.
  static MultiModelMessageStyle _fromDisplay(MultiModelDisplayStyle d) {
    switch (d) {
      case MultiModelDisplayStyle.horizontal:
        return MultiModelMessageStyle.horizontal;
      case MultiModelDisplayStyle.vertical:
        return MultiModelMessageStyle.vertical;
      case MultiModelDisplayStyle.single:
        return MultiModelMessageStyle.fold;
      case MultiModelDisplayStyle.grid:
        return MultiModelMessageStyle.grid;
    }
  }

  void _setStyle(MultiModelMessageStyle style) {
    setState(() => _style = style);
    ref
        .read(chatControllerProvider.notifier)
        .setMultiModelStyle(widget.memberIds, style);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = widget.memberIds;

    final memberStyle = members.isEmpty
        ? null
        : ref.watch(
            chatControllerProvider.select(
              (a) => a.messageById(members.first)?.multiModelMessageStyle,
            ),
          );
    final globalStyle = ref.watch(
      chatInterfaceSettingsProvider.select((s) => s.multiModelDisplayStyle),
    );
    final base = _style ?? memberStyle ?? _fromDisplay(globalStyle);
    final style = members.length < 2 ? MultiModelMessageStyle.fold : base;

    final selectedId = ref.watch(
      chatControllerProvider.select((a) {
        for (final id in members) {
          if (a.messageById(id)?.foldSelected ?? false) return id;
        }
        return members.isEmpty ? null : members.first;
      }),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _body(theme, style, members, selectedId),
          _MenuBar(
            style: style,
            members: members,
            selectedId: selectedId,
            expandedModelList: _expandedModelList,
            onStyleChanged: _setStyle,
            onToggleModelListMode: () =>
                setState(() => _expandedModelList = !_expandedModelList),
            onSelect: (id) =>
                ref.read(chatControllerProvider.notifier).selectSibling(id),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- body ---

  Widget _body(
    ThemeData theme,
    MultiModelMessageStyle style,
    List<String> members,
    String? selectedId,
  ) {
    switch (style) {
      case MultiModelMessageStyle.fold:
        final shownId = selectedId ?? members.first;
        return _MemberCell(messageId: shownId, style: style, selected: true);

      case MultiModelMessageStyle.vertical:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final id in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MemberCell(
                  messageId: id,
                  style: style,
                  selected: id == selectedId,
                ),
              ),
          ],
        );

      case MultiModelMessageStyle.horizontal:
        final size = MediaQuery.of(context).size;
        final cardWidth = (size.width - 56).clamp(260.0, 460.0);
        // Bound the viewport height so each card's inner vertical scroll has a
        // finite height (NO IntrinsicHeight — it can't measure a scroll view,
        // which was zero-sizing the content). Cards size to min(content, this).
        final maxHeight = (size.height - 320).clamp(320.0, 560.0);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            shrinkWrap: true,
            itemCount: members.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => SizedBox(
              width: cardWidth,
              child: _MemberCell(
                messageId: members[i],
                style: style,
                selected: members[i] == selectedId,
              ),
            ),
          ),
        );

      case MultiModelMessageStyle.grid:
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1024
                ? (members.length > 2 ? 3 : 2)
                : width >= 600
                ? (members.length > 1 ? 2 : 1)
                : 1;
            const gap = 12.0;
            final cardWidth = (width - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final id in members)
                  SizedBox(
                    width: cardWidth,
                    child: _MemberCell(
                      messageId: id,
                      style: style,
                      selected: id == selectedId,
                      onTap: () => _openDetail(id),
                    ),
                  ),
              ],
            );
          },
        );
    }
  }

  /// Grid: tapping a card opens the full reply in a centred dialog (the web's
  /// `Popover`), so a truncated preview can still be read in full.
  void _openDetail(String messageId) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final mq = MediaQuery.of(context);
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: mq.size.height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: ChatMessageBubble(
                key: ValueKey('detail:$messageId'),
                messageId: messageId,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The bottom menu bar (port of the web `MenuBar`): the four-way layout toggle,
/// the 折叠 model list with its 展开/压缩 toggle, and the group actions.
class _MenuBar extends ConsumerWidget {
  const _MenuBar({
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
          _StyleToggle(current: style, onChanged: onStyleChanged),
          if (isFold && members.length >= 2) ...[
            const SizedBox(width: 4),
            _BarIconButton(
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
                          child: _ModelEntry(
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
            _BarIconButton(
              icon: LucideIcons.rotateCcw,
              tooltip: '重试失败',
              color: theme.colorScheme.tertiary,
              onPressed: () => ref
                  .read(chatControllerProvider.notifier)
                  .retryFailedSiblings(members),
            ),
          _BarIconButton(
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
class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
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
class _StyleToggle extends StatelessWidget {
  const _StyleToggle({required this.current, required this.onChanged});

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
class _MemberCell extends StatelessWidget {
  const _MemberCell({
    required this.messageId,
    required this.style,
    required this.selected,
    this.onTap,
  });

  final String messageId;
  final MultiModelMessageStyle style;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubble = ChatMessageBubble(
      key: ValueKey(messageId),
      messageId: messageId,
    );

    BoxDecoration decoration() => BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: selected
            ? theme.colorScheme.primary
            : theme.dividerColor.withValues(alpha: 0.6),
        width: selected ? 1.5 : 0.5,
      ),
    );

    switch (style) {
      case MultiModelMessageStyle.fold:
        return bubble;

      case MultiModelMessageStyle.vertical:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: decoration(),
          child: bubble,
        );

      case MultiModelMessageStyle.horizontal:
        return Container(
          decoration: decoration(),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(6),
            child: bubble,
          ),
        );

      case MultiModelMessageStyle.grid:
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 300,
            decoration: decoration(),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Align(alignment: Alignment.topLeft, child: bubble),
            ),
          ),
        );
    }
  }
}

/// A model entry in the 折叠 model list: a compact 图标 avatar (name in tooltip)
/// or, when [expanded], a chip showing the 完整名称. Selected = the 采用 sibling; a
/// streaming/pending sibling dims. Tap = 采用.
class _ModelEntry extends ConsumerWidget {
  const _ModelEntry({
    required this.messageId,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final String messageId;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  static const _processing = <MessageStatus>{
    MessageStatus.pending,
    MessageStatus.processing,
    MessageStatus.searching,
    MessageStatus.streaming,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final view = ref.watch(
      chatControllerProvider.select((a) => a.messageById(messageId)),
    );
    final name = view?.modelName ?? '模型';
    final isProcessing = _processing.contains(view?.status);
    final logo = _ModelLogo(
      modelId: view?.modelId,
      providerId: view?.providerId,
      name: name,
      size: 20,
    );

    final Widget child;
    if (expanded) {
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 28,
        padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? null
              : Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.6),
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            logo,
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      child = Tooltip(
        message: name,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: logo,
        ),
      );
    }

    return Opacity(
      opacity: isProcessing ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(expanded ? 14 : 13),
        child: child,
      ),
    );
  }
}

/// A round provider/model logo with a first-letter fallback, sized [size].
class _ModelLogo extends StatelessWidget {
  const _ModelLogo({
    required this.modelId,
    required this.providerId,
    required this.name,
    required this.size,
  });

  final String? modelId;
  final String? providerId;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
        style: theme.textTheme.labelSmall,
      ),
    );
    if (modelId == null && providerId == null) {
      return ClipOval(child: fallback);
    }
    final asset = getModelOrProviderIcon(
      modelId ?? '',
      providerId ?? '',
      isDark: isDark,
    );
    return ClipOval(
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
