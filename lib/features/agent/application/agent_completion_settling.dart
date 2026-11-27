// 完成卡片「已定稿、后台收尾中」：attempt_completion 参数已流完（结果确定），
// 引擎还在落库 / 跑 stop hook / 迁移状态。此期间 UI 视同任务已完成
// （卡片显示「任务完成」、输入栏切回发送态），用户无感。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_tool_stream.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/loop/finish_result_streamer.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

/// 只看尾部这么多条事件找仍 running 的完成卡片（卡片总在最后几条）。
const int _kTailScan = 20;

final agentCompletionSettlingProvider = Provider.autoDispose
    .family<bool, String>((ref, taskId) {
      final card = ref.watch(
        agentTaskEventsProvider(taskId).select((a) {
          final events = a.value;
          if (events == null) return null;
          final stop = events.length > _kTailScan
              ? events.length - _kTailScan
              : 0;
          for (var i = events.length - 1; i >= stop; i--) {
            final e = events[i];
            if (e is ToolCallEvent &&
                e.toolName == kToolAttemptCompletion &&
                e.state == AgentToolCallState.running) {
              return e;
            }
          }
          return null;
        }),
      );
      if (card == null) return false;
      final live = ref.watch(
        agentToolStreamProvider.select((m) => m[card.id]?.argsText),
      );
      return completionArgsFinal(live ?? card.argsDetail);
    });
