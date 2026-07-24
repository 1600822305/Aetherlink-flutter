import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_compaction_progress.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_compaction_settings.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_manual_compaction.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 手动压缩编排（升级计划 ⑤/⑦，对标 CC /compact）：运行中任务挂到
/// 下一个安全点由引擎强制压缩；空闲任务直接调共享的
/// [runManualCompaction] 落 CompactionEvent。从 AgentTaskRunner 拆出，
/// 挂起请求与进度实况都在这里管理。
class AgentManualCompactService {
  AgentManualCompactService({
    required this.ref,
    required this.store,
    required this.isRunning,
  });

  final Ref ref;
  final AgentEventStore Function() store;
  final bool Function(String taskId) isRunning;

  /// 手动压缩挂起：运行中任务的手动压缩请求，taskId → 用户关注点
  /// （可为 null），引擎在下一个安全点消费。
  final Map<String, String?> _pending = {};

  /// 手动压缩：运行中任务挂起等安全点；空闲任务（暂停/完成/失败）
  /// 直接压缩。返回给 UI 的提示文案；摘要失败时抛错由调用方提示。
  Future<String> compactNow(
    AgentTask task, {
    String? customInstructions,
  }) async {
    final progress = ref.read(agentCompactionProgressProvider.notifier);
    if (isRunning(task.id)) {
      _pending[task.id] = customInstructions;
      progress.start(
        task.id,
        phase: AgentCompactionPhase.queued,
        cancellable: true,
      );
      return '任务运行中：将在下一个安全点压缩';
    }
    final profile =
        ref
            .read(agentProfilesProvider)
            .where((p) => p.id == task.profileId)
            .firstOrNull ??
        AgentProfile(
          id: task.profileId,
          name: '',
          emoji: '🤖',
          systemPrompt: '',
          tools: AgentToolGroup.values.toSet(),
        );
    final runtime = await ref
        .read(agentRuntimeProvider)
        .forProfile(
          profile,
          mode: task.mode,
          boundWorkspaceId: task.workspaceId,
        );
    final compaction = ref.read(agentCompactionSettingsProvider);
    progress.start(
      task.id,
      phase: AgentCompactionPhase.summarizing,
      cancellable: true,
    );
    try {
      final outcome = await runManualCompaction(
        task: task,
        events: await store().getEvents(task.id),
        llm: runtime.llm,
        store: store(),
        keepChars: compaction.keepChars,
        microCompactEnabled: compaction.microCompactEnabled,
        microCompactTriggerChars: compaction.microCompactTriggerChars,
        isCancelled: () => progress.isCancelRequested(task.id),
        customInstructions: customInstructions,
      );
      return switch (outcome) {
        ManualCompactionDone(:final coveredCount) =>
          '已把 $coveredCount 条较早内容压缩为摘要',
        ManualCompactionNothingToCover() => '内容太少，无需压缩',
        ManualCompactionCancelled() => '已取消压缩，未写入摘要',
      };
    } finally {
      progress.finish(task.id);
    }
  }

  /// 取消进行中的手动压缩：排队未到安全点的直接撤单；摘要生成中的
  /// 置取消标记，结果丢弃不落库。
  void cancelCompactNow(String taskId) {
    final progress = ref.read(agentCompactionProgressProvider.notifier);
    if (_pending.containsKey(taskId)) {
      _pending.remove(taskId);
      progress.finish(taskId);
      return;
    }
    progress.requestCancel(taskId);
  }

  /// 撤销一次压缩：原位标记 revoked，上下文视图恢复原样（事件流原文
  /// 本就未删）；引擎与重放侧下一轮同步生效。
  Future<void> revokeCompaction(String taskId, CompactionEvent event) =>
      store().updateCompaction(taskId, event, revoked: true);

  /// 引擎的手动压缩信号：有挂起请求即消费并返回（取后清除）。
  ManualCompactRequest? consumeSignal(String taskId) {
    if (!_pending.containsKey(taskId)) return null;
    return ManualCompactRequest(customInstructions: _pending.remove(taskId));
  }

  /// 运行结束清理挂起请求（未到安全点的请求随运行作废）。
  void clearPending(String taskId) => _pending.remove(taskId);
}
