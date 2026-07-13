import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
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
  });

  final AgentFileChange change;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onCopyPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = _statusBadge(context, change.status);
    final dir = change.relPath.contains('/')
        ? change.relPath.substring(0, change.relPath.lastIndexOf('/'))
        : null;
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
        size: 16,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              change.relPath.split('/').last,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          if (change.additions != null) ...[
            Text(
              '+${change.additions}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
          ],
          if ((change.deletions ?? 0) > 0)
            Text(
              '-${change.deletions}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '复制文件路径',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.copy,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            onPressed: onCopyPath,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
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
          final numStyle = TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          );
          final visible = rows.take(_maxRows).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final row in visible) buildDiffLineRow(theme, row, numStyle),
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
