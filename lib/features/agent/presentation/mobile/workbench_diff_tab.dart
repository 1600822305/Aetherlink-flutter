import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/devin_diff_lines.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_diff_view.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 工作台「改动 diff」tab（UI 稿 §4.3 / P1 清单 10）：任务工作区的
/// 未提交改动文件清单（git status + numstat 行数统计），点文件行内
/// 手风琴展开 diff（HEAD ↔ 工作区当前内容），可全屏查看/复制路径。
/// 智能体文件写入/终端工具成功后自动刷新，也支持手动下拉/按钮刷新。
class WorkbenchDiffTab extends ConsumerStatefulWidget {
  const WorkbenchDiffTab({required this.task, super.key});

  final AgentTask task;

  @override
  ConsumerState<WorkbenchDiffTab> createState() => _WorkbenchDiffTabState();
}

class _WorkbenchDiffTabState extends ConsumerState<WorkbenchDiffTab> {
  /// 已行内展开的文件（relPath）。
  final Set<String> _expanded = {};

  /// 已触发过自动刷新的最新工具事件 seq，防止重复 invalidate。
  int _lastRefreshSeq = -1;

  String? _workspaceId() => ref
      .read(agentProfilesProvider)
      .where((p) => p.id == widget.task.profileId)
      .firstOrNull
      ?.workspaceId;

  bool _isMutatingTool(String toolName) {
    final n = toolName.toLowerCase();
    return fileEditorRiskLevel(toolName) != null ||
        n.contains('terminal') ||
        n.contains('command');
  }

