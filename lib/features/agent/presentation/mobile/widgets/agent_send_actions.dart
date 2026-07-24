import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// 任务执行中发送时的三选动作（§五打断交互）。
enum AgentSendAction { queue, interrupt, edit }

/// 执行中发送三选面板：排队 / 立即打断并发送 / 继续编辑。
Future<AgentSendAction?> showAgentSendActionSheet(BuildContext context) {
  return showModalBottomSheet<AgentSendAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(LucideIcons.listPlus, size: 20),
            title: const Text('排队'),
            subtitle: const Text('不打断当前工具，下一轮生效'),
            onTap: () => Navigator.pop(context, AgentSendAction.queue),
          ),
          ListTile(
            leading: const Icon(LucideIcons.zap, size: 20),
            title: const Text('立即打断并发送'),
            subtitle: const Text('中止当前工具，模型下一轮先响应这条指令'),
            onTap: () => Navigator.pop(context, AgentSendAction.interrupt),
          ),
          ListTile(
            leading: const Icon(LucideIcons.pencil, size: 20),
            title: const Text('继续编辑'),
            onTap: () => Navigator.pop(context, AgentSendAction.edit),
          ),
        ],
      ),
    ),
  );
}

/// 强制终止二次确认：确认返回 true。
Future<bool?> confirmAgentForceStop(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('强制终止任务？'),
      content: const Text('立即中止当前执行，任务转为已取消，不可恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('强制终止'),
        ),
      ],
    ),
  );
}
