import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 回滚范围：仅对话、仅工作区文件，或两者一起回到检查点。
enum AgentRollbackMode { messagesOnly, filesOnly, filesAndMessages }

/// 任务检查点与回滚（初稿 §5.5 P2）：每条用户消息前落检查点、
/// 回滚预览/执行、截断后的级联清理。由 AgentTaskRunner 组装持有。
class AgentCheckpointService {
  AgentCheckpointService({
    required Ref ref,
    required AgentEventStore Function() store,
    required bool Function(String taskId) isRunning,
  }) : _ref = ref,
       _store = store,
       _isRunning = isRunning;

  final Ref _ref;
  final AgentEventStore Function() _store;
  final bool Function(String taskId) _isRunning;

  /// 检查点不可用的提示每个任务只出一次（避免每条消息刷屏）。
  final Set<String> _hintShown = {};

  /// 每条用户消息落地前都落检查点（含 plan/ask 模式，中途切模式后
  /// 也能回滚到任意一条消息之前）；不可用/失败降级为一次性状态
  /// 提示，不阻断任务启动。
  ///
  /// 先落一个空 commits 的占位检查点（纯 DB 写，毫秒级），让紧随其后
  /// 的用户消息立即上屏；耗时的 git 快照（可能跨 proot/SSH 跑
  /// read-tree/commit-tree，秒级）转后台补写 commits。快照失败/不可用
  /// 时占位事件原位降级为状态行，不留空检查点。
  Future<void> checkpoint(AgentTask task, String label) async {
    final CheckpointEvent placeholder;
    try {
      placeholder = await _store().appendCheckpoint(
        task.id,
        commits: const {},
        label: label,
      );
    } catch (e) {
      if (_hintShown.add(task.id)) {
        await _store().appendStatusChange(task.id, '检查点创建失败：$e');
      }
      return;
    }
    unawaited(_fillCheckpoint(task, placeholder));
  }

  /// 后台补写占位检查点的 git 快照结果。
  Future<void> _fillCheckpoint(AgentTask task, CheckpointEvent event) async {
    try {
      final result = await createAgentCheckpoint(
        _ref,
        task.id,
        task.workspaceId.isEmpty ? null : task.workspaceId,
      );
      if (result.commits != null) {
        await _store().updateCheckpoint(
          task.id,
          event,
          commits: result.commits!,
        );
        return;
      }
      final hint = _hintShown.add(task.id)
          ? '检查点不可用：${result.unavailableReason}'
          : null;
      await _degradeCheckpoint(task.id, event, hint);
    } catch (e) {
      final hint = _hintShown.add(task.id) ? '检查点创建失败：$e' : null;
      await _degradeCheckpoint(task.id, event, hint);
    }
  }

  /// 占位检查点降级：首次带原因原位改写为状态行；提示出过后静默移除，
  /// 不每条消息刷一行。
  Future<void> _degradeCheckpoint(
    String taskId,
    CheckpointEvent event,
    String? hint,
  ) async {
    try {
      if (hint != null) {
        await _store().replaceCheckpointWithStatus(taskId, event, hint);
      } else {
        await _store().removeEvent(taskId, event);
      }
    } catch (_) {
      // 降级失败只影响这一行的展示（空检查点回滚时会给出可读错误）。
    }
  }

