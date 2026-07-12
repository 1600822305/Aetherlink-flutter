// 智能体侧边栏通用小件：tab 标头 + 胶囊新建按钮。
// 样式对齐聊天侧边栏的 SidebarTabHeader / SidebarPillButton（复制实现，
// 不 import chat 内部）。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 选中列表项底色：与聊天侧边栏 `kSidebarSelectedItemBg` 同值。
const Color kAgentSidebarSelectedItemBg = Color(0x141976D2);

/// 弱化图标色 / 危险动作红：与聊天侧边栏 token 同值。
const Color kAgentSidebarMutedIcon = Color(0x8A000000);
const Color kAgentSidebarDanger = Color(0xFFD32F2F);

/// tab 标头：左侧标题（18.29px / 500）+ 右侧动作按钮组。
class AgentSidebarTabHeader extends StatelessWidget {
  const AgentSidebarTabHeader({
    super.key,
    required this.title,
    required this.trailing,
  });

  final String title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18.29,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}

/// 描边胶囊动作按钮（新建智能体 / 新建话题）：
/// `border 1px text.secondary`、radius 8、label 14px / 600、16px 前置图标。
class AgentSidebarPillButton extends StatelessWidget {
  const AgentSidebarPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.colorScheme.onSurfaceVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 列表项操作面板里的一行（对齐聊天 `SidebarSheetAction`）。
class AgentSidebarSheetAction<T> {
  const AgentSidebarSheetAction(
    this.value,
    this.icon,
    this.label, {
    this.danger = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final bool danger;
}

/// 列表项右侧「更多」按钮：点开底部操作面板（对齐聊天
/// `SidebarOverflowMenuButton` 的交互与视觉，复制实现不 import chat）。
class AgentSidebarOverflowMenuButton<T> extends StatelessWidget {
  const AgentSidebarOverflowMenuButton({
    super.key,
    required this.actions,
    required this.onSelected,
    required this.size,
    required this.box,
    this.title,
    this.opacity = 0.6,
  });

  final List<AgentSidebarSheetAction<T>> actions;
  final ValueChanged<T> onSelected;
  final double size;
  final double box;
  final String? title;
  final double opacity;

  Future<void> _open(BuildContext context) async {
    final selected = await _showActionSheet<T>(
      context,
      title: title,
      actions: actions,
    );
    if (selected != null && context.mounted) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: InkResponse(
        onTap: () => _open(context),
        radius: box * 0.6,
        child: SizedBox(
          width: box,
          height: box,
          child: Icon(
            LucideIcons.moreVertical,
            size: size,
            color: kAgentSidebarMutedIcon,
          ),
        ),
      ),
    );
  }
}

Future<T?> _showActionSheet<T>(
  BuildContext context, {
  required List<AgentSidebarSheetAction<T>> actions,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final bottomPad = MediaQuery.paddingOf(sheetContext).bottom;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null && title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          for (final action in actions)
            InkWell(
              onTap: () => Navigator.of(sheetContext).pop(action.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      action.icon,
                      size: 18,
                      color: action.danger
                          ? kAgentSidebarDanger
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action.label,
                        style: TextStyle(
                          fontSize: 14,
                          color: action.danger
                              ? kAgentSidebarDanger
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: bottomPad > 0 ? bottomPad : 8),
        ],
      );
    },
  );
}

/// 单输入框弹窗（对齐聊天 `promptText`）：确定返回 trim 后文本，否则 null。
Future<String?> agentPromptText(
  BuildContext context, {
  required String title,
  required String hint,
  String? initial,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _PromptTextDialog(title: title, hint: hint, initial: initial),
  );
  if (result == null || result.isEmpty) return null;
  return result;
}

class _PromptTextDialog extends StatefulWidget {
  const _PromptTextDialog({
    required this.title,
    required this.hint,
    this.initial,
  });

  final String title;
  final String hint;
  final String? initial;

  @override
  State<_PromptTextDialog> createState() => _PromptTextDialogState();
}

class _PromptTextDialogState extends State<_PromptTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 危险确认弹窗（对齐聊天 `showConfirmDialog`）：仅点确定返回 true。
Future<bool> agentConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: kAgentSidebarDanger),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
