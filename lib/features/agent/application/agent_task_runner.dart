import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart';
import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/app/di/agent_subagent_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/domain/subagent_profile.dart';
import 'package:aetherlink_flutter/shared/services/streaming_keepalive_service.dart';

export 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart'
    show AgentRollbackResult, RollbackFileChange, RollbackFileKind;

part 'agent_task_runner.g.dart';

/// 回滚范围：仅对话、仅工作区文件，或两者一起回到检查点。
enum AgentRollbackMode { messagesOnly, filesOnly, filesAndMessages }

/// 任务执行编排：组装引擎依赖、持有每任务的取消 token、
/// 把引擎的任务写回同步到 [AgentTasks]。
/// 真 LLM/真工具/三层审批门均经 app/di 的 [agentRuntime] 组装注入。
@Riverpod(keepAlive: true)
class AgentTaskRunner extends _$AgentTaskRunner {
  final Map<String, AgentCancellationToken> _tokens = {};

  /// 共享单例：seq 缓存在 store 内，多入口（引擎/插队消息）必须同一份。
  AgentEventStore? _storeInstance;

  /// 检查点不可用的提示每个任务只出一次（避免每条消息刷屏）。
  final Set<String> _checkpointHintShown = {};

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
    final updated = task.copyWith(
      title: _titleFrom(text),
      status: AgentTaskStatus.running,
      mode: mode,
      updatedAt: DateTime.now(),
      lastEventSummary: text,
    );
    await ref.read(agentTasksProvider.notifier).apply(updated);
    await _checkpoint(updated, text);
    await _store()
        .appendUserMessage(updated.id, text, attachments: attachments);
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
    await _checkpoint(task, text);
    await _store().appendUserMessage(task.id, text, attachments: attachments);
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
      text,
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

    await _checkpoint(task, text);
    await _store().appendUserMessage(
      task.id,
      text,
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
      attachments: attachments,
    );
    _tokens[task.id]?.requestToolInterrupt();
    // waitingApproval 时引擎阻塞在审批挂起，不消费打断标记：
    // 把挂起审批按拒绝回填让循环继续，否则消息会一直排队
    // 等审批卡被处理。
    ref.read(agentApprovalRegistryProvider.notifier).respond(
          task.id,
          const AgentApprovalDecision(
            approved: false,
            reason: '用户打断并发送了新消息',
          ),
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
    if (state.contains(task.id)) {
      throw StateError('任务正在运行，先暂停/终止后再回滚');
    }
    // 后台子代理（独立任务 id）仍在跑时一并挡掉：它们完成后会
    // 回填父任务事件，与截断竞态会把幽灵事件写回被截断区间。
    final runningChildren = [
      for (final t in ref.read(agentTasksProvider))
        if (t.parentTaskId == task.id && state.contains(t.id)) t,
    ];
    if (runningChildren.isNotEmpty) {
      throw StateError('有后台子代理仍在运行，先终止后再回滚');
    }
    AgentRollbackResult? result;
    if (mode != AgentRollbackMode.messagesOnly) {
      result = await rollbackAgentCheckpoint(
        ref,
        task.id,
        task.workspaceId.isEmpty ? null : task.workspaceId,
        checkpoint.commit,
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
        commit: result.safetyCommit,
        label: '回滚前自动快照',
      );
    }
    await _store().appendStatusChange(task.id, switch (mode) {
      AgentRollbackMode.messagesOnly =>
        '已回滚对话到检查点 ${_shortCommit(checkpoint.commit)}（工作区文件未变）',
      AgentRollbackMode.filesOnly =>
        '已回滚工作区到检查点 ${_shortCommit(checkpoint.commit)}'
            '${_fileSummary(result!.files)}'
            '（回滚前状态已保存为新检查点，可再回滚回来）',
      AgentRollbackMode.filesAndMessages =>
        '已回滚对话与工作区到检查点 ${_shortCommit(checkpoint.commit)}'
            '${_fileSummary(result!.files)}'
            '（回滚前状态已保存为新检查点，可再回滚回来）',
    });
    return result;
  }

  /// 回滚截断后的级联清理：删除被截断工具事件的大输出落盘文件，
  /// 以及由被截断 spawn_subagent 派生的隐藏子任务（含其事件流）。
  Future<void> _cleanupTruncatedEvents(List<AgentEvent> removed) async {
    final tasks = ref.read(agentTasksProvider);
    for (final e in removed.whereType<ToolCallEvent>()) {
      await deleteAgentOverflowFile(e.resultOverflowPath);
      final childId = subagentTaskIdFor(e.id);
      if (!tasks.any((t) => t.id == childId)) continue;
      // 后台子代理仍在跑时不删（其回填会因源事件已删而跳过）。
      if (state.contains(childId)) continue;
      await ref.read(agentTasksProvider.notifier).remove(childId);
    }
  }

