import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';

/// Lays out a multi-model 兄弟组 (assistant replies sharing one `siblingsGroupId`)
/// as a comparison block — the Flutter analogue of the web `MultiModelMessageGroup`
/// and cherry-studio's `MessageGroup`.
///
/// Faithful to the web original, the group supports **four** layouts
/// ([MultiModelMessageStyle]): 折叠 `fold` (only the selected reply shows, with a
/// model picker), 水平 `horizontal` (cards scroll side by side), 垂直 `vertical`
/// (cards stacked) and 网格 `grid` (responsive fixed-height cards, tap to expand).
/// The layout toggle, model picker and group actions live in a **bottom menu
/// bar** (`renderMenuBar`); the chosen layout is persisted onto every member
/// (`multiModelMessageStyle`) so it survives a reload, defaulting to the first
/// member's saved style, then the global 多模型布局 setting, then `fold`.
///
/// Each cell is the real [ChatMessageBubble] (the model name comes from the
/// bubble's own header/footer). In 折叠 the menu bar's model list switches which
/// reply shows and which one 采用(选定) the conversation continues from
/// ([ChatController.selectSibling]); that list can render as compact 图标 or as
/// 完整名称 chips via an 展开/压缩 toggle.
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

  /// Maps the global 多模型布局 setting (three values) into the four-value layout.
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

    // The chosen layout: a local override, else the first member's persisted
    // style, else the global setting (mapped), else fold.
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
    // A lone reply always folds (matches the web's `effectiveStyle`).
    final style = members.length < 2 ? MultiModelMessageStyle.fold : base;

    // The selected sibling id (the one the conversation continues from).
    final selectedId = ref.watch(
      chatControllerProvider.select((a) {
        for (final id in members) {
          if (a.messageById(id)?.foldSelected ?? false) return id;
        }
        return members.isEmpty ? null : members.first;
      }),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _body(theme, style, members, selectedId),
          _menuBar(theme, style, members, selectedId),
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
              _MemberCell(
                messageId: id,
                style: style,
                selected: id == selectedId,
              ),
          ],
        );

      case MultiModelMessageStyle.horizontal:
        final size = MediaQuery.of(context).size;
        final cardWidth = (size.width * 0.85).clamp(0.0, 420.0);
        final maxHeight = (size.height - 350).clamp(280.0, double.infinity);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final id in members)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: cardWidth,
                      maxHeight: maxHeight,
                    ),
                    child: _MemberCell(
                      messageId: id,
                      style: style,
                      selected: id == selectedId,
                    ),
                  ),
              ],
            ),
          ),
        );

      case MultiModelMessageStyle.grid:
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            // Responsive columns: phone 1, tablet 2, desktop 3 (web breakpoints).
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

  // ------------------------------------------------------------- menu bar ---

  /// The bottom menu bar: the four-way layout toggle, the 折叠 model list (with
  /// 展开/压缩 toggle) and the group actions (重试失败 / 删除分组).
  Widget _menuBar(
    ThemeData theme,
    MultiModelMessageStyle style,
    List<String> members,
    String? selectedId,
  ) {
    final isFold = style == MultiModelMessageStyle.fold;
    final hasFailed = ref.watch(
      chatControllerProvider.select(
        (a) => members.any((id) => a.messageById(id)?.status == MessageStatus.error),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(top: 6),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          _StyleToggle(current: style, onChanged: _setStyle),
          if (isFold && members.length >= 2) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: _expandedModelList ? '压缩' : '展开',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: () =>
                  setState(() => _expandedModelList = !_expandedModelList),
              icon: Icon(
                _expandedModelList ? Icons.close_fullscreen : Icons.open_in_full,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final id in members)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _ModelEntry(
                          messageId: id,
                          selected: id == selectedId,
                          expanded: _expandedModelList,
                          onTap: () => ref
                              .read(chatControllerProvider.notifier)
                              .selectSibling(id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else
            const Spacer(),
          if (hasFailed)
            IconButton(
              tooltip: '重试失败',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              color: theme.colorScheme.tertiary,
              onPressed: () => ref
                  .read(chatControllerProvider.notifier)
                  .retryFailedSiblings(members),
              icon: const Icon(Icons.refresh),
            ),
          IconButton(
            tooltip: '删除分组',
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            color: theme.colorScheme.error,
            onPressed: () => _confirmDeleteGroup(members),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGroup(List<String> members) async {
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
    await ref.read(chatControllerProvider.notifier).deleteMultiModelGroup(askId);
  }
}

/// The four-way layout toggle: 折叠 / 水平 / 垂直 / 网格, a segmented row of icon
/// buttons highlighting the active layout (the web `ToggleButtonGroup`).
class _StyleToggle extends StatelessWidget {
  const _StyleToggle({required this.current, required this.onChanged});

  final MultiModelMessageStyle current;
  final ValueChanged<MultiModelMessageStyle> onChanged;

  static const _items = <(MultiModelMessageStyle, IconData, String)>[
    (MultiModelMessageStyle.fold, Icons.unfold_less, '折叠'),
    (MultiModelMessageStyle.horizontal, Icons.view_week, '水平'),
    (MultiModelMessageStyle.vertical, Icons.view_agenda, '垂直'),
    (MultiModelMessageStyle.grid, Icons.grid_view, '网格'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: 0.5,
        ),
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
            size: 15,
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A single grouped reply rendered as the real [ChatMessageBubble], framed
/// according to [style]: bordered scrollable cards for 水平/垂直, a fixed-height
/// tappable preview for 网格, and a plain bubble for 折叠 (only the selected reply
/// is rendered by the parent).
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

    Border border() => Border.all(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
      width: selected ? 1.5 : 0.5,
    );

    switch (style) {
      case MultiModelMessageStyle.fold:
        return bubble;

      case MultiModelMessageStyle.vertical:
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: border(),
          ),
          child: bubble,
        );

      case MultiModelMessageStyle.horizontal:
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: border(),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: bubble,
            ),
          ),
        );

      case MultiModelMessageStyle.grid:
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: border(),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              // A non-scrolling preview; tap opens the full reply (see _openDetail).
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: bubble,
                ),
              ),
            ),
          ),
        );
    }
  }
}

/// A model entry in the 折叠 model list: either a compact 图标 avatar (with a
/// name tooltip) or an expanded chip showing the 完整名称, depending on [expanded].
/// Selected = the 采用 sibling; a streaming/pending sibling pulses. Tap = 采用.
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

    if (expanded) {
      final chip = ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: logo,
        label: Text(
          name,
          style: theme.textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
      );
      return Opacity(opacity: isProcessing ? 0.6 : 1, child: chip);
    }

    return Tooltip(
      message: name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Opacity(
          opacity: isProcessing ? 0.6 : 1,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: _ModelLogo(
                modelId: view?.modelId,
                providerId: view?.providerId,
                name: name,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small provider/model logo with a first-letter fallback, sized [size].
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
