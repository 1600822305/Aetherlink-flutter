import 'package:aetherlink_flutter/features/agent/application/engine/agent_cancellation.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_llm_client.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 策略判定结果：直通 / 需要用户 / 策略硬禁止。
enum ApprovalRequirement { allow, needsUser, forbid }

/// 用户裁决（挂起无超时——初稿 §4.2：超时挂起而非拒绝）。
class ApprovalVerdict {
  const ApprovalVerdict.approved()
      : approved = true,
        reason = '';

  const ApprovalVerdict.denied(this.reason) : approved = false;

  final bool approved;
  final String reason;
}

/// 审批抽象（三层策略：工具风险分级 → 运行级策略 → 白名单，初稿 §七）。
/// 骨架期用 [AutoApprovalGate]；接真实现时复用 tool_confirmation_service
/// + 工具授权白名单。
abstract class ApprovalGate {
  Future<ApprovalRequirement> evaluate(
    AgentToolCallRequest call,
    AgentTask task,
  );

  /// [evaluate] 返回 needsUser 后挂起等用户裁决。
  Future<ApprovalVerdict> waitForVerdict(
    AgentToolCallRequest call,
    AgentTask task,
    AgentCancellationToken cancel,
  );
}

/// 全部直通（骨架期演示用）。
class AutoApprovalGate implements ApprovalGate {
  const AutoApprovalGate();

  @override
  Future<ApprovalRequirement> evaluate(
    AgentToolCallRequest call,
    AgentTask task,
  ) async =>
      ApprovalRequirement.allow;

  @override
  Future<ApprovalVerdict> waitForVerdict(
    AgentToolCallRequest call,
    AgentTask task,
    AgentCancellationToken cancel,
  ) async =>
      const ApprovalVerdict.approved();
}
