import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart'
    show kMaxCheckpointRefsPerTask;
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_tool_detail.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// 检查点的展示状态。
enum _CkptState {
  /// 后台正在拍 git 快照。
  snapshotting,

  /// 可回滚。
  ready,

  /// 快照没完成（App 中途被杀 / 失败残留），不可回滚。
  interrupted,

  /// 快照 ref 已超出保留上限被清理。
  expired,
}

/// 检查点之后发生了什么（从事件流推算，无需跑 git）。
class _CkptStats {
  const _CkptStats({
    required this.number,
    required this.files,
    required this.messages,
    required this.newerSnapshots,
  });

  /// 本任务里第几个检查点（从 1 开始）。
  final int number;

  /// 之后被智能体改动的文件路径（去重）。
  final Set<String> files;

  /// 之后的用户 + 助手消息条数（回滚对话会删掉这些）。
  final int messages;

  /// 之后又拍了多少个快照（超出保留上限说明本检查点已被清理）。
  final int newerSnapshots;

  static _CkptStats of(List<AgentEvent> events, CheckpointEvent ckpt) {
    var number = 0;
    // 复用的快照（工作区没变）不新建 ref，按不同 commit 计数。
    final newerCommits = <String>{};
    final own = ckpt.commits.values.join(',');
    var messages = 0;
    final files = <String>{};
    for (final e in events) {
      if (e is CheckpointEvent) {
        if (e.seq <= ckpt.seq) number++;
        if (e.seq > ckpt.seq && e.commits.isNotEmpty) {
          final key = e.commits.values.join(',');
          if (key != own) newerCommits.add(key);
        }
        continue;
      }
      if (e.seq <= ckpt.seq) continue;
      switch (e) {
        case UserMessageEvent() || AssistantTextEvent():
          messages++;
        case ToolCallEvent(state: AgentToolCallState.success):
          files.addAll(
            toolChangedFilePaths(
              e.toolName,
              e.argsDetail ?? '',
              resultText: e.resultDetail,
            ),
          );
        default:
          break;
      }
    }
    return _CkptStats(
      number: number,
      files: files,
      messages: messages,
      newerSnapshots: newerCommits.length,
    );
  }
}

