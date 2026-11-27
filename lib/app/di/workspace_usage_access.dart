import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_profile_providers.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_task_providers.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';

/// 工作区被其他功能引用的情况，以及「移除工作区」时的连带解绑。
///
/// workspace feature 不得 import agent / settings 的 application 层（架构测试
/// 硬约束），所以引用统计与解绑都经 composition root 暴露。
///
/// 引用方：
/// - 智能体档案 `AgentProfile.workspaceId`（可空）——新建话题的默认工作区；
/// - 智能体话题 `AgentTask.workspaceId`（必填）——历史记录，不改写；
/// - MCP 服务器 `McpServer.workspaceId`（可空）——stdio 服务器的运行环境。
class WorkspaceUsage {
  const WorkspaceUsage({
    this.profileNames = const [],
    this.mcpServerNames = const [],
    this.taskCount = 0,
    this.activeTaskCount = 0,
  });

  /// 绑定了该工作区的智能体档案名。
  final List<String> profileNames;

  /// 以该工作区为运行环境的 MCP 服务器名。
  final List<String> mcpServerNames;

  /// 归属该工作区的智能体话题数。
  final int taskCount;

  /// 其中进行中（running / 待审批 / 待输入 / 暂停）的话题数。
  final int activeTaskCount;

  bool get isEmpty =>
      profileNames.isEmpty && mcpServerNames.isEmpty && taskCount == 0;
}

/// workspaceId → [WorkspaceUsage]；未被引用的工作区不在表里。
final workspaceUsageProvider = Provider<Map<String, WorkspaceUsage>>((ref) {
  final profiles = ref.watch(agentProfilesProvider);
  final tasks = ref.watch(agentTasksProvider);
  final servers = ref.watch(mcpServersProvider).value ?? const [];

  final profileNames = <String, List<String>>{};
  for (final p in profiles) {
    final id = p.workspaceId;
    if (id == null || id.isEmpty) continue;
    (profileNames[id] ??= []).add(p.name.isEmpty ? '未命名智能体' : p.name);
  }
  final serverNames = <String, List<String>>{};
  for (final s in servers) {
    final id = s.workspaceId?.trim();
    if (id == null || id.isEmpty) continue;
    (serverNames[id] ??= []).add(s.name);
  }
  final total = <String, int>{};
  final active = <String, int>{};
  for (final t in tasks) {
    final id = t.workspaceId;
    if (id.isEmpty) continue;
    total[id] = (total[id] ?? 0) + 1;
    if (t.isActive) active[id] = (active[id] ?? 0) + 1;
  }

  return {
    for (final id in {
      ...profileNames.keys,
      ...serverNames.keys,
      ...total.keys,
    })
      id: WorkspaceUsage(
        profileNames: profileNames[id] ?? const [],
        mcpServerNames: serverNames[id] ?? const [],
        taskCount: total[id] ?? 0,
        activeTaskCount: active[id] ?? 0,
      ),
  };
});

/// 「移除工作区」的唯一入口：从列表移除并解除引用，避免悬空 id。
///
/// - 智能体档案：清空 workspaceId / workspaceName，新建话题回到「未绑定」
///   （不会再把失效 id 复制进新话题）；
/// - MCP 服务器：清空 workspaceId 并停用（stdio 服务器没有运行环境无法启动，
///   保持启用只会在每次连接时报错）；
/// - 话题：保留原 workspaceId 作为历史，不改写；引擎与工具对找不到的绑定
///   一律报错 / 跳过，不再回退到当前工作区（见 resolveAgentWorkspace）。
final workspaceRemovalProvider = Provider<WorkspaceRemoval>(
  WorkspaceRemoval.new,
);

class WorkspaceRemoval {
  WorkspaceRemoval(this._ref);

  final Ref _ref;

  Future<void> remove(String workspaceId) async {
    await _ref.read(workspaceStoreProvider.notifier).remove(workspaceId);
    await _detach({workspaceId});
  }

  Future<void> clearAll() async {
    final ids = {
      for (final w in await _ref.read(workspaceStoreProvider.future)) w.id,
    };
    await _ref.read(workspaceStoreProvider.notifier).clear();
    await _detach(ids);
  }

  Future<void> _detach(Set<String> ids) async {
    if (ids.isEmpty) return;

    // 关掉被移除工作区的终端会话：否则 SSH / PRoot 进程与后台命令
    // 要残留到空闲回收（有视图接入时甚至不回收）。
    final pools = _ref.read(workspaceSessionPoolManagerProvider);
    for (final id in ids) {
      try {
        await pools.closeWorkspace(id);
      } catch (_) {}
    }

    final profiles = _ref.read(agentProfilesProvider.notifier);
    for (final p in _ref.read(agentProfilesProvider)) {
      if (p.workspaceId == null || !ids.contains(p.workspaceId)) continue;
      await profiles.upsert(p.copyWith(workspaceId: null, workspaceName: null));
    }

    final servers = _ref.read(mcpServersProvider.notifier);
    final current = await _ref.read(mcpServersProvider.future);
    for (final s in current) {
      final id = s.workspaceId?.trim();
      if (id == null || !ids.contains(id)) continue;
      await servers.edit(s.copyWith(workspaceId: null));
      if (s.isActive) await servers.toggleActive(s.id, isActive: false);
    }
  }
}
