import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/app/di/agent_subagent_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
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
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/services/streaming_keepalive_service.dart';

/// 任务标题取自首条文本的前 24 字。
String agentTaskTitleFrom(String text) =>
    text.length > 24 ? '${text.substring(0, 24)}…' : text;

/// 子代理派发与子引擎执行（初稿 §5.5 P2，对标 Cursor）：独立事件流/
/// 预算，只把最终结论回填父任务。由 AgentTaskRunner 组装持有，
/// 运行集合/取消 token/保活等任务级状态经回调回到 runner。
class AgentSubagentRunner implements AgentSubagentLauncher {
  AgentSubagentRunner({
    required Ref ref,
    required AgentEventStore Function() store,
    required AgentTaskGateway gateway,
    required AgentBudget Function({int? maxRounds, int? maxTokens})
    budgetFromSettings,
    required AgentHookTimelineSink Function(String taskId) hookTimelineFor,
    required AgentHookRewakeSink Function(String taskId) hookRewakeFor,
    required void Function(String taskId, AgentCancellationToken token)
    onBackgroundChildStarted,
    required void Function(String taskId) onBackgroundChildFinished,
  }) : _ref = ref,
       _store = store,
       _gateway = gateway,
       _budgetFromSettings = budgetFromSettings,
       _hookTimelineFor = hookTimelineFor,
       _hookRewakeFor = hookRewakeFor,
       _onBackgroundChildStarted = onBackgroundChildStarted,
       _onBackgroundChildFinished = onBackgroundChildFinished;

  final Ref _ref;
  final AgentEventStore Function() _store;
  final AgentTaskGateway _gateway;
  final AgentBudget Function({int? maxRounds, int? maxTokens})
  _budgetFromSettings;
  final AgentHookTimelineSink Function(String taskId) _hookTimelineFor;
  final AgentHookRewakeSink Function(String taskId) _hookRewakeFor;
  final void Function(String taskId, AgentCancellationToken token)
  _onBackgroundChildStarted;
  final void Function(String taskId) _onBackgroundChildFinished;

  /// 子代理专属提示（系统提示第 3 层）：强调独立上下文 + 结论自包含。
  static const String _kExploreSubagentPrompt =
      '你是一个探索子代理：在独立上下文里完成父任务派发的只读调研/搜索子任务。'
      '你看不到父任务的对话，指令里的信息就是全部上下文。完成时先把结论作为'
      '正文完整输出再调用 finish_task：结论是父任务唯一能看到的内容，必须自包含'
      '（关键发现、文件路径、结论依据），不要只说“已完成”。不要用 ask_user 提问。';

  static const String _kBashSubagentPrompt =
      '你是一个终端子代理：在独立上下文里执行父任务派发的命令型子任务。'
      '你看不到父任务的对话，指令里的信息就是全部上下文。完成后用 finish_task '
      '返回结论：提炼关键输出和结论，不要长篇粘贴原始输出。不要用 ask_user 提问。';

  /// 自定义档案子代理的通用后缀（拼在档案正文之后）。
  static const String _kCustomSubagentSuffix =
      '你是一个子代理，在独立上下文里完成父任务派发的子任务：'
      '你看不到父任务的对话，指令里的信息就是全部上下文。完成后用 finish_task '
      '返回自包含的结论（父任务只能看到结论）。不要用 ask_user 提问。';

  /// fork 分身子代理（对标 Claude Code fork）：首条消息带父对话摘录。
  static const String _kForkSubagentPrompt =
      '你是主任务的一个分身子代理：首条消息里的「父任务对话摘录」是你与'
      '主任务共享的背景，指令在摘录之后——直接按指令干活，不要重新调研背景。'
      '完成时先把结论作为正文完整输出再调用 finish_task：结论是父任务唯一'
      '能看到的内容，必须自包含。不要用 ask_user 提问。';

