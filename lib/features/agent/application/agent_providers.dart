import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart';
import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_builtin_profiles.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

part 'agent_providers.g.dart';

/// 删除工具大输出的落盘文件（删任务/回滚截断时防孤儿文件堆积）。
Future<void> deleteAgentOverflowFile(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

/// last-active 持久化键（架构稿 §三：agent 模式重启 → 恢复上次所在的
/// 智能体与话题）。
const String kLastActiveAgentProfileKey = 'agent_last_profile';
const String kLastActiveAgentTaskKey = 'agent_last_task';

/// 一次性种子数据标记：首次启动把内置预设档案写入 drift，
/// 之后一律以库为准（删光不会重新种入）。
const String kAgentSeededKey = 'agent_seeded_v1';

/// 一次性清理标记：移除 UI 先行阶段种入的演示话题，并清掉内置
/// 档案上的假工作区绑定（ws-1/ws-2 不对应任何真实工作区）。
const String kAgentMockPurgedKey = 'agent_mock_purged_v1';

/// 会话上下文长度上限（token）的持久化键。
const String kAgentContextLimitKey = 'agent_context_limit';

/// 智能体界面偏好的持久化键（执行设置/事件流显示）。
const String kAgentDefaultModeKey = 'agent_default_mode';
const String kAgentAutoCollapseKey = 'agent_auto_collapse_work_sessions';
const String kAgentFollowAiFileKey = 'agent_follow_ai_file';
const String kAgentSidebarTabIndexKey = 'agent_sidebar_tab_index';

/// 首次运行时的一次性种子写入（内置预设档案）。keepAlive 保证
/// 多个 hydrate 入口共享同一次 Future，不会重复种入。
@Riverpod(keepAlive: true)
Future<void> agentSeed(Ref ref) async {
  final store = ref.read(appSettingsStoreProvider);
  final dao = ref.read(agentDaoProvider);
  if (await store.getSetting(kAgentSeededKey) != '1') {
    for (final profile in kBuiltinAgentProfiles) {
      await dao.upsertProfile(profile);
    }
    await store.saveSetting(kAgentSeededKey, '1');
  }
  await _purgeMockData(ref);
}

/// 旧版首次启动曾种入 3 条演示话题（task-1/2/3）和带假工作区
/// 绑定（ws-1/ws-2）的内置档案；这里对已种入的安装做一次性清理。
Future<void> _purgeMockData(Ref ref) async {
  final store = ref.read(appSettingsStoreProvider);
  final dao = ref.read(agentDaoProvider);
  if (await store.getSetting(kAgentMockPurgedKey) == '1') return;
  for (final id in const ['task-1', 'task-2', 'task-3']) {
    await dao.deleteTask(id);
  }
  for (final profile in await dao.getAllProfiles()) {
    if (profile.builtin &&
        (profile.workspaceId == 'ws-1' || profile.workspaceId == 'ws-2')) {
      await dao.upsertProfile(
        profile.copyWith(workspaceId: null, workspaceName: null),
      );
    }
  }
  await store.saveSetting(kAgentMockPurgedKey, '1');
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
    final fromDb = await ref.read(agentDaoProvider).getAllProfiles();
    // hydrate 窗口内用户已增/改的档案优先，不被整表读回结果覆盖。
    final existing = state;
    state = [
      for (final p in fromDb)
        existing.where((e) => e.id == p.id).firstOrNull ?? p,
      for (final e in existing)
        if (!fromDb.any((p) => p.id == e.id)) e,
    ];
  }

  /// 新增或按 id 覆盖一个档案（编辑页保存），等待落库完成。
  Future<void> upsert(AgentProfile profile) async {
    final index = state.indexWhere((p) => p.id == profile.id);
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) profile else state[i],
      if (index < 0) profile,
    ];
    await ref.read(agentDaoProvider).upsertProfile(profile);
  }

  Future<void> remove(String profileId) async {
    state = [
      for (final p in state)
        if (p.id != profileId) p,
    ];
    await ref.read(agentDaoProvider).deleteProfile(profileId);
  }
}

