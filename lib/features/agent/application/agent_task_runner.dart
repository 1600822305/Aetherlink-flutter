import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_budget.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/approval_gate.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/fakes/fake_agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/fakes/fake_agent_tool_executor.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

part 'agent_task_runner.g.dart';

/// 任务执行编排：组装引擎依赖、持有每任务的取消 token、
/// 把引擎的任务写回同步到 [AgentTasks]。
/// 骨架期（落地顺序 ①）注入假 LLM/假工具/直通审批，管道全真。
@Riverpod(keepAlive: true)
class AgentTaskRunner extends _$AgentTaskRunner {
  final Map<String, AgentCancellationToken> _tokens = {};

  /// 共享单例：seq 缓存在 store 内，多入口（引擎/插队消息）必须同一份。
  AgentEventStore? _storeInstance;

  /// 正在运行的任务 id 集合（UI 可 watch）。
  @override
  Set<String> build() => const {};

  /// 草稿态发第一条消息：创建任务 + 落用户消息 + 启动引擎。
  Future<AgentTask> startNewTask({
    required AgentProfile profile,
    required String text,
    required AgentSessionMode mode,
  }) async {
    final now = DateTime.now();
    final task = AgentTask(
      id: 'task-${now.millisecondsSinceEpoch}',
      profileId: profile.id,
      title: text.length > 24 ? '${text.substring(0, 24)}…' : text,
      workspaceId: profile.workspaceId ?? '',
      workspaceName: profile.workspaceName ?? '未绑定工作区',
      status: AgentTaskStatus.running,
      mode: mode,
      createdAt: now,
      updatedAt: now,
      modelLabel: 'GLM-4.6',
      lastEventSummary: text,
    );
    ref.read(agentTasksProvider.notifier).apply(task);
    await _store().appendUserMessage(task.id, text);
    _run(task);
    return task;
  }

  /// 给已有任务发消息：执行中排队注入（L3），非执行中落消息并续跑。
  Future<void> sendMessage(
    AgentTask task,
    String text, {
    bool queued = false,
  }) async {
    await _store().appendUserMessage(task.id, text, queued: queued);
    if (!queued) {
      final updated = task.copyWith(
        status: AgentTaskStatus.running,
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

  void pause(String taskId) => _tokens[taskId]?.requestPause();

  void forceStop(String taskId) => _tokens[taskId]?.requestCancel();

  void _run(AgentTask task) {
    if (state.contains(task.id)) return;
    final token = AgentCancellationToken();
    _tokens[task.id] = token;
    state = {...state, task.id};

    final engine = AgentEngine(
      llm: const FakeAgentLlmClient(),
      tools: const FakeAgentToolExecutor(),
      approval: const AutoApprovalGate(),
      store: _store(),
      gateway: _ProviderTaskGateway(this),
      budget: AgentBudget(),
    );
    engine.run(task, token).whenComplete(() {
      _tokens.remove(task.id);
      state = {
        for (final id in state)
          if (id != task.id) id,
      };
    });
  }

  AgentEventStore _store() =>
      _storeInstance ??= DriftAgentEventStore(ref.read(agentDaoProvider));

  void _applyTask(AgentTask task) =>
      ref.read(agentTasksProvider.notifier).apply(task);
}

class _ProviderTaskGateway implements AgentTaskGateway {
  _ProviderTaskGateway(this._runner);

  final AgentTaskRunner _runner;

  @override
  Future<void> save(AgentTask task) async => _runner._applyTask(task);
}
