import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart';
import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
import 'package:aetherlink_flutter/app/di/agent_hooks_access.dart';
import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_checkpoint_service.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_compaction_progress.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_compaction_settings.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_manual_compact_service.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_subagent_runner.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/shared/services/streaming_keepalive_service.dart';

export 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart'
    show AgentRollbackResult, RollbackFileChange, RollbackFileKind;
export 'package:aetherlink_flutter/features/agent/application/agent_checkpoint_service.dart'
    show AgentRollbackMode;

part 'agent_task_runner.g.dart';

/// 任务执行编排：组装引擎依赖、持有每任务的取消 token、
/// 把引擎的任务写回同步到 [AgentTasks]。
/// 真 LLM/真工具/三层审批门均经 app/di 的 [agentRuntime] 组装注入。
@Riverpod(keepAlive: true)
class AgentTaskRunner extends _$AgentTaskRunner {
  final Map<String, AgentCancellationToken> _tokens = {};

  /// 共享单例：seq 缓存在 store 内，多入口（引擎/插队消息）必须同一份。
  AgentEventStore? _storeInstance;

  late final AgentCheckpointService _checkpoints = AgentCheckpointService(
    ref: ref,
    store: _store,
    isRunning: (taskId) => state.contains(taskId),
  );

  late final AgentSubagentRunner _subagents = AgentSubagentRunner(
    ref: ref,
    store: _store,
    gateway: _ProviderTaskGateway(this),
    budgetFromSettings: _budgetFromSettings,
    hookTimelineFor: _hookTimelineFor,
    hookRewakeFor: _hookRewakeFor,
    onBackgroundChildStarted: (taskId, token) {
      _tokens[taskId] = token;
      state = {...state, taskId};
    },
    onBackgroundChildFinished: (taskId) {
      _tokens.remove(taskId);
      state = {
        for (final id in state)
          if (id != taskId) id,
      };
      if (state.isEmpty) {
        unawaited(StreamingKeepAliveService.release('agent'));
      }
    },
  );

  late final AgentManualCompactService _manualCompact =
      AgentManualCompactService(
        ref: ref,
        store: _store,
        isRunning: (taskId) => state.contains(taskId),
      );

  /// 用户在运行中手动切模式的任务（taskId → 目标模式）：引擎在下个
  /// 安全点暂停后，whenComplete 里落新模式并以新工具目录自动续跑
  ///（引擎暂停时会用自己的旧快照回写任务，模式必须在它之后再落）。
  final Map<String, AgentSessionMode> _pendingUserModeSwitch = {};

  /// 正在运行的任务 id 集合（UI 可 watch）。
  @override
  Set<String> build() => const {};

  /// 新建话题（对齐聊天 handleCreateTopic）：立即创建一条空白草稿话题
  /// 占位到列表顶部，发第一条消息才定标题并启动引擎。
  Future<AgentTask> createDraft({
    required AgentProfile profile,
    required AgentSessionMode mode,
  }) async {
    final now = DateTime.now();
    final task = AgentTask(
      id: 'task-${now.millisecondsSinceEpoch}',
      profileId: profile.id,
      title: '新话题',
      workspaceId: profile.workspaceId ?? '',
      workspaceName: profile.workspaceName ?? '未绑定工作区',
      status: AgentTaskStatus.draft,
      mode: mode,
      createdAt: now,
      updatedAt: now,
      modelLabel:
          await ref.read(agentRuntimeProvider).currentModelLabel() ?? '未配置模型',
    );
    await ref.read(agentTasksProvider.notifier).apply(task);
    return task;
  }