/// 全部话题（drift 持久化）：冷启动从库 hydrate，重命名/删除写穿；
/// 删话题联动删其事件流（DAO 事务内完成）。
@Riverpod(keepAlive: true)
class AgentTasks extends _$AgentTasks {
  /// 已删除任务的 tombstone：引擎/后台子代理的晚到写回不能把
  /// 删掉的任务行重新插回。
  final Set<String> _removed = {};

  @override
  List<AgentTask> build() {
    _hydrate();
    return const [];
  }

  Future<void> _hydrate() async {
    await ref.read(agentSeedProvider.future);
    final dao = ref.read(agentDaoProvider);
    // 对照 tombstone：hydrate 窗口内已被删除的任务不再合并回来。
    final tasks = [
      for (final t in await dao.getAllTasks())
        if (!_removed.contains(t.id)) t,
    ];
    // 恢复语义（循环设计稿 L7）：上次进程死亡时仍 running 或
    // waitingApproval（审批注册表随进程丢失，卡片已无法响应）的任务
    // 标 paused，用户一键「继续」重放续跑；半途工具由引擎按失败回填，
    // 待审批工具续跑时由模型重新发起并重过审批。
    final recovered = [
      for (final t in tasks)
        t.status == AgentTaskStatus.running ||
                t.status == AgentTaskStatus.waitingApproval
            ? t.copyWith(
                status: AgentTaskStatus.paused,
                lastEventSummary: '进程中断，可继续',
              )
            : t,
    ];
    for (var i = 0; i < tasks.length; i++) {
      if (identical(tasks[i], recovered[i])) continue;
      // 恢复写库前重验：行仍存在、未被删除且 updatedAt 未前进
      //（引擎/用户已更新过的不覆盖）。
      if (_removed.contains(tasks[i].id)) continue;
      final row = await dao.getTask(tasks[i].id);
      if (row == null || row.updatedAt.isAfter(tasks[i].updatedAt)) continue;
      await dao.upsertTask(recovered[i]);
    }
    // hydrate 窗口内用户已创建/更新的任务优先（按 updatedAt 新者胜），
    // 不被整表读回结果覆盖。
    final existing = state;
    state = [
      for (final t in recovered)
        existing
                .where(
                  (e) => e.id == t.id && e.updatedAt.isAfter(t.updatedAt),
                )
                .firstOrNull ??
            t,
      for (final e in existing)
        if (!recovered.any((t) => t.id == e.id)) e,
    ];
  }