  /// 回滚预览：该检查点 vs 当前工作区会触达的文件清单（不改状态）。
  Future<List<RollbackFileChange>> previewRollback(
    AgentTask task,
    CheckpointEvent checkpoint,
  ) => previewAgentRollback(
    ref,
    task.workspaceId.isEmpty ? null : task.workspaceId,
    checkpoint.commit,
  );

  /// 预览面板里单文件的文本 diff（检查点 vs 当前工作区）。
  Future<String> rollbackFileDiff(
    AgentTask task,
    CheckpointEvent checkpoint,
    String path,
  ) => loadRollbackFileDiff(
    ref,
    task.workspaceId.isEmpty ? null : task.workspaceId,
    checkpoint.commit,
    path,
  );

  static String _fileSummary(List<RollbackFileChange> files) {
    if (files.isEmpty) return '';
    final names = files.take(5).map((f) => f.path.split('/').last).join('、');
    final more = files.length > 5 ? ' 等' : '';
    return '，还原 ${files.length} 个文件：$names$more';
  }

  /// 每条用户消息落地前都落检查点（含 plan/ask 模式，中途切模式后
  /// 也能回滚到任意一条消息之前）；不可用/失败降级为一次性状态
  /// 提示，不阻断任务启动。
  Future<void> _checkpoint(AgentTask task, String text) async {
    try {
      final result = await createAgentCheckpoint(
        ref,
        task.id,
        task.workspaceId.isEmpty ? null : task.workspaceId,
      );
      if (result.commit != null) {
        await _store().appendCheckpoint(
          task.id,
          commit: result.commit!,
          label: _titleFrom(text),
        );
      } else if (_checkpointHintShown.add(task.id)) {
        await _store().appendStatusChange(
          task.id,
          '检查点不可用：${result.unavailableReason}',
        );
      }
    } catch (e) {
      if (_checkpointHintShown.add(task.id)) {
        await _store().appendStatusChange(task.id, '检查点创建失败：$e');
      }
    }
  }

  static String _shortCommit(String commit) =>
      commit.length > 8 ? commit.substring(0, 8) : commit;

  void pause(String taskId) => _tokens[taskId]?.requestPause();

  void forceStop(String taskId) => _tokens[taskId]?.requestCancel();

  Future<void> _run(AgentTask task) async {
    if (state.contains(task.id)) return;
    final token = AgentCancellationToken();
    _tokens[task.id] = token;
    final wasIdle = state.isEmpty;
    state = {...state, task.id};
    // 前台服务保活（初稿 §5.5 P1）：切后台任务继续跑，常驻通知展示运行中。
    if (wasIdle) {
      unawaited(
        StreamingKeepAliveService.acquire(
          'agent',
          title: '智能体任务运行中…',
          text: 'AetherLink 在后台继续执行任务，需要授权时会通知你',
        ),
      );
    }

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
    // taskStart hooks：任务启动/续跑时触发，fire-and-forget 不阻断。
    unawaited(runtime.lifecycleHooks(AgentHookEvent.taskStart));
    final engine = AgentEngine(
      llm: runtime.llm,
      tools: runtime.tools,
      approval: runtime.approval,
      store: _store(),
      gateway: _ProviderTaskGateway(this),
      budget: AgentBudget(),
      subagents: _RunnerSubagentLauncher(this),
      toolStream: ref.read(agentToolStreamProvider.notifier),
      stopGuard: runtime.stopGuard,
      onTurnStart: () =>
          unawaited(runtime.lifecycleHooks(AgentHookEvent.turnStart)),
      onTurnEnd: () =>
          unawaited(runtime.lifecycleHooks(AgentHookEvent.turnEnd)),
    );
    engine.run(task, token).whenComplete(() {
      _tokens.remove(task.id);
      _clearGraceIfFinished(task.id);
      state = {
        for (final id in state)
          if (id != task.id) id,
      };
      if (state.isEmpty) {
        unawaited(StreamingKeepAliveService.release('agent'));
      }
    });
  }

  /// 子代理专属提示（系统提示第 3 层）：强调独立上下文 + 结论自包含。
  static const String _kExploreSubagentPrompt =
      '你是一个探索子代理：在独立上下文里完成父任务派发的只读调研/搜索子任务。'
      '你看不到父任务的对话，指令里的信息就是全部上下文。完成后用 finish_task '
      '返回结论：结论是父任务唯一能看到的内容，必须自包含（关键发现、文件路径、'
      '结论依据），不要只说“已完成”。不要用 ask_user 提问。';

