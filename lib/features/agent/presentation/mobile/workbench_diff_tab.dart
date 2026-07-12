import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 工作台「改动 diff」tab（UI 稿 §4.3 / P1 清单 10）：任务工作区的
/// 未提交改动文件清单（git status），点文件开只读 diff 面板
/// （HEAD ↔ 工作区当前内容）。手动下拉/按钮刷新。
class WorkbenchDiffTab extends ConsumerWidget {
  const WorkbenchDiffTab({required this.task, super.key});

  final AgentTask task;

  String? _workspaceId(WidgetRef ref) => ref
      .watch(agentProfilesProvider)
      .where((p) => p.id == task.profileId)
      .firstOrNull
      ?.workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = _workspaceId(ref);
    final async = ref.watch(agentWorkspaceChangesProvider(workspaceId));

    return async.when(
      data: (result) => _body(context, ref, result, workspaceId),
      error: (error, _) => _Empty(
        icon: LucideIcons.circleAlert,
        label: '改动清单加载失败\n$error',
        onRefresh: () =>
            ref.invalidate(agentWorkspaceChangesProvider(workspaceId)),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AgentChangesResult result,
    String? workspaceId,
  ) {
    final theme = Theme.of(context);
    final snapshot = result.snapshot;
    if (snapshot == null) {
      return _Empty(
        icon: LucideIcons.gitCompareArrows,
        label: result.unavailableReason ?? '改动清单不可用',
        onRefresh: () =>
            ref.invalidate(agentWorkspaceChangesProvider(workspaceId)),
      );
    }

    void refresh() =>
        ref.invalidate(agentWorkspaceChangesProvider(workspaceId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${snapshot.workspaceName} · '
                  '${snapshot.changes.length} 个未提交改动',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: '刷新',
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                onPressed: refresh,
              ),
            ],
          ),
        ),
        Expanded(
          child: snapshot.changes.isEmpty
              ? _Empty(
                  icon: LucideIcons.gitCompareArrows,
                  label: '工作区没有未提交改动',
                  onRefresh: refresh,
                )
              : RefreshIndicator(
                  onRefresh: () async => refresh(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: snapshot.changes.length,
                    itemBuilder: (context, i) => _ChangeRow(
                      change: snapshot.changes[i],
                      onTap: () => _openDiff(
                        context,
                        ref,
                        workspaceId,
                        snapshot,
                        snapshot.changes[i],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _openDiff(
    BuildContext context,
    WidgetRef ref,
    String? workspaceId,
    AgentChangesSnapshot snapshot,
    AgentFileChange change,
  ) async {
    try {
      final diff = await ref.read(
        _fileDiffProvider((workspaceId, snapshot, change)).future,
      );
      if (!context.mounted) return;
      await showReadOnlyDiffSheet(
        context,
        fileName: change.relPath.split('/').last,
        subtitle: '红色 - 为 HEAD 版本，绿色 + 为当前工作区内容（${change.relPath}）',
        oldText: diff.oldText,
        newText: diff.newText,
      );
    } catch (e) {
      if (context.mounted) AppToast.error(context, '加载 diff 失败 · $e');
    }
  }
}

final _fileDiffProvider = FutureProvider.autoDispose.family<
    ({String oldText, String newText}),
    (String?, AgentChangesSnapshot, AgentFileChange)>((ref, args) {
  final (workspaceId, snapshot, change) = args;
  return loadAgentFileDiff(ref, workspaceId, snapshot, change);
});

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change, required this.onTap});

  final AgentFileChange change;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (change.status) {
      GitFileStatus.modified => ('M', Colors.orange),
      GitFileStatus.added => ('A', Colors.green),
      GitFileStatus.untracked => ('U', Colors.green),
      GitFileStatus.deleted => ('D', theme.colorScheme.error),
      GitFileStatus.renamed => ('R', Colors.blue),
      GitFileStatus.conflicted => ('!', theme.colorScheme.error),
    };
    final dir = change.relPath.contains('/')
        ? change.relPath.substring(0, change.relPath.lastIndexOf('/'))
        : null;
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
      title: Text(
        change.relPath.split('/').last,
        style: theme.textTheme.bodyMedium,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: dir == null
          ? null
          : Text(
              dir,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Icon(
        LucideIcons.chevronRight,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.label,
    required this.onRefresh,
  });

  final IconData icon;
  final String label;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: muted),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRefresh,
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('刷新'),
          ),
        ],
      ),
    );
  }
}
