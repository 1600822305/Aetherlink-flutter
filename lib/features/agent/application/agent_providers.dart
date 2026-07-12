import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
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

/// 一次性种子数据标记：首次启动把内置预设档案 + 演示话题/事件流写入
/// drift，之后一律以库为准（删光不会重新种入）。
const String kAgentSeededKey = 'agent_seeded_v1';

/// 首次运行时的一次性种子写入（档案/话题/事件三表）。keepAlive 保证
/// 多个 hydrate 入口共享同一次 Future，不会重复种入。
@Riverpod(keepAlive: true)
Future<void> agentSeed(Ref ref) async {
  final store = ref.read(appSettingsStoreProvider);
  if (await store.getSetting(kAgentSeededKey) == '1') return;
  final dao = ref.read(agentDaoProvider);
  for (final profile in kBuiltinAgentProfiles) {
    await dao.upsertProfile(profile);
  }
  for (final task in kMockAgentTasks) {
    await dao.upsertTask(task);
    await dao.upsertEvents(task.id, mockEventsForTask(task.id));
  }
  await store.saveSetting(kAgentSeededKey, '1');
}

/// 智能体档案列表（drift 持久化）：冷启动从库 hydrate，增删改写穿。
@Riverpod(keepAlive: true)
class AgentProfiles extends _$AgentProfiles {
  @override
  List<AgentProfile> build() {
    _hydrate();
    return const [];
  }

  Future<void> _hydrate() async {
    await ref.read(agentSeedProvider.future);
    state = await ref.read(agentDaoProvider).getAllProfiles();
  }

  /// 新增或按 id 覆盖一个档案（编辑页保存）。
  void upsert(AgentProfile profile) {
    final index = state.indexWhere((p) => p.id == profile.id);
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) profile else state[i],
      if (index < 0) profile,
    ];
    ref.read(agentDaoProvider).upsertProfile(profile);
  }

  void remove(String profileId) {
    state = [
      for (final p in state)
        if (p.id != profileId) p,
    ];
    ref.read(agentDaoProvider).deleteProfile(profileId);
  }
}

/// 全部话题（drift 持久化）：冷启动从库 hydrate，重命名/删除写穿；
/// 删话题联动删其事件流（DAO 事务内完成）。
@Riverpod(keepAlive: true)
class AgentTasks extends _$AgentTasks {
  @override
  List<AgentTask> build() {
    _hydrate();
    return const [];
  }

  Future<void> _hydrate() async {
    await ref.read(agentSeedProvider.future);
    state = await ref.read(agentDaoProvider).getAllTasks();
  }

  void rename(String taskId, String title) {
    state = [
      for (final t in state)
        if (t.id == taskId) t.copyWith(title: title) else t,
    ];
    final renamed = state.where((t) => t.id == taskId).firstOrNull;
    if (renamed != null) {
      ref.read(agentDaoProvider).upsertTask(renamed);
    }
  }

  void remove(String taskId) {
    state = [
      for (final t in state)
        if (t.id != taskId) t,
    ];
    ref.read(agentDaoProvider).deleteTask(taskId);
  }

  /// 删除某智能体下的全部话题（删除智能体时联动）。
  void removeByProfile(String profileId) {
    state = [
      for (final t in state)
        if (t.profileId != profileId) t,
    ];
    ref.read(agentDaoProvider).deleteTasksByProfile(profileId);
  }
}

/// 某话题的事件流：drift 事件表实时 watch（append 即推增量）。
@riverpod
Stream<List<AgentEvent>> agentTaskEvents(Ref ref, String taskId) async* {
  await ref.watch(agentSeedProvider.future);
  yield* ref.watch(agentDaoProvider).watchEvents(taskId);
}

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
    // 不在这里验存在性（档案列表可能尚未 hydrate 完）；UI 侧用
    // firstOrNull 回退，档案已删时自动落到第一个/空态。
    state = stored;
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
    // 先等话题列表 hydrate 完再验存在性，避免和空列表竞态误判。
    await ref.read(agentSeedProvider.future);
    final tasks = await ref.read(agentDaoProvider).getAllTasks();
    if (tasks.any((t) => t.id == stored)) {
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
