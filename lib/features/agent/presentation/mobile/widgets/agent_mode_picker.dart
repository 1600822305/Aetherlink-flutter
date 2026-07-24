import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

/// 模式快切面板：底部弹出四模式单选；切到 Auto 时二次确认，
/// 未确认返回 null（保持原模式）。
Future<AgentSessionMode?> showAgentModePicker(
  BuildContext context, {
  required AgentSessionMode current,
}) async {
  final mode = await showModalBottomSheet<AgentSessionMode>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (m, desc) in const [
            (AgentSessionMode.code, '执行模式：写/终端全能力，走审批+白名单'),
            (AgentSessionMode.auto, '自动模式：工作区内写/执行免审批，越界仍审批'),
            (AgentSessionMode.ask, '只问答：仅只读工具，不改任何东西'),
            (AgentSessionMode.plan, '只读规划：先出完整方案，确认后转 Code'),
          ])
            ListTile(
              selected: m == current,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              leading: Icon(
                m == current ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 20,
              ),
              title: Text(
                agentModeLabel(m),
                style: m == current
                    ? const TextStyle(fontWeight: FontWeight.w600)
                    : null,
              ),
              subtitle: Text(desc),
              trailing: m == current ? const Text('当前') : null,
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    ),
  );
  if (mode == null) return null;
  if (mode == AgentSessionMode.auto && current != AgentSessionMode.auto) {
    if (!context.mounted) return null;
    final confirmed = await _confirmAutoMode(context);
    if (confirmed != true) return null;
  }
  return mode;
}

Future<bool?> _confirmAutoMode(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('启用 Auto 模式？'),
      content: const Text(
        '绑定工作区内的文件写入与命令执行将不再逐条审批，'
        '越出工作区的操作仍会请求授权。未绑定工作区时不会免审。\n\n'
        '仅在信任当前任务时启用。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
          child: const Text('启用 Auto'),
        ),
      ],
    ),
  );
}