  /// 草稿话题发第一条消息：用消息定标题 + 落用户消息 + 启动引擎。
  Future<void> startDraft(
    AgentTask task,
    String text, {
    required AgentSessionMode mode,
    List<AgentUserAttachment> attachments = const [],
  }) async {
    final processed = await _promptAfterHooks(task.id, task.workspaceId, text);
    if (processed == null) return;
    final updated = task.copyWith(
      title: _titleFrom(text),
      status: AgentTaskStatus.running,
      mode: mode,
      updatedAt: DateTime.now(),
      lastEventSummary: text,
    );
    await ref.read(agentTasksProvider.notifier).apply(updated);
    await _checkpoint(updated, text);
    await _store().appendUserMessage(
      updated.id,
      processed,
      attachments: attachments,
    );
    _run(updated);
  }

  /// 无话题选中时发第一条消息：创建任务 + 落用户消息 + 启动引擎。
  Future<AgentTask> startNewTask({
    required AgentProfile profile,
    required String text,
    required AgentSessionMode mode,
    List<AgentUserAttachment> attachments = const [],
  }) async {
    final now = DateTime.now();
    final task = AgentTask(
      id: 'task-${now.millisecondsSinceEpoch}',
      profileId: profile.id,
      title: _titleFrom(text),
      workspaceId: profile.workspaceId ?? '',
      workspaceName: profile.workspaceName ?? '未绑定工作区',
      status: AgentTaskStatus.running,
      mode: mode,
      createdAt: now,
      updatedAt: now,
      modelLabel:
          await ref.read(agentRuntimeProvider).currentModelLabel() ?? '未配置模型',
      lastEventSummary: text,
    );
    await ref.read(agentTasksProvider.notifier).apply(task);
    final processed = await _promptAfterHooks(task.id, task.workspaceId, text);
    if (processed == null) {
      final blocked = task.copyWith(status: AgentTaskStatus.draft);
      await ref.read(agentTasksProvider.notifier).apply(blocked);
      return blocked;
    }
    await _checkpoint(task, text);
    await _store().appendUserMessage(
      task.id,
      processed,
      attachments: attachments,
    );
    _run(task);
    return task;
  }

  /// 给已有任务发消息：执行中排队注入（L3），非执行中落消息并续跑；
  /// [mode] 非空时同步话题模式（输入区 chips 中途切模式）。
  Future<void> sendMessage(
    AgentTask task,
    String text, {
    bool queued = false,
    AgentSessionMode? mode,
    List<AgentUserAttachment> attachments = const [],
  }) async {
    final processed = await _promptAfterHooks(task.id, task.workspaceId, text);
    if (processed == null) return;
    if (!queued && mode != null && mode != task.mode) {
      await _store().appendStatusChange(
        task.id,
        '模式切换：${task.mode.name} → ${mode.name}',
      );
    }
    if (!queued) {
      await _checkpoint(task.copyWith(mode: mode), text);
    }
    await _store().appendUserMessage(
      task.id,
      processed,
      queued: queued,
      attachments: attachments,
    );
    if (!queued) {
      final updated = task.copyWith(
        status: AgentTaskStatus.running,
        mode: mode,
        updatedAt: DateTime.now(),
        lastEventSummary: text,
      );
      await ref.read(agentTasksProvider.notifier).apply(updated);
      _run(updated);
    }
  }

  /// 回答 ask_user 提问：校验提问仍是最新待答项，以 replyToQuestionId
  /// 落用户消息并续跑任务。
  Future<void> answerUserQuestion(
    AgentTask task,
    UserQuestionEvent question,
    String answer,
  ) async {
    if (state.contains(task.id)) return;
    final text = answer.trim();
    if (text.isEmpty) throw StateError('回答不能为空');
    final events = await _store().getEvents(task.id);
    final pending = latestPendingUserQuestion(events);
    if (task.status != AgentTaskStatus.waitingInput ||
        pending?.id != question.id) {
      throw StateError('该提问已失效或任务不再等待回答');
    }

    final processed = await _promptAfterHooks(task.id, task.workspaceId, text);
    if (processed == null) return;
    await _checkpoint(task, text);
    await _store().appendUserMessage(
      task.id,
      processed,
      replyToQuestionId: question.id,
    );
    final updated = task.copyWith(
      status: AgentTaskStatus.running,
      updatedAt: DateTime.now(),
      lastEventSummary: text,
    );
    await ref.read(agentTasksProvider.notifier).apply(updated);
    _run(updated);
  }

