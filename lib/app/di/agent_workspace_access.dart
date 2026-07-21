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
    required this.repoRoot,
    required this.repoName,
    this.additions,
    this.deletions,
  });

  /// 相对**所属仓库根** [repoRoot] 的路径。
  final String relPath;
  final String absPath;
  final GitFileStatus status;

  /// 该文件所属的 git 仓库根（多仓库工作区里每个文件各自归属），
  /// diff/还原都基于它，而非工作区根。
  final String repoRoot;

  /// 仓库根尾段，多仓库工作区里 UI 分组表头用。
  final String repoName;

  /// +增/-删行数（git diff --numstat；未跟踪文件用 wc -l），
  /// 二进制文件或统计失败时为 null。
  final int? additions;
  final int? deletions;
}

/// 一次 git status 快照：跨工作区下发现的**全部**仓库聚合而成。
class AgentChangesSnapshot {
  const AgentChangesSnapshot({
    required this.workspaceName,
    required this.changes,
    required this.repoCount,
  });

  final String workspaceName;
  final List<AgentFileChange> changes;

  /// 发现并纳入统计的仓库数（>1 时 UI 按仓库分组显示表头）。
  final int repoCount;
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
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
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

  // 多仓库工作区：向上 rev-parse（工作区在某仓库内）+ 向下扫描 .git
  //（工作区是多仓库容器）合并发现全部仓库，与文件树染色同一套逻辑。
  final roots = await discoverGitRepos(backend, workspace.root);
  if (roots.isEmpty) {
    return const AgentChangesResult.unavailable(
      '工作区里没有发现 git 仓库\n改动清单基于 git status，初始化仓库后可用',
    );
  }

  final status = await backend.exec(
    buildBatchStatusCommand(roots),
    workingDirectory: workspace.root,
    timeout: const Duration(seconds: 20),
  );
  if (status.exitCode != 0 && status.stdout.isEmpty) {
    return AgentChangesResult.unavailable(
      'git status 执行失败\n${status.stderr.trim()}',
    );
  }

  final snapshots = parseBatchStatusOutput(status.stdout);
  final changes = <AgentFileChange>[];
  for (final repo in snapshots) {
    final repoRoot = repo.repoRoot;
    final repoName = repoRoot.contains('/')
        ? repoRoot.substring(repoRoot.lastIndexOf('/') + 1)
        : repoRoot;
    final prefix = '$repoRoot/';
    final entries = [
      for (final MapEntry(key: abs, value: st) in repo.files.entries)
        if (abs.startsWith(prefix))
          (relPath: abs.substring(prefix.length), absPath: abs, status: st),
    ]..sort((a, b) => a.relPath.compareTo(b.relPath));
    if (entries.isEmpty) continue;

    final stats = await _loadChangeStats(backend, repoRoot, entries);
    for (final e in entries) {
      changes.add(AgentFileChange(
        relPath: e.relPath,
        absPath: e.absPath,
        status: e.status,
        repoRoot: repoRoot,
        repoName: repoName,
        additions: stats[e.relPath]?.$1,
        deletions: stats[e.relPath]?.$2,
      ));
    }
  }
  // 多仓库时按 仓库名 → 路径 排序，同仓库文件相邻，UI 好插分组表头。
  changes.sort((a, b) {
    final byRepo = a.repoName.compareTo(b.repoName);
    return byRepo != 0 ? byRepo : a.relPath.compareTo(b.relPath);
  });

  return AgentChangesResult.ok(AgentChangesSnapshot(
    workspaceName: workspace.name,
    changes: changes,
    repoCount: snapshots.length,
  ));
});

/// 逐文件 +增/-删行数：已跟踪改动一次 `git diff HEAD --numstat -z`
/// 全量拿到；未跟踪文件批量 `wc -l`。任一步失败只丢行数不丢清单。
Future<Map<String, (int?, int?)>> _loadChangeStats(
  WorkspaceBackend backend,
  String repoRoot,
  List<({String relPath, String absPath, GitFileStatus status})> entries,
) async {
  final stats = <String, (int?, int?)>{};
  if (entries.isEmpty) return stats;

  try {
    final numstat = await backend.exec(
      'git -c core.quotepath=off diff HEAD --numstat -z',
      workingDirectory: repoRoot,
      timeout: const Duration(seconds: 20),
    );
    if (numstat.exitCode == 0) {
      // -z 格式：`added TAB deleted TAB path NUL`；重命名时 path 为空，
      // 后跟两个 NUL 分隔的旧/新路径。二进制文件行数为 `-`。
      final tokens = numstat.stdout.split('\x00');
      for (var i = 0; i < tokens.length; i++) {
        final parts = tokens[i].split('\t');
        if (parts.length < 3) continue;
        final add = int.tryParse(parts[0]);
        final del = int.tryParse(parts[1]);
        var path = parts.sublist(2).join('\t');
        if (path.isEmpty && i + 2 < tokens.length) {
          path = tokens[i + 2]; // 重命名：取新路径
          i += 2;
        }
        if (path.isNotEmpty) stats[path] = (add, del);
      }
    }
  } catch (_) {
    // 忽略，行数缺失不影响清单。
  }

  final untracked = [
    for (final e in entries)
      if (e.status == GitFileStatus.untracked) e.relPath,
  ];
  if (untracked.isNotEmpty) {
    try {
      final wc = await backend.exec(
        'wc -l ${untracked.map(shellQuoteArg).join(' ')}',
        workingDirectory: repoRoot,
        timeout: const Duration(seconds: 20),
      );
      if (wc.exitCode == 0) {
        for (final line in wc.stdout.split('\n')) {
          final t = line.trim();
          final sp = t.indexOf(' ');
          if (sp <= 0) continue;
          final count = int.tryParse(t.substring(0, sp));
          final path = t.substring(sp + 1).trim();
          if (count != null && untracked.contains(path)) {
            stats[path] = (count, 0);
          }
        }
      }
    } catch (_) {
      // 忽略。
    }
  }
  return stats;
}