  /// 新增或按 id 覆盖一个话题（引擎写回/新建任务共用），写穿到库
  /// 并等待落库完成（保证状态迁移的落库顺序，失败向上抛）。
  Future<void> apply(AgentTask task) async {
    if (_removed.contains(task.id)) return;
    final index = state.indexWhere((t) => t.id == task.id);
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) task else state[i],
      if (index < 0) task,
    ];
    await ref.read(agentDaoProvider).upsertTask(task);
  }

  Future<void> rename(String taskId, String title) async {
    state = [
      for (final t in state)
        if (t.id == taskId) t.copyWith(title: title) else t,
    ];
    final renamed = state.where((t) => t.id == taskId).firstOrNull;
    if (renamed != null) {
      await ref.read(agentDaoProvider).upsertTask(renamed);
    }
  }

  /// 固定/取消固定（对齐聊天 TopicsController.togglePin），写穿到库。
  Future<void> togglePin(String taskId) async {
    state = [
      for (final t in state)
        if (t.id == taskId) t.copyWith(pinned: !t.pinned) else t,
    ];
    final toggled = state.where((t) => t.id == taskId).firstOrNull;
    if (toggled != null) {
      await ref.read(agentDaoProvider).upsertTask(toggled);
    }
  }

  /// 删话题级联删其派生的子任务（子代理隐藏话题），并清理
  /// 各自事件引用的大输出落盘文件。
  Future<void> remove(String taskId) async {
    final removedTasks = [
      for (final t in state)
        if (t.id == taskId || t.parentTaskId == taskId) t,
    ];
    final runner = ref.read(agentTaskRunnerProvider.notifier);
    for (final t in removedTasks) {
      _removed.add(t.id);
      runner.forceStop(t.id);
    }
    state = [
      for (final t in state)
        if (t.id != taskId && t.parentTaskId != taskId) t,
    ];
    for (final t in removedTasks) {
      await _deleteOverflowFilesOf(t.id);
      await cleanupAgentCheckpointRefs(
        ref,
        t.id,
        t.workspaceId.isEmpty ? null : t.workspaceId,
      );
      await ref.read(agentDaoProvider).deleteTask(t.id);
    }
  }

  /// 删除某智能体下的全部话题（删除智能体时联动）。
  Future<void> removeByProfile(String profileId) async {
    final removedTasks = [
      for (final t in state)
        if (t.profileId == profileId) t,
    ];
    final runner = ref.read(agentTaskRunnerProvider.notifier);
    for (final t in removedTasks) {
      _removed.add(t.id);
      runner.forceStop(t.id);
    }
    state = [
      for (final t in state)
        if (t.profileId != profileId) t,
    ];
    for (final t in removedTasks) {
      await _deleteOverflowFilesOf(t.id);
      await cleanupAgentCheckpointRefs(
        ref,
        t.id,
        t.workspaceId.isEmpty ? null : t.workspaceId,
      );
    }
    await ref.read(agentDaoProvider).deleteTasksByProfile(profileId);
  }

  Future<void> _deleteOverflowFilesOf(String taskId) async {
    try {
      final events = await ref.read(agentDaoProvider).getEvents(taskId);
      for (final e in events.whereType<ToolCallEvent>()) {
        await deleteAgentOverflowFile(e.resultOverflowPath);
        await deleteAgentOverflowFile(e.imagePath);
      }
    } catch (_) {}
  }
}

/// 某话题的事件流：drift 事件表实时 watch（append 即推增量）。
@riverpod
Stream<List<AgentEvent>> agentTaskEvents(Ref ref, String taskId) async* {
  await ref.watch(agentSeedProvider.future);
  yield* ref.watch(agentDaoProvider).watchEvents(taskId);
}

/// 侧边栏当前 tab（0 智能体 / 1 话题 / 2 设置）。持久化（appSettingsStore）：
/// 重开抽屉、重启 app 都保持在上次 tab。
@Riverpod(keepAlive: true)
class AgentSidebarTabIndex extends _$AgentSidebarTabIndex {
  bool _touched = false;

  @override
  int build() {
    _hydrate();
    return 0;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kAgentSidebarTabIndexKey);
    final index = int.tryParse(stored ?? '');
    if (!_touched && index != null && index >= 0 && index <= 2) {
      state = index;
    }
  }

  void set(int index) {
    if (index < 0 || index > 2) return;
    _touched = true;
    state = index;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentSidebarTabIndexKey, '$index');
  }
}

/// 智能体界面偏好（appSettingsStore 持久化，冷启动 hydrate 恢复）。
class AgentUiSettings {
  const AgentUiSettings({
    this.defaultMode = AgentSessionMode.code,
    this.autoCollapseWorkSessions = true,
    this.followAiFile = true,
    this.contextLimit = 128000,
  });

  /// 新话题的默认模式（Code/Auto/Ask/Plan）；与输入区模式 chip 同源，
  /// 草稿态切模式也写回这里（持久化）。
  final AgentSessionMode defaultMode;

  /// 工作段完成后自动折叠为摘要块（UI 稿 §4.1）。
  final bool autoCollapseWorkSessions;

  /// 右页工作台焦点 tab 跟随智能体当前活动。
  final bool followAiFile;

  /// 会话上下文长度上限（token）：用于展示已用/剩余占比，按模型
  /// 窗口自行设置（持久化）。
  final int contextLimit;

