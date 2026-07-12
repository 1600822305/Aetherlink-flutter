// 智能体侧边栏通用小件：tab 标头 + 胶囊新建按钮。
// 样式对齐聊天侧边栏的 SidebarTabHeader / SidebarPillButton（复制实现，
// 不 import chat 内部）。

import 'package:flutter/material.dart';

/// 选中列表项底色：与聊天侧边栏 `kSidebarSelectedItemBg` 同值。
const Color kAgentSidebarSelectedItemBg = Color(0x141976D2);

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
