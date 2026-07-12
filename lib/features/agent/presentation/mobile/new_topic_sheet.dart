import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

/// 新建话题底部弹层（UI 稿 §三）：任务指令 + 工作区（一律必选，已拍板
/// "强制要求选择工作区"；调研需求走普通聊天）。模式不放这里——在工作台
/// 输入区上沿快切（默认 Code）；模型跟随聊天当前选择。
Future<void> showNewTopicSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _NewTopicSheet(),
  );
}

class _NewTopicSheet extends ConsumerStatefulWidget {
  const _NewTopicSheet();

  @override
  ConsumerState<_NewTopicSheet> createState() => _NewTopicSheetState();
}

class _NewTopicSheetState extends ConsumerState<_NewTopicSheet> {
  final TextEditingController _instruction = TextEditingController();
  Workspace? _workspace;

  @override
  void dispose() {
    _instruction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final profiles = ref.watch(agentProfilesProvider);
    final profileId = ref.watch(selectedAgentProfileIdProvider);
    final profile = profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => profiles.first,
    );
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    final canStart =
        _instruction.text.trim().isNotEmpty && _workspace != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '新建话题 · ${profile.emoji} ${profile.name}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _instruction,
            minLines: 3,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: '要做什么？描述得越具体越好…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '工作区（必选）',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          if (workspaces.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: cs.onSurface.withValues(alpha: 0.15)),
              ),
              child: Text(
                '还没有工作区——先去「工作区」页打开一个目录',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in workspaces.take(6))
                  ChoiceChip(
                    avatar: Icon(
                      LucideIcons.folderTree,
                      size: 14,
                      color: _workspace?.id == w.id
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.6),
                    ),
                    label: Text(w.name),
                    selected: _workspace?.id == w.id,
                    onSelected: (_) => setState(() => _workspace = w),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: canStart
                ? () => Navigator.of(context).pop() // TODO(agent): 接真引擎后创建话题
                : null,
            icon: const Icon(LucideIcons.play, size: 18),
            label: const Text('开始执行'),
          ),
        ],
      ),
    );
  }
}
