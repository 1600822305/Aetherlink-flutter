import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_executor.dart';

/// 演示用假工具执行器：固定延迟后返回成功；支持被用户打断。
class FakeAgentToolExecutor implements AgentToolExecutor {
  const FakeAgentToolExecutor({
    this.delay = const Duration(milliseconds: 900),
    this.concurrencySafe = false,
  });

  final Duration delay;
  final bool concurrencySafe;

  @override
  bool isConcurrencySafe(AgentToolCallRequest call) => concurrencySafe;

  @override
  Future<AgentToolResult> execute(
    AgentToolCallRequest call,
    AgentCancellationToken cancel,
  ) async {
    const tick = Duration(milliseconds: 100);
    var waited = Duration.zero;
    while (waited < delay) {
      if (cancel.consumeToolInterrupt() || cancel.stopRequested) {
        return const AgentToolResult(ok: false, summary: '已被用户打断');
      }
      await Future<void>.delayed(tick);
      waited += tick;
    }
    return AgentToolResult(
      ok: true,
      summary: '完成 · ${delay.inMilliseconds / 1000}s（演示）',
      detail: '（演示输出）${call.name}(${call.argSummary}) 执行成功。\n'
          '接真实现时这里是 ToolRoute 分发的真实工具输出。',
    );
  }
}