  /// 底部输入框直接回复最新提问时走这里。
  Future<void> answerLatestUserQuestion(AgentTask task, String text) async {
    final events = await _store().getEvents(task.id);
    final question = latestPendingUserQuestion(events);
    if (question == null) throw StateError('没有待回答的提问');
    await answerUserQuestion(task, question, text);
  }

  /// 立即打断并发送：排队消息 + 打断当前执行（LLM 流/工具/审批挂起
  /// 都生效），循环继续，下一个安全点先消费排队消息。
  Future<void> interruptAndSend(
    AgentTask task,
    String text, {
    List<AgentUserAttachment> attachments = const [],
  }) async {
    await _store().appendUserMessage(
      task.id,
      text,
      queued: true,
      interrupt: true,
      attachments: attachments,
    );
    _tokens[task.id]?.requestToolInterrupt();
    // waitingApproval 时引擎阻塞在审批挂起，不消费打断标记：
    // 把挂起审批按拒绝回填让循环继续，否则消息会一直排队
    // 等审批卡被处理。
    ref
        .read(agentApprovalRegistryProvider.notifier)
        .respond(
          task.id,
          const AgentApprovalDecision(approved: false, reason: '用户打断并发送了新消息'),
        );
  }

  /// 续跑 paused/waitingInput 的任务（恢复语义 L7：重放上下文接着跑）。
  Future<void> resume(AgentTask task) async {
    if (state.contains(task.id)) return;
    final updated = task.copyWith(
      status: AgentTaskStatus.running,
      updatedAt: DateTime.now(),
    );
    await ref.read(agentTasksProvider.notifier).apply(updated);
    _run(updated);
  }

  /// Plan→Code 一键转（设计初稿 §七）：方案确认后切 Code 模式，
  /// 注入确认消息并续跑执行（切模式出审计事件）。
  Future<void> convertPlanToCode(AgentTask task) async {
    if (state.contains(task.id)) return;
    await _store().appendStatusChange(task.id, '模式切换：plan → code（方案已确认）');
    await _checkpoint(
      task.copyWith(mode: AgentSessionMode.code),
      '方案已确认，转 Code 执行',
    );
    await _store().appendUserMessage(task.id, '方案已确认，请按方案开始执行。');
    final updated = task.copyWith(
      status: AgentTaskStatus.running,
      mode: AgentSessionMode.code,
      updatedAt: DateTime.now(),
      lastEventSummary: '方案已确认，转 Code 执行',
    );
    await ref.read(agentTasksProvider.notifier).apply(updated);
    _run(updated);
  }

  /// 回滚到检查点：详见 [AgentCheckpointService.rollbackToCheckpoint]。
  Future<AgentRollbackResult?> rollbackToCheckpoint(
    AgentTask task,
    CheckpointEvent checkpoint, {
    AgentRollbackMode mode = AgentRollbackMode.filesAndMessages,
  }) => _checkpoints.rollbackToCheckpoint(task, checkpoint, mode: mode);

  /// 回滚预览：该检查点 vs 当前工作区会触达的文件清单（不改状态）。
  Future<List<RollbackFileChange>> previewRollback(
    AgentTask task,
    CheckpointEvent checkpoint,
  ) => _checkpoints.previewRollback(task, checkpoint);

  /// 预览面板里单文件的文本 diff（检查点 vs 当前工作区）。
  Future<String> rollbackFileDiff(
    AgentTask task,
    CheckpointEvent checkpoint,
    RollbackFileChange file,
  ) => _checkpoints.rollbackFileDiff(task, checkpoint, file);

  /// 每条用户消息落地前都落检查点：详见 [AgentCheckpointService.checkpoint]。
  Future<void> _checkpoint(AgentTask task, String text) =>
      _checkpoints.checkpoint(task, _titleFrom(text));

