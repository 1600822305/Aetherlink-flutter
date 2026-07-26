import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_session_protocol.dart';

export 'package:aetherlink_flutter/features/workspace/application/workspace_session_pool.dart'
    show
        PooledWorkspaceSession,
        WorkspaceSessionException,
        WorkspaceSessionPoolManager;

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
) => [
  for (final s in manager.allSessions())
    if (s.alive && s.workspaceId == workspaceId) s,
];

/// 在任务绑定工作区 [workspaceId] 的会话池里手动新建一个会话（chip 展示，
/// AI 与用户都可用）。后端不支持命令执行或工作区不存在时抛
/// [WorkspaceSessionException]。
Future<PooledWorkspaceSession> createAgentTerminalSession(
  WidgetRef ref,
  String workspaceId, {
  String? name,
}) async {
  final workspaces = await ref.read(workspaceStoreProvider.future);
  final workspace = workspaces.where((w) => w.id == workspaceId).firstOrNull;
  if (workspace == null) {
    throw const WorkspaceSessionException('任务绑定的工作区不存在或已被移除');
  }
  final backend = ref.read(workspaceBackendProvider(workspace));
  if (!backend.capabilities.canExec) {
    throw const WorkspaceSessionException(
      '该工作区的后端不支持终端（仅内置终端 / SSH / Termux 支持）',
    );
  }
  return ref
      .read(workspaceSessionPoolManagerProvider)
      .poolFor(
        backend,
        workspaceLabel: workspace.name,
        workspaceId: workspace.id,
      )
      .create(
        name: name,
        workingDirectory: workspace.root,
        environment: {
          if (workspace.scope == WorkspaceScope.project &&
              workspace.isolatedHomePath != null)
            'HOME': workspace.isolatedHomePath!,
        },
        greeting: workspace.backendType == WorkspaceBackendType.prootLocal
            ? buildProotGreeting(name: workspace.name, root: workspace.root)
            : null,
      );
}
