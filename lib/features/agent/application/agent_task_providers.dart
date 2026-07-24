import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/agent_checkpoint_access.dart';
import 'package:aetherlink_flutter/app/di/agent_data_access.dart';
import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_seed_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_runner.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

part 'agent_task_providers.g.dart';

/// 删除工具大输出的落盘文件（删任务/回滚截断时防孤儿文件堆积）。
Future<void> deleteAgentOverflowFile(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

/// last-active 持久化键（架构稿 §三：agent 模式重启 → 恢复上次所在的
/// 话题）。
const String kLastActiveAgentTaskKey = 'agent_last_task';

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
                .where((e) => e.id == t.id && e.updatedAt.isAfter(t.updatedAt))
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

  /// 切换话题绑定的工作区（编辑话题入口），写穿到库。任务活跃期间
  /// 由 UI 侧拦截，不在此处重复判断。
  Future<void> updateWorkspace(
    String taskId,
    String workspaceId,
    String workspaceName,
  ) async {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(workspaceId: workspaceId, workspaceName: workspaceName)
        else
          t,
    ];
    final updated = state.where((t) => t.id == taskId).firstOrNull;
    if (updated != null) {
      await ref.read(agentDaoProvider).upsertTask(updated);
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