  void pause(String taskId) => _tokens[taskId]?.requestPause();

  /// 手动切换任务模式（对标运行中切 Plan/Code）：落审计事件 + 更新任务；
  /// 切入 Plan 时记录 prePlanMode（方案批准退出时恢复），切出 Plan 清标记。
  /// 运行中的任务：工具目录/系统提示是按模式在运行开始时构建的，
  /// 请求引擎在下个安全点暂停，完成后自动以新模式续跑。
  Future<void> switchMode(AgentTask task, AgentSessionMode newMode) async {
    if (task.mode == newMode) return;
    await _store().appendStatusChange(
      task.id,
      '模式切换：${task.mode.name} → ${newMode.name}（用户手动）',
    );
    if (state.contains(task.id)) {
      // 运行中：不在这里落模式（引擎暂停时会用旧快照回写覆盖掉），
      // 挂 pending 由 whenComplete 在引擎退出后落模式并续跑。
      _pendingUserModeSwitch[task.id] = newMode;
      _tokens[task.id]?.requestPause();
      return;
    }
    await ref.read(agentTasksProvider.notifier).apply(_withMode(task, newMode));
  }

  /// 切模式的字段变更：切入 Plan 记 prePlanMode（方案批准退出时恢复），
  /// 切出 Plan 清标记。
  static AgentTask _withMode(AgentTask task, AgentSessionMode newMode) {
    final enteringPlan =
        newMode == AgentSessionMode.plan &&
        (task.mode == AgentSessionMode.code ||
            task.mode == AgentSessionMode.auto);
    return task.copyWith(
      mode: newMode,
      prePlanMode: enteringPlan ? task.mode : null,
      clearPrePlanMode: !enteringPlan,
      updatedAt: DateTime.now(),
    );
  }

  /// 手动压缩入口（详见 [AgentManualCompactService]）。
  Future<String> compactNow(AgentTask task, {String? customInstructions}) =>
      _manualCompact.compactNow(task, customInstructions: customInstructions);

  void cancelCompactNow(String taskId) =>
      _manualCompact.cancelCompactNow(taskId);

  Future<void> revokeCompaction(String taskId, CompactionEvent event) =>
      _manualCompact.revokeCompaction(taskId, event);

  void forceStop(String taskId) => _tokens[taskId]?.requestCancel();

  /// 从设置组装引擎预算：上下文窗口取侧栏设置，压缩开关/阈值取
  /// 压缩设置页；主任务与 subagent 共用同一来源，任务启动时一次性
  /// 快照。主任务轮数/token 默认不限（0），子代理调用方显式传上限。
  AgentBudget _budgetFromSettings({int? maxRounds, int? maxTokens}) {
    final compaction = ref.read(agentCompactionSettingsProvider);
    return AgentBudget(
      maxRounds: maxRounds ?? 0,
      maxTokens: maxTokens ?? 0,
      contextLimitTokens: ref
          .read(agentUiSettingsControllerProvider)
          .contextLimit,
      autoCompactEnabled: compaction.autoCompactEnabled,
      microCompactEnabled: compaction.microCompactEnabled,
      compactionTriggerRatio: compaction.triggerRatio,
      compactionTriggerChars: compaction.compactionTriggerChars,
      compactionKeepChars: compaction.keepChars,
      microCompactTriggerChars: compaction.microCompactTriggerChars,
    );
  }

