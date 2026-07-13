import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';

export 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart'
    show PooledWorkspaceSession, WorkspaceSessionPoolManager;

/// 智能体工作台「终端」tab 的组合 seam（import-boundary Rule 3：agent
/// 不得直接 import workspace 的 application——AI 会话池经 composition
/// root 暴露）。会话生命周期归会话池 / AI 管，工作台只围观 / 接管输入。
final agentSessionPoolManagerProvider = Provider<WorkspaceSessionPoolManager>(
  (ref) => ref.watch(workspaceSessionPoolManagerProvider),
);

/// 任务绑定工作区 [workspaceId] 下存活的 AI 会话（任务一律绑定工作区，
/// 终端工具的会话都锚定该工作区，按 ID 过滤即硬隔离范围内的全部会话）。
List<PooledWorkspaceSession> agentAliveSessions(
  WorkspaceSessionPoolManager manager,
  String workspaceId,
) =>
    [
      for (final s in manager.allSessions())
        if (s.alive && s.workspaceId == workspaceId) s,
    ];
