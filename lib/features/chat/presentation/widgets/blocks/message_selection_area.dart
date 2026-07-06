import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/core/platform/platform_providers.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/selection_menu_panel.dart';
import 'package:aetherlink_flutter/features/settings/application/selection_menu_settings_controller.dart';
import 'package:aetherlink_flutter/shared/domain/selection_menu_settings.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// A [SelectionArea] for chat message bodies (正文 / 思考过程) that supports
/// clearing its selection when the user taps elsewhere on the chat page.
///
/// Each message block wraps its content in its own small [SelectionArea], so a
/// tap on another bubble or on blank space never reaches the area that holds
/// the selection and the highlight would otherwise linger. Every mounted
/// [MessageSelectionArea] registers itself in a static set; the chat page
/// listens for pointer-downs ([MessageSelectionArea.clearOutside]) and unfocuses
/// any area whose bounds don't contain the tap — [SelectionArea] clears its
/// selection when its focus node loses focus.
///
/// The long-press selection menu is the app's custom 复制面板 (复制 / 全选 /
/// 引用到输入框 / 分享, configurable under 外观设置 → 界面定制 → 复制面板);
/// turning 自定义复制面板 off falls back to the system adaptive menu (which
/// carries third-party Process Text entries like 问AI).
class MessageSelectionArea extends ConsumerStatefulWidget {
  const MessageSelectionArea({required this.child, super.key});

  final Widget child;

  static final Set<_MessageSelectionAreaState> _mounted =
      <_MessageSelectionAreaState>{};

  /// Clears the selection of every [MessageSelectionArea] whose bounds do not
  /// contain [globalPosition] (a tap inside the area is handled by the area's
  /// own gestures and must not be interfered with).
  static void clearOutside(Offset globalPosition) {
    for (final state in _mounted) {
      state._clearIfOutside(globalPosition);
    }
  }

  @override
  ConsumerState<MessageSelectionArea> createState() =>
      _MessageSelectionAreaState();
}

class _MessageSelectionAreaState extends ConsumerState<MessageSelectionArea> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'MessageSelectionArea');

  /// The current selection's plain text, kept fresh by [SelectionArea]'s
  /// `onSelectionChanged` so the 复制面板 actions can read it synchronously.
  String _selectedText = '';

  @override
  void initState() {
    super.initState();
    MessageSelectionArea._mounted.add(this);
  }

  @override
  void dispose() {
    MessageSelectionArea._mounted.remove(this);
    _focusNode.dispose();
    super.dispose();
  }

  void _clearIfOutside(Offset globalPosition) {
    // Only an area that holds a selection has focus (SelectableRegion requests
    // focus when a selection starts); skip the rest.
    if (!_focusNode.hasFocus) return;
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      final local = box.globalToLocal(globalPosition);
      if ((Offset.zero & box.size).contains(local)) return;
    }
    // Losing focus makes the SelectionArea clear its selection.
    _focusNode.unfocus();
  }

  void _handleAction(String id, SelectableRegionState region) {
    final text = _selectedText;
    switch (id) {
      case kSelectionMenuCopy:
        if (text.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: text));
          AppToast.success(context, '已复制');
        }
        region.hideToolbar();
        _focusNode.unfocus();
      case kSelectionMenuSelectAll:
        region.selectAll(SelectionChangedCause.toolbar);
      case kSelectionMenuQuote:
        region.hideToolbar();
        _focusNode.unfocus();
        final hook = ChatInputBar.insertTextHook;
        if (text.isNotEmpty && hook != null) {
          hook(text);
        }
      case kSelectionMenuShare:
        region.hideToolbar();
        _focusNode.unfocus();
        if (text.isNotEmpty) {
          ref.read(shareApiProvider).shareText(text);
        }
    }
  }

  Widget _buildContextMenu(
    BuildContext context,
    SelectableRegionState region,
  ) {
    final settings = ref.watch(selectionMenuSettingsControllerProvider);
    if (!settings.useCustomMenu) {
      return AdaptiveTextSelectionToolbar.selectableRegion(
        selectableRegionState: region,
      );
    }
    final ids = [
      for (final id in settings.enabledItemIds ?? kDefaultSelectionMenuItemIds)
        if (selectionMenuSpec(id) != null) id,
    ];
    if (ids.isEmpty) return const SizedBox.shrink();
    final anchors = region.contextMenuAnchors;
    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      toolbarBuilder: (context, child) => SelectionMenuCard(child: child),
      children: [
        for (final id in ids)
          SelectionMenuButton(
            spec: selectionMenuSpec(id)!,
            onPressed: () => _handleAction(id, region),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      focusNode: _focusNode,
      onSelectionChanged: (content) =>
          _selectedText = content?.plainText ?? '',
      contextMenuBuilder: _buildContextMenu,
      child: widget.child,
    );
  }
}