  /// userPromptSubmit hooks：用户消息进入任务前过一遍 hooks——
  /// block → 消息不进上下文，落状态事件说明拦截原因并返回 null；
  /// additionalContext → 追加到消息后注入模型上下文；无 hooks /
  /// hook 自身异常 → 原样返回。
  Future<String?> _promptAfterHooks(
    String taskId,
    String workspaceId,
    String text,
  ) async {
    try {
      final result = await runUserPromptSubmitHooks(
        ref,
        workspaceId: workspaceId,
        prompt: text,
      );
      if (result == null) return text;
      if (result.preventContinuation) {
        await _store().appendStatusChange(
          taskId,
          '[userPromptSubmit hook 终止] ${result.stopReason.isNotEmpty ? result.stopReason : 'hook 要求终止任务（continue:false）'}',
        );
        return null;
      }
      if (result.outcome == AgentHookOutcome.block) {
        await _store().appendStatusChange(
          taskId,
          '[userPromptSubmit hook 拦截] ${result.message}',
        );
        return null;
      }
      if (result.additionalContext.isNotEmpty) {
        return '$text\n\n[userPromptSubmit hook additionalContext]\n'
            '${result.additionalContext}';
      }
    } catch (_) {}
    return text;
  }

  Future<void> _run(AgentTask task) async {
    if (state.contains(task.id)) return;
    final token = AgentCancellationToken();
    _tokens[task.id] = token;
    state = {...state, task.id};
    // 前台服务保活（初稿 §5.5 P1）：切后台任务继续跑，常驻通知展示运行中。
    // 每个任务启动都 acquire（幂等）：上次启动失败时这里是重试点。
    unawaited(
      StreamingKeepAliveService.acquire(
        'agent',
        title: '智能体任务运行中…',
        text: 'AetherLink 在后台继续执行任务，需要授权时会通知你',
      ),
    );

    // 档案已删的孤儿话题兜底：空专长 + 全工具组，任务仍可继续。
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
    // hooks 运行状态写进任务时间线（阶段 8）：落「运行中」状态行，
    // 完成后原位改写为结果（放行/阻断/转后台…）。
    runtime.setHookTimeline(_hookTimelineFor(task.id));
    runtime.setHookRewake(_hookRewakeFor(task.id));
    // taskStart hooks：任务启动/续跑时触发，fire-and-forget 不阻断。
    unawaited(runtime.lifecycleHooks(AgentHookEvent.taskStart));
    // 计划模式切换（enter/exit_plan_mode）：引擎落库新模式后 return，
    // 这里在本次运行清理完成后以新模式的工具目录重启续跑。
    AgentTask? modeSwitchRestart;
    final engine = AgentEngine(
      llm: runtime.llm,
      tools: runtime.tools,
      approval: runtime.approval,
      store: _store(),
      gateway: _ProviderTaskGateway(this),
      // 设置页的上下文窗口作为按 token 压缩触发的依据（usage 拿不到时
      // 回退字符估算）；压缩设置页的开关/阈值在任务启动时一次性填入
      // budget（本次运行内不变）。
      budget: _budgetFromSettings(),
      subagents: _subagents,
      toolStream: ref.read(agentToolStreamProvider.notifier),
      stopGuard: runtime.stopGuard,
      hookStopSignal: runtime.hookStopSignal,
      onTurnStart: () =>
          unawaited(runtime.lifecycleHooks(AgentHookEvent.turnStart)),
      onTurnEnd: () =>
          unawaited(runtime.lifecycleHooks(AgentHookEvent.turnEnd)),
      onTaskEnd: () =>
          unawaited(runtime.lifecycleHooks(AgentHookEvent.taskEnd)),
      onNotification: (message, type) =>
          unawaited(runtime.notificationHooks(message, notificationType: type)),
      onPreCompact: () {
        // 事件流实况行：安全点压缩开始（LLM 摘要中不可取消）。
        ref
            .read(agentCompactionProgressProvider.notifier)
            .start(
              task.id,
              phase: AgentCompactionPhase.summarizing,
              cancellable: false,
            );
        unawaited(runtime.compactionHooks(AgentHookEvent.preCompact));
      },
      onPostCompact: (summary) {
        ref.read(agentCompactionProgressProvider.notifier).finish(task.id);
        unawaited(
          runtime.compactionHooks(AgentHookEvent.postCompact, summary: summary),
        );
      },
      onCompactionFailed: () =>
          ref.read(agentCompactionProgressProvider.notifier).finish(task.id),
      manualCompactSignal: () => _manualCompact.consumeSignal(task.id),
      onModeSwitchRestart: (updated) => modeSwitchRestart = updated,
    );
    // fileChanged hooks 的工作区文件 watcher：与本次运行同生命周期
    // （无配置时 start 内部不订阅）。
    unawaited(runtime.fileWatcher.start());
    engine.run(task, token).whenComplete(() {
      unawaited(runtime.fileWatcher.stop());
      // 兜底清掉压缩实况行（压缩失败时引擎不回调 onPostCompact）。
      ref.read(agentCompactionProgressProvider.notifier).finish(task.id);
      _manualCompact.clearPending(task.id);
      _tokens.remove(task.id);
      _clearGraceIfFinished(task.id);
      state = {
        for (final id in state)
          if (id != task.id) id,
      };
      if (state.isEmpty) {
        unawaited(StreamingKeepAliveService.release('agent'));
      }
      final restart = modeSwitchRestart;
      final userSwitch = _pendingUserModeSwitch.remove(task.id);
      if (restart != null) {
        _run(restart);
      } else if (userSwitch != null) {
        // 用户运行中手动切模式：引擎已在安全点退出（通常 paused），
        // 现在落新模式并以新工具目录续跑；若任务已终止/完成则只落
        // 模式不续跑。
        final latest = ref
            .read(agentTasksProvider)
            .where((t) => t.id == task.id)
            .firstOrNull;
        if (latest != null) {
          final resume = latest.status == AgentTaskStatus.paused;
          final switched = _withMode(
            latest,
            userSwitch,
          ).copyWith(status: resume ? AgentTaskStatus.running : null);
          unawaited(
            ref.read(agentTasksProvider.notifier).apply(switched).then((_) {
              if (resume) _run(switched);
            }),
          );
        }
      }
    });
  }

