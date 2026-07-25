import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/chat_interface_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:aetherlink_flutter/shared/domain/chat_interface_settings.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/multi_model/multi_model_member_cell.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/multi_model/multi_model_menu_bar.dart';

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
          MultiModelMenuBar(
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
        return MultiModelMemberCell(
          messageId: shownId,
          style: style,
          selected: true,
        );

      case MultiModelMessageStyle.vertical:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final id in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MultiModelMemberCell(
                  messageId: id,
                  style: style,
                  selected: id == selectedId,
                ),
              ),
          ],
        );

      case MultiModelMessageStyle.horizontal:
        final size = MediaQuery.of(context).size;
        // Near-full-width cards (scroll horizontally between models), so the
        // bubble gets close to its normal width — a narrow card overflowed
        // right because the bubble's action toolbar has a minimum width.
        final cardWidth = (size.width - 24).clamp(300.0, 560.0);
        // Cap the height so a long reply scrolls inside its card, but let short
        // replies shrink to their content. A horizontal ListView would force
        // every card to the full viewport height (→ big blank space under short
        // replies); a Row with crossAxisAlignment.start hands children LOOSE
        // height (0..maxHeight) so each card sizes to min(content, maxHeight) —
        // the web's `maxHeight + overflowY:auto`.
        final maxHeight = (size.height - 320).clamp(320.0, 560.0);
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  SizedBox(
                    width: cardWidth,
                    child: MultiModelMemberCell(
                      messageId: members[i],
                      style: style,
                      selected: members[i] == selectedId,
                    ),
                  ),
                ],
              ],
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
                    child: MultiModelMemberCell(
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
