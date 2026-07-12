import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_view_providers.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

export 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart'
    show GitFileStatus;

/// 智能体工作台「改动 diff」tab 的组装 seam（agent 不得 import workspace
/// 的 application/data，git status/diff 能力经 composition root 暴露）。
///
/// 工作区解析与引擎的项目指令层同一套规则：档案绑定工作区 → 当前打开
/// 的工作区 → 最近打开列表第一个。仅 canExec 后端（SSH/PRoot）可用——
/// git 需要真实 POSIX 路径与可执行环境，SAF 无法支持。

/// 一个改动文件（`git status --porcelain` 的一条记录）。
class AgentFileChange {
  const AgentFileChange({
    required this.relPath,
    required this.absPath,
    required this.status,
  });

  final String relPath;
  final String absPath;
  final GitFileStatus status;
}

/// 一次 git status 快照 + 取 diff 所需的仓库上下文。
class AgentChangesSnapshot {
  const AgentChangesSnapshot({
    required this.workspaceName,
    required this.repoRoot,
    required this.changes,
  });

  final String workspaceName;
  final String repoRoot;
  final List<AgentFileChange> changes;
}

/// 不可用时 [snapshot] 为 null，[unavailableReason] 给 UI 空态文案。
class AgentChangesResult {
  const AgentChangesResult.ok(AgentChangesSnapshot this.snapshot)
      : unavailableReason = null;

  const AgentChangesResult.unavailable(String this.unavailableReason)
      : snapshot = null;

  final AgentChangesSnapshot? snapshot;
  final String? unavailableReason;
}

/// 指定档案工作区（可空）的未提交改动清单。UI 用 `ref.refresh` 手动刷新。
final agentWorkspaceChangesProvider = FutureProvider.autoDispose
    .family<AgentChangesResult, String?>((ref, workspaceId) async {
  final resolved = await _resolveWorkspace(ref, workspaceId);
  if (resolved == null) {
    return const AgentChangesResult.unavailable(
      '尚未打开任何工作区\n在工作区页面「打开文件夹」后这里会显示未提交改动',
    );
  }
  final (workspace, backend) = resolved;
  if (!backend.capabilities.canExec) {
    return const AgentChangesResult.unavailable(
      '当前工作区后端不支持执行命令（纯 SAF）\ngit 改动清单仅在 SSH / PRoot 工作区可用',
    );
  }

  final top = await backend.exec(
    'git rev-parse --show-toplevel',
    workingDirectory: workspace.root,
    timeout: const Duration(seconds: 10),
  );
  final repoRoot = top.stdout.trim();
  if (top.exitCode != 0 || repoRoot.isEmpty) {
    return const AgentChangesResult.unavailable(
      '工作区不在 git 仓库内\n改动清单基于 git status，初始化仓库后可用',
    );
  }

  final status = await backend.exec(
    'git -c core.quotepath=off status --porcelain=v1 -z',
    workingDirectory: workspace.root,
    timeout: const Duration(seconds: 20),
  );
  if (status.exitCode != 0) {
    return AgentChangesResult.unavailable(
      'git status 执行失败\n${status.stderr.trim()}',
    );
  }

  final files = parseGitPorcelainZ(repoRoot, status.stdout);
  final prefix = '$repoRoot/';
  final changes = [
    for (final MapEntry(key: abs, value: st) in files.entries)
      if (abs.startsWith(prefix))
        AgentFileChange(
          relPath: abs.substring(prefix.length),
          absPath: abs,
          status: st,
        ),
  ]..sort((a, b) => a.relPath.compareTo(b.relPath));

  return AgentChangesResult.ok(AgentChangesSnapshot(
    workspaceName: workspace.name,
    repoRoot: repoRoot,
    changes: changes,
  ));
});

/// 单文件对比内容：HEAD 版本（新增/未跟踪为空） vs 工作区当前内容
/// （删除为空）。供只读 diff 面板展示。
Future<({String oldText, String newText})> loadAgentFileDiff(
  Ref ref,
  String? workspaceId,
  AgentChangesSnapshot snapshot,
  AgentFileChange change,
) async {
  final resolved = await _resolveWorkspace(ref, workspaceId);
  if (resolved == null) throw StateError('工作区不可用');
  final (_, backend) = resolved;

  var oldText = '';
  if (change.status != GitFileStatus.untracked &&
      change.status != GitFileStatus.added) {
    final show = await backend.exec(
      'git -c core.quotepath=off show '
      '${shellQuoteArg('HEAD:${change.relPath}')}',
      workingDirectory: snapshot.repoRoot,
      timeout: const Duration(seconds: 20),
    );
    if (show.exitCode == 0) oldText = show.stdout;
  }
  var newText = '';
  if (change.status != GitFileStatus.deleted) {
    newText = await backend.readFile(change.absPath);
  }
  return (oldText: oldText, newText: newText);
}

Future<(Workspace, WorkspaceBackend)?> _resolveWorkspace(
  Ref ref,
  String? workspaceId,
) async {
  List<Workspace> workspaces;
  try {
    workspaces = await loadWorkspaces(ref);
  } catch (_) {
    workspaces = const [];
  }
  if (workspaces.isEmpty) return null;
  final bound = workspaces.where((w) => w.id == workspaceId).firstOrNull;
  final workspace =
      bound ?? ref.read(currentWorkspaceProvider) ?? workspaces.first;
  return (workspace, ref.read(workspaceBackendProvider(workspace)));
}
