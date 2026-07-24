import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_event_store.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 任务状态迁移样板：写回 gateway 并持有最新任务快照；
/// transition 同时落 StatusChangeEvent（状态迁移全部出状态行）。
class TaskTransitions {
  TaskTransitions({
    required this.store,
    required this.gateway,
    required AgentTask initial,
  }) : current = initial;

  final AgentEventStore store;
  final AgentTaskGateway gateway;

  AgentTask current;

  Future<AgentTask> save(AgentTask next) async {
    await gateway.save(next);
    return current = next;
  }

  Future<AgentTask> transition(
    AgentTaskStatus status,
    String description,
  ) async {
    await store.appendStatusChange(current.id, description);
    return save(
      current.copyWith(
        status: status,
        updatedAt: DateTime.now(),
        lastEventSummary: description,
      ),
    );
  }
}
