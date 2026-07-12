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

/// 智能体档案列表。UI 先行阶段为内置预设 + 会话内可编辑/新建
/// （编辑页写这里，重启丢失）；接真实现时替换为 drift 读取与写入。
@Riverpod(keepAlive: true)
class AgentProfiles extends _$AgentProfiles {
  @override
  List<AgentProfile> build() => kBuiltinAgentProfiles;

  /// 新增或按 id 覆盖一个档案（编辑页保存）。
  void upsert(AgentProfile profile) {
    final index = state.indexWhere((p) => p.id == profile.id);
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) profile else state[i],
      if (index < 0) profile,
    ];
  }
}

/// 全部话题。UI 先行阶段为 mock 数据 + 会话内重命名/删除；
/// 接真实现时替换为 drift 查询与写入。
@Riverpod(keepAlive: true)
class AgentTasks extends _$AgentTasks {
  @override
  List<AgentTask> build() => kMockAgentTasks;

  void rename(String taskId, String title) {
    state = [
      for (final t in state)
        if (t.id == taskId) t.copyWith(title: title) else t,
    ];
  }

  void remove(String taskId) {
    state = [
      for (final t in state)
        if (t.id != taskId) t,
    ];
  }
}

/// 某话题的事件流（mock）。接真实现时替换为 drift 事件表 watch。
@riverpod
List<AgentEvent> agentTaskEvents(Ref ref, String taskId) =>
    mockEventsForTask(taskId);

/// 侧边栏当前 tab（0 智能体 / 1 话题 / 2 设置）。与聊天侧边栏同款策略：
/// 仅会话内记忆（内存态）——重开抽屉保持在上次 tab，重启回默认智能体 tab。
@Riverpod(keepAlive: true)
class AgentSidebarTabIndex extends _$AgentSidebarTabIndex {
  @override
  int build() => 0;

  void set(int index) {
    if (index < 0 || index > 2) return;
    state = index;
  }
}

/// 智能体界面偏好（UI 先行阶段：会话内记忆；接真实现时走
/// appSettingsStore 持久化）。
class AgentUiSettings {
  const AgentUiSettings({
    this.defaultMode = AgentSessionMode.code,
    this.autoCollapseWorkSessions = true,
    this.followAiFile = true,
  });

  /// 新话题的默认模式（Code/Ask/Plan）。
  final AgentSessionMode defaultMode;

  /// 工作段完成后自动折叠为摘要块（UI 稿 §4.1）。
  final bool autoCollapseWorkSessions;

  /// 右页工作台焦点 tab 跟随智能体当前活动。
  final bool followAiFile;

  AgentUiSettings copyWith({
    AgentSessionMode? defaultMode,
    bool? autoCollapseWorkSessions,
    bool? followAiFile,
  }) {
    return AgentUiSettings(
      defaultMode: defaultMode ?? this.defaultMode,
      autoCollapseWorkSessions:
          autoCollapseWorkSessions ?? this.autoCollapseWorkSessions,
      followAiFile: followAiFile ?? this.followAiFile,
    );
  }
}

@Riverpod(keepAlive: true)
class AgentUiSettingsController extends _$AgentUiSettingsController {
  @override
  AgentUiSettings build() => const AgentUiSettings();

  void setDefaultMode(AgentSessionMode mode) =>
      state = state.copyWith(defaultMode: mode);

  void setAutoCollapseWorkSessions(bool value) =>
      state = state.copyWith(autoCollapseWorkSessions: value);

  void setFollowAiFile(bool value) =>
      state = state.copyWith(followAiFile: value);
}

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
