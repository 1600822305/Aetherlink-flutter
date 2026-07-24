// 试跑结果弹窗：裁决 + 原因 + 注入上下文 + 耗时。

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';

class HookTryRunResultDialog extends StatelessWidget {
  const HookTryRunResultDialog({
    super.key,
    required this.result,
    required this.elapsed,
  });

  final AgentHookResult result;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, label) = switch (result.outcome) {
      AgentHookOutcome.proceed => (
        LucideIcons.check,
        theme.colorScheme.tertiary,
        result.isAsync ? '放行（async 转后台）' : '放行',
      ),
      AgentHookOutcome.allow => (
        LucideIcons.check,
        theme.colorScheme.tertiary,
        '免审放行',
      ),
      AgentHookOutcome.ask => (LucideIcons.circleHelp, Colors.orange, '强制审批'),
      AgentHookOutcome.block => (
        LucideIcons.ban,
        theme.colorScheme.error,
        '阻断',
      ),
      AgentHookOutcome.failed => (
        LucideIcons.triangleAlert,
        Colors.orange,
        'hook 自身失败（不阻断）',
      ),
    };
    final seconds = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    return AlertDialog(
      title: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('试跑结果：$label')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.message.isNotEmpty) ...[
            Text('原因/输出', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              result.message,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (result.additionalContext.isNotEmpty) ...[
            Text('注入上下文', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              result.additionalContext,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (result.preventContinuation)
            Text(
              '⏹ 该 hook 要求终止整个任务'
              '${result.stopReason.isNotEmpty ? '：${result.stopReason}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          Text(
            '耗时 ${seconds}s',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