  /// 回滚到检查点（初稿 §5.5 P2）：仅限非运行态；按 [mode] 决定回滚
  /// 文件、对话，还是两者。回滚文件前自动把当前状态落为新检查点
  ///（可再回滚回来）；回滚对话把检查点之后的事件全部删除。
  /// 失败抛带可读原因的 [StateError]。返回结果含实际还原的文件清单
  ///（仅回滚对话时为 null）。
  Future<AgentRollbackResult?> rollbackToCheckpoint(
    AgentTask task,
    CheckpointEvent checkpoint, {
    AgentRollbackMode mode = AgentRollbackMode.filesAndMessages,
  }) async {
    if (_isRunning(task.id)) {
      throw StateError('任务正在运行，先暂停/终止后再回滚');
    }
    // 后台子代理（独立任务 id）仍在跑时一并挡掉：它们完成后会
    // 回填父任务事件，与截断竞态会把幽灵事件写回被截断区间。
    final runningChildren = [
      for (final t in _ref.read(agentTasksProvider))
        if (t.parentTaskId == task.id && _isRunning(t.id)) t,
    ];
    if (runningChildren.isNotEmpty) {
      throw StateError('有后台子代理仍在运行，先终止后再回滚');
    }
    AgentRollbackResult? result;
    if (mode != AgentRollbackMode.messagesOnly) {
      result = await rollbackAgentCheckpoint(
        _ref,
        task.id,
        task.workspaceId.isEmpty ? null : task.workspaceId,
        checkpoint.commits,
      );
    }
    // 文件回滚成功后再截断对话（失败时对话保持原样）；保留检查点
    // 事件本身作为锚点，之后追加的快照/状态事件从这里续增。
    if (mode != AgentRollbackMode.filesOnly) {
      final events = await _store().getEvents(task.id);
      final removed = [
        for (final e in events)
          if (e.seq > checkpoint.seq) e,
      ];
      await _store().truncateEventsAfter(task.id, checkpoint.seq);
      await _cleanupTruncatedEvents(removed);
    }
    if (result != null) {
      await _store().appendCheckpoint(
        task.id,
        commits: result.safetyCommits,
        label: '回滚前自动快照',
      );
    }
    final ckpt = _checkpointSummary(checkpoint.commits);
    await _store().appendStatusChange(task.id, switch (mode) {
      AgentRollbackMode.messagesOnly => '已回滚对话到检查点 $ckpt（工作区文件未变）',
      AgentRollbackMode.filesOnly =>
        '已回滚工作区到检查点 $ckpt'
            '${_fileSummary(result!.files)}'
            '（回滚前状态已保存为新检查点，可再回滚回来）',
      AgentRollbackMode.filesAndMessages =>
        '已回滚对话与工作区到检查点 $ckpt'
            '${_fileSummary(result!.files)}'
            '（回滚前状态已保存为新检查点，可再回滚回来）',
    });
    return result;
  }

  /// 回滚截断后的级联清理：删除被截断工具事件的大输出落盘文件，
  /// 以及由被截断 spawn_subagent 派生的隐藏子任务（含其事件流）。
  Future<void> _cleanupTruncatedEvents(List<AgentEvent> removed) async {
    final tasks = _ref.read(agentTasksProvider);
    for (final e in removed.whereType<ToolCallEvent>()) {
      await deleteAgentOverflowFile(e.resultOverflowPath);
      await deleteAgentOverflowFile(e.imagePath);
      final childId = subagentTaskIdFor(e.id);
      if (!tasks.any((t) => t.id == childId)) continue;
      // 后台子代理仍在跑时不删（其回填会因源事件已删而跳过）。
      if (_isRunning(childId)) continue;
      await _ref.read(agentTasksProvider.notifier).remove(childId);
    }
  }

  /// 回滚预览：该检查点 vs 当前工作区会触达的文件清单（不改状态）。
  Future<List<RollbackFileChange>> previewRollback(
    AgentTask task,
    CheckpointEvent checkpoint,
  ) => previewAgentRollback(
    _ref,
    task.workspaceId.isEmpty ? null : task.workspaceId,
    checkpoint.commits,
  );

  /// 预览面板里单文件的文本 diff（检查点 vs 当前工作区）。
  Future<String> rollbackFileDiff(
    AgentTask task,
    CheckpointEvent checkpoint,
    RollbackFileChange file,
  ) => loadRollbackFileDiff(
    _ref,
    task.workspaceId.isEmpty ? null : task.workspaceId,
    checkpoint.commits,
    file,
  );

  static String _fileSummary(List<RollbackFileChange> files) {
    if (files.isEmpty) return '';
    final names = files.take(5).map((f) => f.path.split('/').last).join('、');
    final more = files.length > 5 ? ' 等' : '';
    return '，还原 ${files.length} 个文件：$names$more';
  }

  /// 检查点的短摘要：首个 commit 短哈希，多仓库时附仓库数。
  static String _checkpointSummary(Map<String, String> commits) {
    final first = commits.values.firstOrNull ?? '';
    final short = first.length > 8 ? first.substring(0, 8) : first;
    return commits.length > 1 ? '$short 等 ${commits.length} 个仓库' : short;
  }
}
