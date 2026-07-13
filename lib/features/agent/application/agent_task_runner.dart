import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart';
import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_subagent.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/shared/services/streaming_keepalive_service.dart';

part 'agent_task_runner.g.dart';

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
    ref.read(agentTasksProvider.notifier).apply(task);
    return task;
  }

  /// 草稿话题发第一条消息：用消息定标题 + 落用户消息 + 启动引擎。
  Future<void> startDraft(
    AgentTask task,
    String text, {
    required AgentSessionMode mode,
  }) async {
    final updated = task.copyWith(
      title: _titleFrom(text),
      status: AgentTaskStatus.running,
      mode: mode,
      updatedAt: DateTime.now(),
      lastEventSummary: text,
    );
    ref.read(agentTasksProvider.notifier).apply(updated);
    await _checkpoint(updated, text);
    await _store().appendUserMessage(updated.id, text);
    _run(updated);
  }

  /// 无话题选中时发第一条消息：创建任务 + 落用户消息 + 启动引擎。
  Future<AgentTask> startNewTask({
    required AgentProfile profile,
    required String text,
    required AgentSessionMode mode,
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
    ref.read(agentTasksProvider.notifier).apply(task);
    await _checkpoint(task, text);
    await _store().appendUserMessage(task.id, text);
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
  }) async {
    if (!queued && mode != null && mode != task.mode) {
      await _store().appendStatusChange(
          task.id, '模式切换：${task.mode.name} → ${mode.name}');
    }
    if (!queued) {
      await _checkpoint(task.copyWith(mode: mode), text);
    }
    await _store().appendUserMessage(task.id, text, queued: queued);
    if (!queued) {
      final updated = task.copyWith(
        status: AgentTaskStatus.running,
        mode: mode,
        updatedAt: DateTime.now(),
        lastEventSummary: text,
      );
      ref.read(agentTasksProvider.notifier).apply(updated);
      _run(updated);
    }
  }

  /// 立即打断并发送：排队消息 + 打断当前工具（循环继续，下一轮先消费）。
  Future<void> interruptAndSend(AgentTask task, String text) async {
    await _store().appendUserMessage(task.id, text, queued: true);
    _tokens[task.id]?.requestToolInterrupt();
  }

  /// 续跑 paused/waitingInput 的任务（恢复语义 L7：重放上下文接着跑）。
  void resume(AgentTask task) {
    if (state.contains(task.id)) return;
    final updated = task.copyWith(
      status: AgentTaskStatus.running,
      updatedAt: DateTime.now(),
    );
    ref.read(agentTasksProvider.notifier).apply(updated);
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
    ref.read(agentTasksProvider.notifier).apply(updated);
    _run(updated);
  }

  /// 回滚到检查点（初稿 §5.5 P2）：仅限非运行态；回滚前自动把当前
  /// 状态落为新检查点（可再回滚回来），只还原文件不动对话。
  /// 失败抛带可读原因的 [StateError]。
  Future<void> rollbackToCheckpoint(
    AgentTask task,
    CheckpointEvent checkpoint,
  ) async {
    if (state.contains(task.id)) {
      throw StateError('任务正在运行，先暂停/终止后再回滚');
    }
    final result = await rollbackAgentCheckpoint(
      ref,
      task.id,
      task.workspaceId.isEmpty ? null : task.workspaceId,
      checkpoint.commit,
    );
    await _store().appendCheckpoint(
      task.id,
      commit: result.safetyCommit,
      label: '回滚前自动快照',
    );
    await _store().appendStatusChange(
      task.id,
      '已回滚工作区到检查点 ${_shortCommit(checkpoint.commit)}'
      '（回滚前状态已保存为新检查点，可再回滚回来）',
    );
  }

  /// 用户消息落地前落检查点（仅写入模式）；不可用/失败降级为
  /// 一次性状态提示，不阻断任务启动。
  Future<void> _checkpoint(AgentTask task, String text) async {
    if (task.mode != AgentSessionMode.code &&
        task.mode != AgentSessionMode.auto) {
      return;
    }
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

  void _run(AgentTask task) {
    if (state.contains(task.id)) return;
    final token = AgentCancellationToken();
    _tokens[task.id] = token;
    final wasIdle = state.isEmpty;
    state = {...state, task.id};
    // 前台服务保活（初稿 §5.5 P1）：切后台任务继续跑，常驻通知展示运行中。
    if (wasIdle) {
      unawaited(StreamingKeepAliveService.acquire(
        'agent',
        title: '智能体任务运行中…',
        text: 'AetherLink 在后台继续执行任务，需要授权时会通知你',
      ));
    }

    // 档案已删的孤儿话题兜底：空专长 + 全工具组，任务仍可继续。
    final profile = ref
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
    final runtime =
        ref.read(agentRuntimeProvider).forProfile(profile, mode: task.mode);
    final engine = AgentEngine(
      llm: runtime.llm,
      tools: runtime.tools,
      approval: runtime.approval,
      store: _store(),
      gateway: _ProviderTaskGateway(this),
      budget: AgentBudget(),
      subagents: _RunnerSubagentLauncher(this),
    );
    engine.run(task, token).whenComplete(() {
      _tokens.remove(task.id);
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

  /// 派生并阻塞运行一个子代理（初稿 §5.5 P2，对标 Cursor）：独立
  /// 事件流/预算，只把最终结论回填父任务；bash 型工具调用仍走现有
  /// 审批链（auto 模式工作区内照常免审）。
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
    final typeName = args['type'] as String? ?? '';
    final prompt = (args['prompt'] as String? ?? '').trim();
    final description = (args['description'] as String? ?? '').trim();
    final type = AgentSubagentType.values
        .where((t) => t.name == typeName)
        .firstOrNull;
    if (type == null) {
      return const AgentToolResult(
          ok: false,
          summary: '未知子代理类型 ✗',
          detail: 'type 必须是 explore 或 bash');
    }
    if (prompt.isEmpty) {
      return const AgentToolResult(ok: false, summary: '缺少 prompt ✗');
    }
    final parentReadOnly = parent.mode == AgentSessionMode.ask ||
        parent.mode == AgentSessionMode.plan;
    if (type == AgentSubagentType.bash && parentReadOnly) {
      return const AgentToolResult(
          ok: false,
          summary: 'bash 子代理不可用 ✗',
          detail: '当前为只读模式（Ask/Plan），只能派 explore 子代理');
    }

    final baseProfile = ref
        .read(agentProfilesProvider)
        .where((p) => p.id == parent.profileId)
        .firstOrNull;
    final childMode = type == AgentSubagentType.explore
        ? AgentSessionMode.ask
        : parent.mode;
    final childProfile = AgentProfile(
      id: parent.profileId,
      name: type == AgentSubagentType.explore ? '探索子代理' : '终端子代理',
      emoji: '🤖',
      systemPrompt: type == AgentSubagentType.explore
          ? _kExploreSubagentPrompt
          : _kBashSubagentPrompt,
      tools: type == AgentSubagentType.explore
          ? (baseProfile?.tools ?? AgentToolGroup.values.toSet())
          : {AgentToolGroup.terminal},
      workspaceId: baseProfile?.workspaceId,
      workspaceName: baseProfile?.workspaceName,
    );

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
    ref.read(agentTasksProvider.notifier).apply(child);
    await _store().appendUserMessage(childId, prompt);

    final runtime = ref.read(agentRuntimeProvider).forProfile(
          childProfile,
          mode: childMode,
          enableSubagents: false,
        );
    final engine = AgentEngine(
      llm: runtime.llm,
      tools: runtime.tools,
      approval: runtime.approval,
      store: _store(),
      gateway: _ProviderTaskGateway(this),
      budget: AgentBudget(maxRounds: 15, maxTokens: 200000),
    );
    // 取消桥接：父任务暂停/终止 → 子代理在下个安全点终止。
    final childToken = AgentCancellationToken();
    final bridge = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (cancel.stopRequested) childToken.requestCancel();
    });
    try {
      await engine.run(child, childToken);
    } finally {
      bridge.cancel();
    }

    final finalChild = ref
            .read(agentTasksProvider)
            .where((t) => t.id == childId)
            .firstOrNull ??
        child;
    final events = await _store().getEvents(childId);
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
      summary: ok
          ? '子代理完成 · ${finalChild.rounds} 轮'
          : '子代理$statusLabel ✗',
      detail: detail.isNotEmpty ? detail : '（子代理未返回结论，状态：$statusLabel）',
    );
  }

  static String _titleFrom(String text) =>
      text.length > 24 ? '${text.substring(0, 24)}…' : text;

  AgentEventStore _store() =>
      _storeInstance ??= DriftAgentEventStore(ref.read(agentDaoProvider));

  void _applyTask(AgentTask task) =>
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
  }) =>
      _runner._launchSubagent(
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
  Future<void> save(AgentTask task) async => _runner._applyTask(task);
}
