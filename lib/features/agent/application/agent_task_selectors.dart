import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_task_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 单个话题：只在该话题对象被替换时通知，其它话题的轮数/token/状态
/// 写回不会让按 id 订阅的界面重建；界面再 select 自己的字段进一步收窄。
final agentTaskProvider = Provider.autoDispose.family<AgentTask?, String>(
  (ref, taskId) => ref.watch(
    agentTasksProvider.select(
      (tasks) => tasks.where((t) => t.id == taskId).firstOrNull,
    ),
  ),
);