  AgentUiSettings copyWith({
    AgentSessionMode? defaultMode,
    bool? autoCollapseWorkSessions,
    bool? followAiFile,
    int? contextLimit,
  }) {
    return AgentUiSettings(
      defaultMode: defaultMode ?? this.defaultMode,
      autoCollapseWorkSessions:
          autoCollapseWorkSessions ?? this.autoCollapseWorkSessions,
      followAiFile: followAiFile ?? this.followAiFile,
      contextLimit: contextLimit ?? this.contextLimit,
    );
  }
}

@Riverpod(keepAlive: true)
class AgentUiSettingsController extends _$AgentUiSettingsController {
  /// hydrate 窗口内用户已改过的设置键：hydrate 不再用存储旧值覆盖。
  final Set<String> _touched = {};

  @override
  AgentUiSettings build() {
    _hydrate();
    return const AgentUiSettings();
  }

  Future<void> _hydrate() async {
    final store = ref.read(appSettingsStoreProvider);
    final storedLimit = await store.getSetting(kAgentContextLimitKey);
    final storedMode = await store.getSetting(kAgentDefaultModeKey);
    final storedCollapse = await store.getSetting(kAgentAutoCollapseKey);
    final storedFollow = await store.getSetting(kAgentFollowAiFileKey);

    final limit = int.tryParse(storedLimit ?? '');
    final mode = AgentSessionMode.values
        .where((m) => m.name == storedMode)
        .firstOrNull;
    state = state.copyWith(
      contextLimit: _touched.contains(kAgentContextLimitKey)
          ? null
          : (limit != null && limit > 0)
              ? limit
              : null,
      defaultMode: _touched.contains(kAgentDefaultModeKey) ? null : mode,
      autoCollapseWorkSessions: _touched.contains(kAgentAutoCollapseKey)
          ? null
          : switch (storedCollapse) {
              '1' => true,
              '0' => false,
              _ => null,
            },
      followAiFile: _touched.contains(kAgentFollowAiFileKey)
          ? null
          : switch (storedFollow) {
              '1' => true,
              '0' => false,
              _ => null,
            },
    );
  }

  void setDefaultMode(AgentSessionMode mode) {
    _touched.add(kAgentDefaultModeKey);
    state = state.copyWith(defaultMode: mode);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentDefaultModeKey, mode.name);
  }

  void setAutoCollapseWorkSessions(bool value) {
    _touched.add(kAgentAutoCollapseKey);
    state = state.copyWith(autoCollapseWorkSessions: value);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentAutoCollapseKey, value ? '1' : '0');
  }

  void setFollowAiFile(bool value) {
    _touched.add(kAgentFollowAiFileKey);
    state = state.copyWith(followAiFile: value);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentFollowAiFileKey, value ? '1' : '0');
  }

  void setContextLimit(int value) {
    if (value <= 0) return;
    _touched.add(kAgentContextLimitKey);
    state = state.copyWith(contextLimit: value);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentContextLimitKey, '$value');
  }
}

/// 当前选中的智能体档案 id；冷启动从 KV 恢复，切换写穿。
@Riverpod(keepAlive: true)
class SelectedAgentProfileId extends _$SelectedAgentProfileId {
  @override
  String build() {
    _hydrate();
    return kBuiltinAgentProfiles.first.id;
  }

  bool _userSelected = false;

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kLastActiveAgentProfileKey);
    if (_userSelected || stored == null || stored.isEmpty) return;
    // 不在这里验存在性（档案列表可能尚未 hydrate 完）；UI 侧用
    // firstOrNull 回退，档案已删时自动落到第一个/空态。
    state = stored;
  }

  void select(String id) {
    _userSelected = true;
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

  bool _userSelected = false;

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kLastActiveAgentTaskKey);
    if (stored == null || stored.isEmpty) return;
    // 先等话题列表 hydrate 完再验存在性，避免和空列表竞态误判。
    await ref.read(agentSeedProvider.future);
    final tasks = await ref.read(agentDaoProvider).getAllTasks();
    if (!_userSelected && tasks.any((t) => t.id == stored)) {
      state = stored;
    }
  }

  void select(String? id) {
    _userSelected = true;
    state = id;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kLastActiveAgentTaskKey, id ?? '');
  }
}