  static const String _kBashSubagentPrompt =
      '你是一个终端子代理：在独立上下文里执行父任务派发的命令型子任务。'
      '你看不到父任务的对话，指令里的信息就是全部上下文。完成后用 finish_task '
      '返回结论：提炼关键输出和结论，不要长篇粘贴原始输出。不要用 ask_user 提问。';

  /// 自定义档案子代理的通用后缀（拼在档案正文之后）。
  static const String _kCustomSubagentSuffix =
      '你是一个子代理，在独立上下文里完成父任务派发的子任务：'
      '你看不到父任务的对话，指令里的信息就是全部上下文。完成后用 finish_task '
      '返回自包含的结论（父任务只能看到结论）。不要用 ask_user 提问。';

  /// 派生一个子代理（初稿 §5.5 P2，对标 Cursor）：独立事件流/预算，
  /// 只把最终结论回填父任务；bash / 非只读档案的工具调用仍走现有
  /// 审批链（auto 模式工作区内照常免审）。type 为内置 explore/bash
  /// 或自定义档案名（工作区 .aetherlink/agents、.cursor/agents 的
  /// markdown 定义）。background=true 时立即返回不阻塞父循环，完成后
  /// 结论回填原工具事件并以排队消息注入父对话。
  Future<AgentToolResult> _launchSubagent({
    required AgentTask parent,
    required AgentToolCallRequest call,
    required String toolEventId,
    required AgentCancellationToken cancel,
  }) async {
    Map<String, dynamic> args;
    try {
      args = jsonDecode(call.argsJson) as Map<String, dynamic>;
    } catch (_) {
      return const AgentToolResult(ok: false, summary: '参数解析失败 ✗');
    }
    final typeName = (args['type'] as String? ?? '').trim();
    final prompt = (args['prompt'] as String? ?? '').trim();
    final description = (args['description'] as String? ?? '').trim();
    final background = args['background'] as bool? ?? false;
    if (prompt.isEmpty) {
      return const AgentToolResult(ok: false, summary: '缺少 prompt ✗');
    }
    final parentReadOnly =
        parent.mode == AgentSessionMode.ask ||
        parent.mode == AgentSessionMode.plan;
    final baseProfile = ref
        .read(agentProfilesProvider)
        .where((p) => p.id == parent.profileId)
        .firstOrNull;

    final builtin = AgentSubagentType.values
        .where((t) => t.name == typeName)
        .firstOrNull;
    final AgentSessionMode childMode;
    final AgentProfile childProfile;
    if (builtin != null) {
      if (builtin == AgentSubagentType.bash && parentReadOnly) {
        return const AgentToolResult(
          ok: false,
          summary: 'bash 子代理不可用 ✗',
          detail: '当前为只读模式（Ask/Plan），只能派 explore 子代理',
        );
      }
      childMode = builtin == AgentSubagentType.explore
          ? AgentSessionMode.ask
          : parent.mode;
      childProfile = AgentProfile(
        id: parent.profileId,
        name: builtin == AgentSubagentType.explore ? '探索子代理' : '终端子代理',
        emoji: '🤖',
        systemPrompt: builtin == AgentSubagentType.explore
            ? _kExploreSubagentPrompt
            : _kBashSubagentPrompt,
        tools: builtin == AgentSubagentType.explore
            ? (baseProfile?.tools ?? AgentToolGroup.values.toSet())
            : {AgentToolGroup.terminal},
        workspaceId: baseProfile?.workspaceId,
        workspaceName: baseProfile?.workspaceName,
      );
    } else {
      List<AgentSubagentProfile> customs;
      try {
        customs = await loadCustomSubagentProfiles(
          ref,
          parent.workspaceId.isEmpty ? null : parent.workspaceId,
        );
      } catch (_) {
        customs = const [];
      }
      final custom = customs.where((p) => p.name == typeName).firstOrNull;
      if (custom == null) {
        final names = [
          'explore',
          'bash',
          for (final p in customs) p.name,
        ].join('、');
        return AgentToolResult(
          ok: false,
          summary: '未知子代理类型 ✗',
          detail: 'type 必须是以下之一：$names',
        );
      }
      if (!custom.readonly && parentReadOnly) {
        return AgentToolResult(
          ok: false,
          summary: '子代理「${custom.name}」不可用 ✗',
          detail: '当前为只读模式（Ask/Plan），只能派只读子代理',
        );
      }
      // 工作区内的自定义档案属外来内容（提示注入面）：非只读档案
      // 不继承父任务的 auto 免审，降为 Code 模式走完整审批链。
      childMode = custom.readonly
          ? AgentSessionMode.ask
          : parent.mode == AgentSessionMode.auto
              ? AgentSessionMode.code
              : parent.mode;
      childProfile = AgentProfile(
        id: parent.profileId,
        name: custom.name,
        emoji: '🤖',
        systemPrompt: custom.systemPrompt.isEmpty
            ? _kCustomSubagentSuffix
            : '${custom.systemPrompt}\n\n$_kCustomSubagentSuffix',
        tools: baseProfile?.tools ?? AgentToolGroup.values.toSet(),
        workspaceId: baseProfile?.workspaceId,
        workspaceName: baseProfile?.workspaceName,
      );
    }

    final now = DateTime.now();
    final childId = subagentTaskIdFor(toolEventId);
    final child = AgentTask(
      id: childId,
      profileId: parent.profileId,
      title: description.isNotEmpty ? description : _titleFrom(prompt),
      workspaceId: parent.workspaceId,
      workspaceName: parent.workspaceName,
      status: AgentTaskStatus.running,
      mode: childMode,
      createdAt: now,
      updatedAt: now,
      modelLabel: parent.modelLabel,
      lastEventSummary: prompt,
      parentTaskId: parent.id,
    );
    await ref.read(agentTasksProvider.notifier).apply(child);
    await _store().appendUserMessage(childId, prompt);

    if (background) {
      unawaited(
        _runBackgroundSubagent(
          parent: parent,
          child: child,
          childProfile: childProfile,
          childMode: childMode,
          toolEventId: toolEventId,
        ),
      );
      return AgentToolResult(
        ok: true,
        summary: '后台子代理已启动',
        detail:
            '子代理「${child.title}」已在后台运行；完成后结论会更新到'
            '本工具结果，并以消息注入对话。',
      );
    }

    // 取消桥接：父任务暂停/终止 → 子代理在下个安全点终止。
    final childToken = AgentCancellationToken();
    void bridge() {
      if (cancel.stopRequested) childToken.requestCancel();
    }

    cancel.addListener(bridge);
    bridge();
    try {
      return await _runChildEngine(
        child: child,
        childProfile: childProfile,
        childMode: childMode,
        childToken: childToken,
      );
    } finally {
      cancel.removeListener(bridge);
    }
  }