String _hhmm(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// 检查点时间线节点（V2）：旗标节点 + 「检查点 #N · 时间」+ 之后改了几个
/// 文件 / 几条消息，右侧按状态显示「回滚」/ 快照中 / 已过期 / 快照中断。
/// 点回滚弹预览面板：范围分段选择、将触达的文件（可看 diff）、后果说明。
class CheckpointTile extends ConsumerStatefulWidget {
  const CheckpointTile({required this.event, required this.taskId, super.key});

  final CheckpointEvent event;
  final String taskId;

  @override
  ConsumerState<CheckpointTile> createState() => _CheckpointTileState();
}

class _CheckpointTileState extends ConsumerState<CheckpointTile> {
  bool _busy = false;

  /// 预览时 git 报告提交已不存在 → 本地标记过期。
  bool _expiredByGit = false;

  _CkptState _stateOf(_CkptStats? stats) {
    final e = widget.event;
    if (e.commits.isEmpty) {
      return ref.read(agentTaskRunnerProvider.notifier).isSnapshotting(e.id)
          ? _CkptState.snapshotting
          : _CkptState.interrupted;
    }
    if (_expiredByGit ||
        (stats != null && stats.newerSnapshots >= kMaxCheckpointRefsPerTask)) {
      return _CkptState.expired;
    }
    return _CkptState.ready;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.5);
    final running = ref.watch(agentTaskRunnerProvider).contains(widget.taskId);
    final events = ref.watch(agentTaskEventsProvider(widget.taskId)).value;
    final stats = events == null ? null : _CkptStats.of(events, widget.event);
    final state = _stateOf(stats);
    final isSafety = widget.event.label == '回滚前自动快照';
    final title = stats == null
        ? '检查点 · ${_hhmm(widget.event.at)}'
        : '${isSafety ? '回滚前快照' : '检查点'} #${stats.number} · ${_hhmm(widget.event.at)}';

    final String detail;
    switch (state) {
      case _CkptState.snapshotting:
        detail = '正在保存工作区快照，智能体改文件前会等它完成';
      case _CkptState.interrupted:
        detail = '快照没有完成（可能是 App 中途退出），无法回滚';
      case _CkptState.expired:
        detail = '快照已超出保留上限（每个任务 $kMaxCheckpointRefsPerTask 个）被清理';
      case _CkptState.ready:
        if (stats == null) {
          detail = widget.event.label;
        } else {
          final parts = [
            if (stats.files.isNotEmpty) '之后改了 ${stats.files.length} 个文件',
            if (stats.messages > 0) '${stats.messages} 条消息',
          ];
          detail = parts.isEmpty ? '之后还没有改动' : parts.join(' · ');
        }
    }

    final accent = state == _CkptState.ready ? cs.primary : muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: state == _CkptState.ready
                  ? cs.primary.withValues(alpha: 0.12)
                  : cs.onSurface.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: state == _CkptState.snapshotting
                ? SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: muted),
                  )
                : Icon(
                    isSafety ? LucideIcons.lifeBuoy : LucideIcons.flag,
                    size: 10,
                    color: accent,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: state == _CkptState.ready
                        ? cs.onSurface.withValues(alpha: 0.75)
                        : muted,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10.5,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_busy)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            switch (state) {
              _CkptState.ready => FilledButton.tonal(
                onPressed: running ? null : () => _startRollback(stats),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('回滚'),
              ),
              _CkptState.snapshotting => _StateChip('快照中', color: muted),
              _CkptState.interrupted => _StateChip('不可用', color: muted),
              _CkptState.expired => const _StateChip(
                '已过期',
                color: Color(0xFFCA8A04),
              ),
            },
        ],
      ),
    );
  }

  Future<void> _startRollback(_CkptStats? stats) async {
    final task = ref
        .read(agentTasksProvider)
        .where((t) => t.id == widget.taskId)
        .firstOrNull;
    if (task == null) return;

    setState(() => _busy = true);
    List<RollbackFileChange> preview;
    try {
      preview = await ref
          .read(agentTaskRunnerProvider.notifier)
          .previewRollback(task, widget.event);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          if ('$e'.contains('已不存在')) _expiredByGit = true;
        });
        _toast('回滚预览失败：$e', isError: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final mode = await showModalBottomSheet<AgentRollbackMode>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RollbackPreviewSheet(
        number: stats?.number,
        at: widget.event.at,
        label: widget.event.label,
        messages: stats?.messages ?? 0,
        files: preview,
        loadDiff: (file) => ref
            .read(agentTaskRunnerProvider.notifier)
            .rollbackFileDiff(task, widget.event, file),
      ),
    );
    if (mode == null || !mounted) return;

    setState(() => _busy = true);
    String? error;
    AgentRollbackResult? result;
    try {
      result = await ref
          .read(agentTaskRunnerProvider.notifier)
          .rollbackToCheckpoint(task, widget.event, mode: mode);
    } catch (e) {
      error = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    _toast(
      isError: error != null,
      error != null
          ? '回滚失败：$error'
          : switch (mode) {
              AgentRollbackMode.messagesOnly => '已回滚对话，已提醒智能体重新确认文件',
              AgentRollbackMode.filesOnly =>
                '已还原 ${result!.files.length} 个文件，已告知智能体',
              AgentRollbackMode.filesAndMessages =>
                '已回滚对话与 ${result!.files.length} 个文件',
            },
    );
  }

  void _toast(String text, {bool isError = false}) {
    if (isError) {
      AppToast.error(context, text);
    } else {
      AppToast.success(context, text);
    }
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// 回滚预览面板（V2）：标题「回滚到检查点 #N · 时间」、摘要胶囊、范围
/// 分段、将触达的文件（可点看 diff）、后果说明，确认后 pop 选中的模式。
class _RollbackPreviewSheet extends StatefulWidget {
  const _RollbackPreviewSheet({
    required this.number,
    required this.at,
    required this.label,
    required this.messages,
    required this.files,
    required this.loadDiff,
  });

  final int? number;
  final DateTime at;
  final String label;
  final int messages;
  final List<RollbackFileChange> files;
  final Future<String> Function(RollbackFileChange file) loadDiff;

  @override
  State<_RollbackPreviewSheet> createState() => _RollbackPreviewSheetState();
}

class _RollbackPreviewSheetState extends State<_RollbackPreviewSheet> {
  AgentRollbackMode _mode = AgentRollbackMode.filesAndMessages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.6);
    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    final files = widget.files;
    final touchFiles = _mode != AgentRollbackMode.messagesOnly;
    final touchMessages = _mode != AgentRollbackMode.filesOnly;

    Widget pill(String text, {Color? color}) {
      final c = color ?? muted;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
        ),
      );
    }

    final consequence = switch (_mode) {
      AgentRollbackMode.filesAndMessages =>
        '之后的 ${widget.messages} 条消息会被删除，文件还原到这个检查点。',
      AgentRollbackMode.filesOnly =>
        '对话保留；会自动告诉智能体"文件已还原"，避免它以为之前的修改还在。',
      AgentRollbackMode.messagesOnly =>
        '只删除之后的 ${widget.messages} 条消息，文件保持现状；会提醒智能体先重新读取文件。',
    };

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.number == null
                          ? '回滚到此检查点'
                          : '回滚到检查点 #${widget.number}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(_hhmm(widget.at), style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ],
              ),
              if (widget.label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '回到「${widget.label}」发送之前',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  pill('${files.length} 个文件', color: cs.primary),
                  pill('${widget.messages} 条消息'),
                  pill('回滚前自动保存', color: const Color(0xFF16A34A)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<AgentRollbackMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: theme.textTheme.labelMedium,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: AgentRollbackMode.filesAndMessages,
                      label: Text('文件 + 对话'),
                    ),
                    ButtonSegment(
                      value: AgentRollbackMode.filesOnly,
                      label: Text('仅文件'),
                    ),
                    ButtonSegment(
                      value: AgentRollbackMode.messagesOnly,
                      label: Text('仅对话'),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ),
              const SizedBox(height: 10),
              if (touchFiles) ...[
                if (files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '没有检测到文件差异',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: files.length,
                      itemBuilder: (context, i) => _FileRow(
                        file: files[i],
                        loadDiff: widget.loadDiff,
                        showRepo: files.map((f) => f.repoRoot).toSet().length > 1,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$consequence'
                  '${touchFiles ? '\n回滚前会自动保存当前状态，之后可以再滚回来；.gitignore 里的文件（如 build/、.env）不受影响。' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    height: 1.45,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_mode),
                      child: Text(switch ((touchFiles, touchMessages)) {
                        (true, true) => files.isEmpty
                            ? '回滚对话与文件'
                            : '回滚对话与 ${files.length} 个文件',
                        (true, false) =>
                          files.isEmpty ? '回滚文件' : '回滚 ${files.length} 个文件',
                        _ => '回滚对话',
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.loadDiff,
    this.showRepo = false,
  });

  final RollbackFileChange file;
  final Future<String> Function(RollbackFileChange file) loadDiff;
  final bool showRepo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (badge, color, action) = switch (file.kind) {
      RollbackFileKind.added => ('A', Colors.green, '回滚将删除'),
      RollbackFileKind.modified => ('M', Colors.orange, '回滚将还原'),
      RollbackFileKind.deleted => ('D', Colors.red, '回滚将恢复'),
    };
    return InkWell(
      onTap: () => _showDiff(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                showRepo && file.repoName.isNotEmpty
                    ? '${file.repoName}/${file.path}'
                    : file.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (file.insertions != null || file.deletions != null) ...[
              const SizedBox(width: 8),
              if ((file.insertions ?? 0) > 0)
                Text(
                  '+${file.insertions}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontFamily: 'monospace',
                  ),
                ),
              if ((file.insertions ?? 0) > 0 && (file.deletions ?? 0) > 0)
                const SizedBox(width: 4),
              if ((file.deletions ?? 0) > 0)
                Text(
                  '-${file.deletions}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.red,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
            const SizedBox(width: 8),
            Text(
              action,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDiff(BuildContext context) async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          file.path.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<String>(
            future: loadDiff(file),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('取 diff 失败：${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final diff = snapshot.data!.trim();
              if (diff.isEmpty) {
                return const Text('（检查点之后新增的未跟踪文件，回滚将直接删除，无逐行 diff）');
              }
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    diff,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
