import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 用户指令：贴右对称气泡（Devin/IDE 同款，与 agent 侧时间线叙述区分；
/// 已拍板 §九）；排队追加的指令带「已排队」标记。
class UserMessageTile extends StatelessWidget {
  const UserMessageTile({required this.event, super.key});

  final UserMessageEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (event.queued)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '已排队 · 下一轮生效',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ),
              Text(event.text, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
