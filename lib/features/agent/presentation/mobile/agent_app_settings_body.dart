// App 级设置页的「智能体设置」视图：目前只是空骨架占位。
// 智能体该有哪些设置项还没设计，这里不预设任何分组/行；结构上与聊天
// 设置 hub 同款（目录 + 多级子页），等设置项定稿后再往里填。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 智能体设置正文骨架（空态占位）。
class AgentAppSettingsBody extends StatelessWidget {
  const AgentAppSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.bot, size: 40, color: muted),
          const SizedBox(height: 12),
          Text(
            '智能体设置项待设计',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