  /// 后台子代理：不桥接父取消（父暂停/终止后照常跑完），token 挂
  /// [_tokens] 可单独停；完成后结论回填父工具事件 + 排队消息在父
  /// 任务下个安全点注入（父已收尾则等用户续跑时消费）。
  Future<void> _runBackgroundSubagent({
    required AgentTask parent,
    required AgentTask child,
    required AgentProfile childProfile,
    required AgentSessionMode childMode,
    required String toolEventId,
  }) async {
    final token = AgentCancellationToken();
    _tokens[child.id] = token;
    final wasIdle = state.isEmpty;
    state = {...state, child.id};
    if (wasIdle) {
      unawaited(
        StreamingKeepAliveService.acquire(
          'agent',
          title: '智能体任务运行中…',
          text: 'AetherLink 在后台继续执行任务，需要授权时会通知你',
        ),
      );
    }
    try {
      final result = await _runChildEngine(
        child: child,
        childProfile: childProfile,
        childMode: childMode,
        childToken: token,
      );
      final events = await _store().getEvents(parent.id);
      final event = events
          .whereType<ToolCallEvent>()
          .where((e) => e.id == toolEventId)
          .firstOrNull;
      // 原工具事件已被回滚对话截断删除时跳过回填/注入，
      // 避免把"幽灵"事件按旧 seq 重新插回被截断区间。
      if (event != null) {
        await _store().updateToolCall(
          parent.id,
          event,
          state: result.ok
              ? AgentToolCallState.success
              : AgentToolCallState.failure,
          resultSummary: result.summary,
          resultDetail: result.detail,
        );
        await _store().appendUserMessage(
          parent.id,
          '[后台子代理「${child.title}」${result.ok ? '已完成' : '已结束'}：'
          '${result.summary}]（完整结论已回填到对应工具结果）',
          queued: true,
        );
      }
    } catch (e) {
      // 异常也要回填父工具事件并通知，否则事件永久停在 running。
      try {
        await ref.read(agentTasksProvider.notifier).apply(child.copyWith(
              status: AgentTaskStatus.failed,
              updatedAt: DateTime.now(),
              lastEventSummary: '执行出错：$e',
            ));
        final events = await _store().getEvents(parent.id);
        final event = events
            .whereType<ToolCallEvent>()
            .where((e) => e.id == toolEventId)
            .firstOrNull;
        if (event != null) {
          await _store().updateToolCall(
            parent.id,
            event,
            state: AgentToolCallState.failure,
            resultSummary: '子代理执行出错 ✗',
            resultDetail: '$e',
          );
          await _store().appendUserMessage(
            parent.id,
            '[后台子代理「${child.title}」执行出错：$e]',
            queued: true,
          );
        }
      } catch (_) {}
    } finally {
      _tokens.remove(child.id);
      state = {
        for (final id in state)
          if (id != child.id) id,
      };
      if (state.isEmpty) {
        unawaited(StreamingKeepAliveService.release('agent'));
      }
    }
  }