  /// 某个任务的 hooks 时间线通道：运行中文案落一条状态事件，
  /// 返回的更新函数在 hooks 完成后原位改写为结果（id/seq 不变）。
  AgentHookTimelineSink _hookTimelineFor(String taskId) => (String line) async {
    final event = await _store().appendStatusChange(taskId, line);
    return (String updated) =>
        unawaited(_store().updateStatusChange(taskId, event, updated));
  };

  /// asyncRewake 反馈注入通道：反馈作为排队消息落库，引擎在安全点
  /// 消费叫醒模型；任务已结束时留待续跑进上下文。
  AgentHookRewakeSink _hookRewakeFor(String taskId) => (String feedback) async {
    await _store().appendUserMessage(taskId, feedback, queued: true);
  };

  static String _titleFrom(String text) => agentTaskTitleFrom(text);

  AgentEventStore _store() =>
      _storeInstance ??= DriftAgentEventStore(ref.read(agentDaoProvider));

  /// 任务进终态后清掉运行级审批宽限（「随任务结束失效」）；
  /// 暂停/等待输入等可续跑状态保留宽限。
  void _clearGraceIfFinished(String taskId) {
    final task = ref
        .read(agentTasksProvider)
        .where((t) => t.id == taskId)
        .firstOrNull;
    const finished = {
      AgentTaskStatus.done,
      AgentTaskStatus.cancelled,
      AgentTaskStatus.failed,
    };
    if (task == null || finished.contains(task.status)) {
      ref.read(agentApprovalRegistryProvider.notifier).clearTaskGrace(taskId);
    }
  }

  Future<void> _applyTask(AgentTask task) =>
      ref.read(agentTasksProvider.notifier).apply(task);
}

class _ProviderTaskGateway implements AgentTaskGateway {
  _ProviderTaskGateway(this._runner);

  final AgentTaskRunner _runner;

  @override
  Future<void> save(AgentTask task) => _runner._applyTask(task);
}
