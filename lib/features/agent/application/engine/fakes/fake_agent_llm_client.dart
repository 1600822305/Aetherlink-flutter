import 'dart:convert';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 演示用假 LLM（接真模型前跑通状态机/落库/流式管道）：
/// 第 1 轮出计划 + 读文件；第 2 轮更新计划 + finish_task。
class FakeAgentLlmClient implements AgentLlmClient {
  const FakeAgentLlmClient({this.chunkDelay = const Duration(milliseconds: 60)});

  final Duration chunkDelay;

  @override
  Future<AgentLlmTurn> completeTurn(
    AgentLlmContext context, {
    void Function(String textSoFar)? onTextDelta,
    void Function(String reasoningSoFar)? onReasoningDelta,
    AgentCancellationToken? cancel,
  }) async {
    final hasToolResult = context.events.any(
      (e) => e is ToolCallEvent && e.state == AgentToolCallState.success,
    );

    if (!hasToolResult) {
      const reasoning = '用户想了解项目现状。先读入口文件确认结构，再更新计划逐步推进。';
      await _streamText(reasoning, onReasoningDelta, cancel);
      const text = '收到任务。我先读取工作区文件了解现状，然后按计划推进。'
          '（演示引擎：假模型/假工具，仅验证循环与落库）';
      await _streamText(text, onTextDelta, cancel);
      return AgentLlmTurn(
        text: text,
        tokensUsed: 120,
        toolCalls: [
          AgentToolCallRequest(
            id: 'call-plan-1',
            name: kToolUpdatePlan,
            argsJson: jsonEncode({
              'items': [
                {'content': '读取相关文件了解现状', 'status': 'in_progress'},
                {'content': '完成任务并汇报', 'status': 'pending'},
              ],
            }),
            argSummary: '2 项计划',
          ),
          AgentToolCallRequest(
            id: 'call-read-1',
            name: 'read_file',
            argsJson: jsonEncode({'path': 'lib/main.dart'}),
            argSummary: 'lib/main.dart',
          ),
        ],
      );
    }

    const text = '文件已读取，演示流程完成。事件流、状态机与持久化管道均已跑通。';
    await _streamText(text, onTextDelta, cancel);
    return AgentLlmTurn(
      text: text,
      tokensUsed: 80,
      toolCalls: [
        AgentToolCallRequest(
          id: 'call-plan-2',
          name: kToolUpdatePlan,
          argsJson: jsonEncode({
            'items': [
              {'content': '读取相关文件了解现状', 'status': 'completed'},
              {'content': '完成任务并汇报', 'status': 'completed'},
            ],
          }),
          argSummary: '2 项计划',
        ),
        AgentToolCallRequest(
          id: 'call-finish-1',
          name: kToolFinishTask,
          argsJson: jsonEncode({'summary': '演示任务完成：循环/事件流/落库已验证'}),
          argSummary: '收尾',
        ),
      ],
    );
  }

  @override
  Future<String> summarizeForCompaction(
    AgentTask task,
    List<AgentEvent> events,
  ) async =>
      '（演示摘要）已压缩 ${events.length} 条早期事件。';

  Future<void> _streamText(
    String text,
    void Function(String textSoFar)? onTextDelta,
    AgentCancellationToken? cancel,
  ) async {
    if (onTextDelta == null) return;
    const step = 6;
    for (var i = step; i < text.length; i += step) {
      if (cancel?.stopRequested ?? false) break;
      onTextDelta(text.substring(0, i));
      await Future<void>.delayed(chunkDelay);
    }
    onTextDelta(text);
  }
}