  /// 跑子引擎（独立运行时/预算，不再暴露 spawn_subagent 防嵌套），
  /// 从子任务终态提取结论组装父工具结果。
  Future<AgentToolResult> _runChildEngine({
    required AgentTask child,
    required AgentProfile childProfile,
    required AgentSessionMode childMode,
    required AgentCancellationToken childToken,
  }) async {
    final runtime = await ref
        .read(agentRuntimeProvider)
        .forProfile(
          childProfile,
          mode: childMode,
          enableSubagents: false,
          boundWorkspaceId: child.workspaceId,
        );
    final engine = AgentEngine(
      llm: runtime.llm,
      tools: runtime.tools,
      approval: runtime.approval,
      store: _store(),
      gateway: _ProviderTaskGateway(this),
      budget: AgentBudget(maxRounds: 15, maxTokens: 200000),
      toolStream: ref.read(agentToolStreamProvider.notifier),
      stopGuard: runtime.stopGuard,
    );
    await engine.run(child, childToken);

    final finalChild =
        ref
            .read(agentTasksProvider)
            .where((t) => t.id == child.id)
            .firstOrNull ??
        child;
    final events = await _store().getEvents(child.id);
    final finalText =
        events.whereType<AssistantTextEvent>().lastOrNull?.text.trim() ?? '';
    final ok = finalChild.status == AgentTaskStatus.done;
    final statusLabel = switch (finalChild.status) {
      AgentTaskStatus.done => '完成',
      AgentTaskStatus.cancelled => '已终止',
      AgentTaskStatus.failed => '失败',
      AgentTaskStatus.paused => '已暂停（预算耗尽或被暂停）',
      _ => finalChild.status.name,
    };
    // finish_task 的总结落在 lastEventSummary；正文取最后一段助手文本。
    final finishSummary = ok ? finalChild.lastEventSummary.trim() : '';
    final detail = [
      if (finalText.isNotEmpty) finalText,
      if (finishSummary.isNotEmpty && finishSummary != finalText)
        '结论：$finishSummary',
    ].join('\n\n');
    return AgentToolResult(
      ok: ok,
      summary: ok ? '子代理完成 · ${finalChild.rounds} 轮' : '子代理$statusLabel ✗',
      detail: detail.isNotEmpty ? detail : '（子代理未返回结论，状态：$statusLabel）',
    );
  }

  static String _titleFrom(String text) =>
      text.length > 24 ? '${text.substring(0, 24)}…' : text;

  AgentEventStore _store() =>
      _storeInstance ??= DriftAgentEventStore(ref.read(agentDaoProvider));

  /// 任务进终态后清掉运行级审批宽限（「随任务结束失效」）；
  /// 暂停/等待输入等可续跑状态保留宽限。
  void _clearGraceIfFinished(String taskId) {
    final task =
        ref.read(agentTasksProvider).where((t) => t.id == taskId).firstOrNull;
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

class _RunnerSubagentLauncher implements AgentSubagentLauncher {
  _RunnerSubagentLauncher(this._runner);

  final AgentTaskRunner _runner;

  @override
  Future<AgentToolResult> launch({
    required AgentTask parent,
    required AgentToolCallRequest call,
    required String toolEventId,
    required AgentCancellationToken cancel,
  }) => _runner._launchSubagent(
    parent: parent,
    call: call,
    toolEventId: toolEventId,
    cancel: cancel,
  );
}

class _ProviderTaskGateway implements AgentTaskGateway {
  _ProviderTaskGateway(this._runner);

  final AgentTaskRunner _runner;

  @override
  Future<void> save(AgentTask task) => _runner._applyTask(task);
}