/// 单文件对比内容：HEAD 版本（新增/未跟踪为空） vs 工作区当前内容
/// （删除为空）。供只读 diff 面板展示。
Future<({String oldText, String newText})> loadAgentFileDiff(
  Ref ref,
  String? workspaceId,
  AgentChangesSnapshot snapshot,
  AgentFileChange change,
) async {
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) throw StateError('工作区不可用');
  final (_, backend) = resolved;

  var oldText = '';
  if (change.status != GitFileStatus.untracked &&
      change.status != GitFileStatus.added) {
    final show = await backend.exec(
      'git -c core.quotepath=off show '
      '${shellQuoteArg('HEAD:${change.relPath}')}',
      workingDirectory: change.repoRoot,
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

/// 还原单个文件到 HEAD 版本（Diff tab 逐文件「还原此文件」）：
/// HEAD 里存在的文件用 `git checkout HEAD --` 覆盖工作区与暂存区；
/// HEAD 里不存在（新增/未跟踪）则从暂存区与工作区删除。
/// 破坏性操作，工作区绑定解析失败直接抛错，不做回退。
Future<void> revertAgentFileChange(
  Ref ref,
  String? workspaceId,
  AgentChangesSnapshot snapshot,
  AgentFileChange change,
) async {
  final resolved =
      await resolveAgentWorkspace(ref, workspaceId, allowFallback: false);
  if (resolved == null) throw StateError('工作区绑定不可用，无法还原');
  final (_, backend) = resolved;
  final quoted = shellQuoteArg(change.relPath);
  final headRef = shellQuoteArg('HEAD:${change.relPath}');
  final result = await backend.exec(
    'if git cat-file -e $headRef 2>/dev/null; then '
    'git checkout HEAD -- $quoted; '
    'else git rm -f -q --ignore-unmatch -- $quoted; rm -f -- $quoted; fi',
    workingDirectory: change.repoRoot,
    timeout: const Duration(seconds: 20),
  );
  if (result.exitCode != 0) {
    throw StateError('还原失败：${result.stderr.trim()}');
  }
}

/// 工作台「文档」tab：按任务工作区读取智能体写入的文档全文。
/// [path] 为工具参数里的路径（相对工作区 root 或绝对 POSIX 路径），
/// 与 file-editor 写入侧同规则锚定到 root。
Future<String> readAgentWorkspaceDoc(
  Ref ref,
  String? workspaceId,
  String path,
) async {
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) {
    throw StateError('尚未打开任何工作区');
  }
  final (workspace, backend) = resolved;
  final abs = path.startsWith('/') || !workspace.root.startsWith('/')
      ? path
      : joinPosixPath(workspace.root, path);
  return backend.readFile(abs);
}

/// 按任务/档案绑定解析工作区及其后端。
///
/// [allowFallback] 为 true 时绑定未命中会回退到当前打开 → 最近
/// 第一个，仅限纯展示型场景（diff 面板）；检查点/回滚等破坏性
/// 操作必须传 false，绑定解析失败时直接返回 null，避免作用到
/// 错误的工作区。
Future<(Workspace, WorkspaceBackend)?> resolveAgentWorkspace(
  Ref ref,
  String? workspaceId, {
  bool allowFallback = true,
}) async {
  List<Workspace> workspaces;
  try {
    workspaces = await loadWorkspaces(ref);
  } catch (_) {
    workspaces = const [];
  }
  if (workspaces.isEmpty) return null;
  final bound = workspaces.where((w) => w.id == workspaceId).firstOrNull;
  if (bound == null && workspaceId != null && !allowFallback) return null;
  final workspace = bound ??
      (allowFallback
          ? ref.read(currentWorkspaceProvider) ?? workspaces.first
          : null);
  if (workspace == null) return null;
  return (workspace, ref.read(workspaceBackendProvider(workspace)));
}
