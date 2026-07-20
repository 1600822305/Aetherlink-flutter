/// 压缩进行中状态（按话题）：事件流实况行的数据源。
/// - queued：任务运行中，等下一个安全点（可取消 = 撤单）；
/// - summarizing：正在生成摘要（手动空闲路径可取消 = 丢弃结果不落库；
///   引擎安全点路径不可取消，LLM 调用无法中途安全撤回）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AgentCompactionPhase { queued, summarizing }

class AgentCompactionRun {
  const AgentCompactionRun({required this.phase, required this.cancellable});

  final AgentCompactionPhase phase;
  final bool cancellable;
}

final agentCompactionProgressProvider = NotifierProvider<
    AgentCompactionProgressNotifier,
    Map<String, AgentCompactionRun>>(AgentCompactionProgressNotifier.new);

class AgentCompactionProgressNotifier
    extends Notifier<Map<String, AgentCompactionRun>> {
  final Set<String> _cancelRequested = {};

  @override
  Map<String, AgentCompactionRun> build() => const {};

  void start(
    String taskId, {
    required AgentCompactionPhase phase,
    required bool cancellable,
  }) {
    _cancelRequested.remove(taskId);
    state = {
      ...state,
      taskId: AgentCompactionRun(phase: phase, cancellable: cancellable),
    };
  }

  void finish(String taskId) {
    _cancelRequested.remove(taskId);
    if (!state.containsKey(taskId)) return;
    state = {
      for (final e in state.entries)
        if (e.key != taskId) e.key: e.value,
    };
  }

  /// 摘要生成中的协作式取消：置标记，生成完成后丢弃结果不落库。
  void requestCancel(String taskId) => _cancelRequested.add(taskId);

  bool isCancelRequested(String taskId) => _cancelRequested.contains(taskId);
}