  /// 派生一个子代理（初稿 §5.5 P2，对标 Cursor）：独立事件流/预算，
  /// 只把最终结论回填父任务；bash / 非只读档案的工具调用仍走现有
  /// 审批链（auto 模式工作区内照常免审）。type 为内置 explore/bash
  /// 或自定义档案名（工作区 .aetherlink/agents、.cursor/agents 的
  /// markdown 定义）。background=true 时立即返回不阻塞父循环，完成后
  /// 结论回填原工具事件并以排队消息注入父对话。
  @override
  Future<AgentToolResult> launch({
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
    final baseProfile = _ref
        .read(agentProfilesProvider)
        .where((p) => p.id == parent.profileId)
        .firstOrNull;

    final builtin = AgentSubagentType.values
        .where((t) => t.name == typeName)
        .firstOrNull;
    final AgentSessionMode childMode;
    final AgentProfile childProfile;
    Model? childModel;
    int? childMaxTurns;
    var childPrompt = prompt;
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
        name: switch (builtin) {
          AgentSubagentType.explore => '探索子代理',
          AgentSubagentType.bash => '终端子代理',
          AgentSubagentType.fork => '分身子代理',
        },
        emoji: '🤖',
        systemPrompt: switch (builtin) {
          AgentSubagentType.explore => _kExploreSubagentPrompt,
          AgentSubagentType.bash => _kBashSubagentPrompt,
          AgentSubagentType.fork => _kForkSubagentPrompt,
        },
        tools: builtin == AgentSubagentType.bash
            ? {AgentToolGroup.terminal}
            : (baseProfile?.tools ?? AgentToolGroup.values.toSet()),
        workspaceId: baseProfile?.workspaceId,
        workspaceName: baseProfile?.workspaceName,
      );
      // fork 继承父对话：把父事件流摘录拼在指令前，prompt 只需指令。
      if (builtin == AgentSubagentType.fork) {
        final parentEvents = await _store().getEvents(parent.id);
        final context = buildSubagentForkContext(parentEvents);
        if (context.isNotEmpty) {
          childPrompt = '[父任务对话摘录]\n$context\n\n[指令]\n$prompt';
        }
      }
    } else {
      List<AgentSubagentProfile> customs;
      try {
        customs = await loadCustomSubagentProfiles(
          _ref,
          parent.workspaceId.isEmpty ? null : parent.workspaceId,
        );
      } catch (_) {
        customs = const [];
      }
      final custom = customs.where((p) => p.name == typeName).firstOrNull;
      if (custom == null) {
        final names = [
          for (final t in AgentSubagentType.values) t.name,
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
      // frontmatter tools 白名单：限定工具分组（无效名字忽略，
      // 全部无效/未声明时继承父档案）。
      final whitelisted = {
        for (final g in AgentToolGroup.values)
          if (custom.tools.contains(g.name)) g,
      };
      // frontmatter memory：注入持久记忆文件内容；非只读档案可用
      // 文件工具回写记忆（路径已给出）。
      var memorySection = '';
      if (custom.memory) {
        try {
          final mem = await readSubagentMemory(
            _ref,
            parent.workspaceId.isEmpty ? null : parent.workspaceId,
            custom.name,
          );
          if (mem != null) {
            memorySection =
                '\n\n[持久记忆]（文件：${mem.path}）\n'
                '${mem.content?.trim().isNotEmpty == true ? mem.content!.trim() : '（暂无记忆，首次运行）'}'
                '${custom.readonly ? '' : '\n任务中学到的可复用经验（坑、约定、关键路径）请用文件工具更新到上述记忆文件，保持精炼。'}';
          }
        } catch (_) {}
      }
      childProfile = AgentProfile(
        id: parent.profileId,
        name: custom.name,
        emoji: '🤖',
        systemPrompt:
            (custom.systemPrompt.isEmpty
                ? _kCustomSubagentSuffix
                : '${custom.systemPrompt}\n\n$_kCustomSubagentSuffix') +
            memorySection,
        tools: whitelisted.isNotEmpty
            ? whitelisted
            : (baseProfile?.tools ?? AgentToolGroup.values.toSet()),
        workspaceId: baseProfile?.workspaceId,
        workspaceName: baseProfile?.workspaceName,
      );
      childMaxTurns = custom.maxTurns;
      // frontmatter model：按 id/显示名匹配已配置模型；匹不上时
      // 静默回退父任务当前模型（不阻断派发）。
      if (custom.model.isNotEmpty) {
        try {
          final providers = await _ref.read(appModelProvidersProvider.future);
          final found = findModelNamed(providers, custom.model);
          if (found != null) childModel = effectiveModelFor(found);
        } catch (_) {}
      }
    }

    final now = DateTime.now();
    final childId = subagentTaskIdFor(toolEventId);
    final child = AgentTask(
      id: childId,
      profileId: parent.profileId,
      title: description.isNotEmpty ? description : agentTaskTitleFrom(prompt),
      workspaceId: parent.workspaceId,
      workspaceName: parent.workspaceName,
      status: AgentTaskStatus.running,
      mode: childMode,
      createdAt: now,
      updatedAt: now,
      modelLabel: childModel?.name ?? parent.modelLabel,
      lastEventSummary: prompt,
      parentTaskId: parent.id,
    );
    await _ref.read(agentTasksProvider.notifier).apply(child);
    await _store().appendUserMessage(childId, childPrompt);

    if (background) {
      unawaited(
        _runBackgroundSubagent(
          parent: parent,
          child: child,
          childProfile: childProfile,
          childMode: childMode,
          toolEventId: toolEventId,
          childModel: childModel,
          childMaxTurns: childMaxTurns,
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
        childModel: childModel,
        childMaxTurns: childMaxTurns,
      );
    } finally {
      cancel.removeListener(bridge);
    }
  }

  /// 后台子代理：不桥接父取消（父暂停/终止后照常跑完），token 挂
  /// runner 的运行集合可单独停；完成后结论回填父工具事件 + 排队消息
  /// 在父任务下个安全点注入（父已收尾则等用户续跑时消费）。
  Future<void> _runBackgroundSubagent({
    required AgentTask parent,
    required AgentTask child,
    required AgentProfile childProfile,
    required AgentSessionMode childMode,
    required String toolEventId,
    Model? childModel,
    int? childMaxTurns,
  }) async {
    final token = AgentCancellationToken();
    _onBackgroundChildStarted(child.id, token);
    unawaited(
      StreamingKeepAliveService.acquire(
        'agent',
        title: '智能体任务运行中…',
        text: 'AetherLink 在后台继续执行任务，需要授权时会通知你',
      ),
    );
    try {
      final result = await _runChildEngine(
        child: child,
        childProfile: childProfile,
        childMode: childMode,
        childToken: token,
        childModel: childModel,
        childMaxTurns: childMaxTurns,
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
        await _ref
            .read(agentTasksProvider.notifier)
            .apply(
              child.copyWith(
                status: AgentTaskStatus.failed,
                updatedAt: DateTime.now(),
                lastEventSummary: '执行出错：$e',
              ),
            );
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
      _onBackgroundChildFinished(child.id);
    }
  }

  /// 跑子引擎（独立运行时/预算，不再暴露 spawn_subagent 防嵌套），
  /// 从子任务终态提取结论组装父工具结果。
  Future<AgentToolResult> _runChildEngine({
    required AgentTask child,
    required AgentProfile childProfile,
    required AgentSessionMode childMode,
    required AgentCancellationToken childToken,
    Model? childModel,
    int? childMaxTurns,
  }) async {
    final runtime = await _ref
        .read(agentRuntimeProvider)
        .forProfile(
          childProfile,
          mode: childMode,
          enableSubagents: false,
          boundWorkspaceId: child.workspaceId,
          modelOverride: childModel,
        );
    runtime.setHookTimeline(_hookTimelineFor(child.id));
    runtime.setHookRewake(_hookRewakeFor(child.id));
    // subagentStart hooks：子智能体启动时触发，fire-and-forget 不阻断；
    // 收尾校验用 subagentStop hooks（而非主任务的 stop）。
    unawaited(runtime.lifecycleHooks(AgentHookEvent.subagentStart));
    final engine = AgentEngine(
      llm: runtime.llm,
      tools: runtime.tools,
      approval: runtime.approval,
      store: _store(),
      gateway: _gateway,
      // 档案 maxTurns 覆盖默认轮数预算（限 1~100 防失控）。
      budget: _budgetFromSettings(
        maxRounds: childMaxTurns?.clamp(1, 100) ?? 15,
        maxTokens: 200000,
      ),
      toolStream: _ref.read(agentToolStreamProvider.notifier),
      stopGuard: runtime.subagentStopGuard,
      hookStopSignal: runtime.hookStopSignal,
    );
    await engine.run(child, childToken);

    final finalChild =
        _ref
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
}
