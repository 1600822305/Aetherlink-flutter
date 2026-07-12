import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_mock_data.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

part 'agent_providers.g.dart';

/// last-active 持久化键（架构稿 §三：agent 模式重启 → 恢复上次所在的
/// 智能体与话题）。
const String kLastActiveAgentProfileKey = 'agent_last_profile';
const String kLastActiveAgentTaskKey = 'agent_last_task';

/// 智能体档案列表。UI 先行阶段返回内置预设；接真实现时替换为
/// drift 读取（内置+自建）。
@Riverpod(keepAlive: true)
List<AgentProfile> agentProfiles(Ref ref) => kBuiltinAgentProfiles;

/// 全部话题（mock）。接真实现时替换为 drift 查询。
@Riverpod(keepAlive: true)
List<AgentTask> agentTasks(Ref ref) => kMockAgentTasks;

/// 某话题的事件流（mock）。接真实现时替换为 drift 事件表 watch。
@riverpod
List<AgentEvent> agentTaskEvents(Ref ref, String taskId) =>
    mockEventsForTask(taskId);

/// 当前选中的智能体档案 id；冷启动从 KV 恢复，切换写穿。
@Riverpod(keepAlive: true)
class SelectedAgentProfileId extends _$SelectedAgentProfileId {
  @override
  String build() {
    _hydrate();
    return kBuiltinAgentProfiles.first.id;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kLastActiveAgentProfileKey);
    if (stored == null || stored.isEmpty) return;
    if (kBuiltinAgentProfiles.any((p) => p.id == stored)) state = stored;
  }

  void select(String id) {
    state = id;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kLastActiveAgentProfileKey, id);
  }
}

/// 当前选中的话题 id（null = 该智能体下还没有/未选话题，主界面显示空态）；
/// 冷启动从 KV 恢复，切换写穿。
@Riverpod(keepAlive: true)
class SelectedAgentTaskId extends _$SelectedAgentTaskId {
  @override
  String? build() {
    _hydrate();
    return null;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kLastActiveAgentTaskKey);
    if (stored == null || stored.isEmpty) return;
    if (ref.read(agentTasksProvider).any((t) => t.id == stored)) {
      state = stored;
    }
  }

  void select(String? id) {
    state = id;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kLastActiveAgentTaskKey, id ?? '');
  }
}