  /// 智能体每次文件写入/终端工具成功后自动刷新改动清单。
  void _autoRefreshOnToolSuccess(List<AgentEvent> events) {
    for (var i = events.length - 1; i >= 0; i--) {
      final e = events[i];
      if (e is! ToolCallEvent) continue;
      if (e.state != AgentToolCallState.success) return;
      if (e.seq <= _lastRefreshSeq) return;
      if (!_isMutatingTool(e.toolName)) return;
      _lastRefreshSeq = e.seq;
      ref.invalidate(agentWorkspaceChangesProvider(_workspaceId()));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspaceId = _workspaceId();
    ref.listen(agentTaskEventsProvider(widget.task.id), (prev, next) {
      final events = next.value;
      if (events != null) _autoRefreshOnToolSuccess(events);
    });
    final async = ref.watch(agentWorkspaceChangesProvider(workspaceId));

    return async.when(
      data: (result) => _body(context, result, workspaceId),
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
                    itemBuilder: (context, i) {
                      final change = snapshot.changes[i];
                      final expanded = _expanded.contains(change.relPath);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ChangeRow(
                            change: change,
                            expanded: expanded,
                            onTap: () => setState(() {
                              expanded
                                  ? _expanded.remove(change.relPath)
                                  : _expanded.add(change.relPath);
                            }),
                            onCopyPath: () async {
                              await Clipboard.setData(
                                ClipboardData(text: change.relPath),
                              );
                              if (context.mounted) {
                                AppToast.success(context, '已复制文件路径');
                              }
                            },
                            onRevert: () => _revertFile(
                              context,
                              workspaceId,
                              snapshot,
                              change,
                            ),
                          ),
                          if (expanded)
                            _InlineDiff(
                              workspaceId: workspaceId,
                              snapshot: snapshot,
                              change: change,
                              onOpenFull: () => _openDiff(
                                context,
                                workspaceId,
                                snapshot,
                                change,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// 逐文件「还原此文件」：二次确认后把该文件恢复到 HEAD 版本
  /// （新增/未跟踪文件则删除），成功后刷新改动清单。
  Future<void> _revertFile(
    BuildContext context,
    String? workspaceId,
    AgentChangesSnapshot snapshot,
    AgentFileChange change,
  ) async {
    final isNew = change.status == GitFileStatus.untracked ||
        change.status == GitFileStatus.added;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('还原此文件？'),
        content: Text(
          isNew
              ? '${change.relPath}\n\n该文件在 HEAD 中不存在，还原将直接删除它，不可撤销。'
              : '${change.relPath}\n\n将丢弃该文件的全部未提交改动，恢复为 HEAD 版本，不可撤销。',
        ),
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
            child: Text(isNew ? '删除文件' : '还原'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(_revertFileProvider((workspaceId, snapshot, change)).future);
      if (context.mounted) {
        AppToast.success(context, isNew ? '已删除 ${change.relPath}' : '已还原 ${change.relPath}');
      }
      setState(() => _expanded.remove(change.relPath));
      ref.invalidate(agentWorkspaceChangesProvider(workspaceId));
    } catch (e) {
      if (context.mounted) AppToast.error(context, '还原失败 · $e');
    }
  }

  Future<void> _openDiff(
    BuildContext context,
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

final _revertFileProvider = FutureProvider.autoDispose.family<void,
    (String?, AgentChangesSnapshot, AgentFileChange)>((ref, args) {
  final (workspaceId, snapshot, change) = args;
  return revertAgentFileChange(ref, workspaceId, snapshot, change);
});

final _fileDiffProvider = FutureProvider.autoDispose.family<
    ({String oldText, String newText}),
    (String?, AgentChangesSnapshot, AgentFileChange)>((ref, args) {
  final (workspaceId, snapshot, change) = args;
  return loadAgentFileDiff(ref, workspaceId, snapshot, change);
});

(String, Color) _statusBadge(BuildContext context, GitFileStatus status) {
  final theme = Theme.of(context);
  return switch (status) {
    GitFileStatus.modified => ('Modified', Colors.orange),
    GitFileStatus.added => ('Added', Colors.green),
    GitFileStatus.untracked => ('Added', Colors.green),
    GitFileStatus.deleted => ('Deleted', theme.colorScheme.error),
    GitFileStatus.renamed => ('Renamed', Colors.blue),
    GitFileStatus.conflicted => ('Conflict', theme.colorScheme.error),
  };
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.change,
    required this.expanded,
    required this.onTap,
    required this.onCopyPath,
    required this.onRevert,
  });

  final AgentFileChange change;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onCopyPath;
  final VoidCallback onRevert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (label, color) = _statusBadge(context, change.status);
    final dir = change.relPath.contains('/')
        ? change.relPath.substring(0, change.relPath.lastIndexOf('/'))
        : null;
    // 对齐 Devin Changes：文件名 + 灰色目录同行，右侧 复制 · +N -M · 徽标。
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
              size: 15,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: change.relPath.split('/').last,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (dir != null)
                      TextSpan(
                        text: '  $dir',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onCopyPath,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.copy,
                  size: 13,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onRevert,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.undo2,
                  size: 13,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ),
            const SizedBox(width: 6),
            if ((change.additions ?? 0) > 0 || change.status != GitFileStatus.deleted) ...[
              Text(
                '+${change.additions ?? 0}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
            ],
            if ((change.deletions ?? 0) > 0) ...[
              Text(
                '-${change.deletions}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 行内手风琴 diff 面板：限行数渲染，超出提供「全屏查看」。
class _InlineDiff extends ConsumerWidget {
  const _InlineDiff({
    required this.workspaceId,
    required this.snapshot,
    required this.change,
    required this.onOpenFull,
  });

  static const int _maxRows = 300;

  final String? workspaceId;
  final AgentChangesSnapshot snapshot;
  final AgentFileChange change;
  final VoidCallback onOpenFull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async =
        ref.watch(_fileDiffProvider((workspaceId, snapshot, change)));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '加载 diff 失败 · $e',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        data: (diff) {
          final rows = computeLineDiff(diff.oldText, diff.newText);
          if (rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '两个版本内容一致',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          final visible = rows.take(_maxRows).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DevinDiffLines(rows: visible),
              if (rows.length > _maxRows)
                TextButton.icon(
                  onPressed: onOpenFull,
                  icon: const Icon(LucideIcons.expand, size: 14),
                  label: Text('还有 ${rows.length - _maxRows} 行，全屏查看'),
                ),
            ],
          );
        },
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
