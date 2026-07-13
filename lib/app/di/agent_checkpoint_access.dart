import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/agent_workspace_access.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';

/// 检查点回滚的组装 seam（初稿 §5.5 P2，参考 Cline 影子提交思路的
/// 就地变体）：每条用户消息前把工作区完整状态（含未跟踪文件，尊重
/// .gitignore）用临时索引写成 commit 对象，挂在 refs/aetherlink/
/// checkpoints/ 下防 gc——不动用户的 HEAD/index/暂存区/分支。
/// 回滚 = 先给当前状态落安全快照，再删掉检查点之后新增的文件、
/// `git restore --source` 还原其余文件；对话/事件流不受影响。
/// 仅 canExec + git 仓库的工作区可用（SAF 无法执行 git）。

/// 检查点创建结果：成功给 [commit]，不可用给 [unavailableReason]。
class AgentCheckpointResult {
  const AgentCheckpointResult.ok(String this.commit) : unavailableReason = null;

  const AgentCheckpointResult.unavailable(String this.unavailableReason)
    : commit = null;

  final String? commit;
  final String? unavailableReason;
}

/// 回滚结果：[safetyCommit] 是回滚前自动落的安全快照（可再回滚回来），
/// [files] 是本次回滚实际触达的文件清单（检查点 vs 回滚前状态）。
class AgentRollbackResult {
  const AgentRollbackResult({required this.safetyCommit, required this.files});

  final String safetyCommit;
  final List<RollbackFileChange> files;
}

/// 回滚会触达的一个文件（检查点与当前状态的差异条目）。
class RollbackFileChange {
  const RollbackFileChange({
    required this.path,
    required this.kind,
    this.insertions,
    this.deletions,
  });

  /// 仓库根相对路径。
  final String path;

  final RollbackFileKind kind;

  /// 检查点之后新增/删除的行数（numstat）；二进制或取不到时 null。
  final int? insertions;
  final int? deletions;

  RollbackFileChange withStats({int? insertions, int? deletions}) =>
      RollbackFileChange(
        path: path,
        kind: kind,
        insertions: insertions ?? this.insertions,
        deletions: deletions ?? this.deletions,
      );
}

/// 回滚对文件的动作：检查点之后新增的会被删除，被改的会还原，
/// 被删的会恢复。
enum RollbackFileKind {
  /// 检查点之后新增 → 回滚将删除。
  added,

  /// 检查点之后被修改 → 回滚将还原。
  modified,

  /// 检查点之后被删除 → 回滚将恢复。
  deleted,
}

/// 为任务当前工作区创建检查点。不可用（未绑定/SAF/非 git）不抛错，
/// 由调用方决定是否提示。
Future<AgentCheckpointResult> createAgentCheckpoint(
  Ref ref,
  String taskId,
  String? workspaceId,
) async {
  final context = await _repoContext(ref, workspaceId);
  if (context.unavailableReason != null) {
    return AgentCheckpointResult.unavailable(context.unavailableReason!);
  }
  final (backend, repoRoot) = (context.backend!, context.repoRoot!);
  try {
    final commit = await _snapshot(backend, repoRoot, taskId);
    return AgentCheckpointResult.ok(commit);
  } on _GitFailure catch (e) {
    return AgentCheckpointResult.unavailable('git 快照失败：${e.message}');
  }
}

/// 回滚到检查点 [commit]：先落安全快照，再删掉检查点之后新增的文件、
/// 还原被改/被删文件。失败抛 [StateError]（带用户可读原因）。
Future<AgentRollbackResult> rollbackAgentCheckpoint(
  Ref ref,
  String taskId,
  String? workspaceId,
  String commit,
) async {
  final context = await _repoContext(ref, workspaceId);
  if (context.unavailableReason != null) {
    throw StateError(context.unavailableReason!);
  }
  final (backend, repoRoot) = (context.backend!, context.repoRoot!);

  final exists = await backend.exec(
    'git cat-file -e ${shellQuoteArg('$commit^{commit}')}',
    workingDirectory: repoRoot,
    timeout: const Duration(seconds: 10),
  );
  if (exists.exitCode != 0) {
    throw StateError('检查点提交已不存在（可能被清理），无法回滚');
  }

  late final String safetyCommit;
  try {
    safetyCommit = await _snapshot(backend, repoRoot, taskId);
  } on _GitFailure catch (e) {
    throw StateError('回滚前安全快照失败，已中止：${e.message}');
  }

  // 两个快照都含未跟踪文件，这个 diff 就是本次回滚实际触达的文件清单。
  final quotedCommit = shellQuoteArg(commit);
  final diff = await backend.exec(
    'git -c core.quotepath=off diff --name-status --no-renames -z '
    '$quotedCommit ${shellQuoteArg(safetyCommit)}',
    workingDirectory: repoRoot,
    timeout: const Duration(minutes: 1),
  );
  final files = diff.exitCode == 0
      ? parseNameStatusZ(diff.stdout)
      : <RollbackFileChange>[];

  // 删掉检查点之后新增的文件（安全快照已保住它们），再整树还原。
  // --worktree 只动工作树，不碰用户的 index/暂存区。
  final restore = await backend.exec(
    'git diff --name-only -z --diff-filter=A '
    '$quotedCommit ${shellQuoteArg(safetyCommit)} '
    '| xargs -0 -r rm -f -- && '
    'git restore --source=$quotedCommit --worktree -- :/',
    workingDirectory: repoRoot,
    timeout: const Duration(minutes: 2),
  );
  if (restore.exitCode != 0) {
    throw StateError(
      '还原失败：${restore.stderr.trim()}\n'
      '当前状态已保存为安全快照 ${_short(safetyCommit)}',
    );
  }
  return AgentRollbackResult(safetyCommit: safetyCommit, files: files);
}

/// 回滚预览：检查点 vs 当前工作区会触达的文件清单（不改任何状态）。
/// `git diff <commit>` 看不到检查点之后新增的未跟踪文件，单独用
/// ls-files/ls-tree 补齐。失败抛 [StateError]。
Future<List<RollbackFileChange>> previewAgentRollback(
  Ref ref,
  String? workspaceId,
  String commit,
) async {
  final context = await _repoContext(ref, workspaceId);
  if (context.unavailableReason != null) {
    throw StateError(context.unavailableReason!);
  }
  final (backend, repoRoot) = (context.backend!, context.repoRoot!);
  final quotedCommit = shellQuoteArg(commit);

  final diff = await backend.exec(
    'git -c core.quotepath=off diff --name-status --no-renames -z '
    '$quotedCommit',
    workingDirectory: repoRoot,
    timeout: const Duration(minutes: 1),
  );
  if (diff.exitCode != 0) {
    throw StateError('对比检查点失败：${diff.stderr.trim()}');
  }
  final files = parseNameStatusZ(diff.stdout);

  final untracked = await backend.exec(
    'git -c core.quotepath=off ls-files --others --exclude-standard -z',
    workingDirectory: repoRoot,
    timeout: const Duration(seconds: 30),
  );
  final inCheckpoint = await backend.exec(
    'git -c core.quotepath=off ls-tree -r --name-only -z $quotedCommit',
    workingDirectory: repoRoot,
    timeout: const Duration(seconds: 30),
  );
  if (untracked.exitCode == 0 && inCheckpoint.exitCode == 0) {
    final checkpointPaths = inCheckpoint.stdout
        .split('\x00')
        .where((p) => p.isNotEmpty)
        .toSet();
    final known = files.map((f) => f.path).toSet();
    for (final path in untracked.stdout.split('\x00')) {
      if (path.isEmpty || known.contains(path)) continue;
      files.add(
        RollbackFileChange(
          path: path,
          kind: checkpointPaths.contains(path)
              ? RollbackFileKind.modified
              : RollbackFileKind.added,
        ),
      );
    }
  }
  // 逐文件行数统计：已跟踪差异用 numstat；未跟踪新文件 git diff
  // 看不到，用 wc -l 补一个新增行数（回滚将删除这些行）。
  final stats = <String, (int?, int?)>{};
  final numstat = await backend.exec(
    'git -c core.quotepath=off diff --numstat --no-renames $quotedCommit',
    workingDirectory: repoRoot,
    timeout: const Duration(minutes: 1),
  );
  if (numstat.exitCode == 0) {
    for (final line in numstat.stdout.split('\n')) {
      final parts = line.split('\t');
      if (parts.length < 3) continue;
      stats[parts.sublist(2).join('\t')] = (
        int.tryParse(parts[0]),
        int.tryParse(parts[1]),
      );
    }
  }
  final wc = await backend.exec(
    'git -c core.quotepath=off ls-files --others --exclude-standard -z '
    '| xargs -0 -r -n 50 wc -l',
    workingDirectory: repoRoot,
    timeout: const Duration(seconds: 30),
  );
  if (wc.exitCode == 0) {
    for (final line in wc.stdout.split('\n')) {
      final m = RegExp(r'^\s*(\d+)\s+(.+)$').firstMatch(line);
      if (m == null || m.group(2) == 'total') continue;
      stats.putIfAbsent(m.group(2)!, () => (int.tryParse(m.group(1)!), 0));
    }
  }
  for (var i = 0; i < files.length; i++) {
    final s = stats[files[i].path];
    if (s != null) {
      files[i] = files[i].withStats(insertions: s.$1, deletions: s.$2);
    }
  }

  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// 取单文件「检查点 vs 当前工作区」的文本 diff（预览面板看内容用）。
/// 未跟踪新增文件 git diff 看不到，返回空串由 UI 降级提示。
Future<String> loadRollbackFileDiff(
  Ref ref,
  String? workspaceId,
  String commit,
  String path,
) async {
  final context = await _repoContext(ref, workspaceId);
  if (context.unavailableReason != null) {
    throw StateError(context.unavailableReason!);
  }
  final (backend, repoRoot) = (context.backend!, context.repoRoot!);
  final diff = await backend.exec(
    'git -c core.quotepath=off diff --no-color --no-renames '
    '${shellQuoteArg(commit)} -- ${shellQuoteArg(path)}',
    workingDirectory: repoRoot,
    timeout: const Duration(seconds: 30),
  );
  if (diff.exitCode != 0) {
    throw StateError('取 diff 失败：${diff.stderr.trim()}');
  }
  return diff.stdout;
}

/// 解析 `git diff --name-status --no-renames -z` 输出（状态\0路径\0…）。
/// 方向固定为「检查点 → 当前状态」：A=之后新增，D=之后被删。
List<RollbackFileChange> parseNameStatusZ(String raw) {
  final parts = raw.split('\x00');
  final files = <RollbackFileChange>[];
  for (var i = 0; i + 1 < parts.length; i += 2) {
    final status = parts[i].trim();
    final path = parts[i + 1];
    if (status.isEmpty || path.isEmpty) continue;
    files.add(
      RollbackFileChange(
        path: path,
        kind: switch (status[0]) {
          'A' => RollbackFileKind.added,
          'D' => RollbackFileKind.deleted,
          _ => RollbackFileKind.modified,
        },
      ),
    );
  }
  return files;
}

String _short(String commit) =>
    commit.length > 8 ? commit.substring(0, 8) : commit;

class _GitFailure implements Exception {
  const _GitFailure(this.message);

  final String message;
}

class _RepoContext {
  const _RepoContext.ok(WorkspaceBackend this.backend, String this.repoRoot)
    : unavailableReason = null;

  const _RepoContext.unavailable(String this.unavailableReason)
    : backend = null,
      repoRoot = null;

  final WorkspaceBackend? backend;
  final String? repoRoot;
  final String? unavailableReason;
}

Future<_RepoContext> _repoContext(Ref ref, String? workspaceId) async {
  final resolved = await resolveAgentWorkspace(ref, workspaceId);
  if (resolved == null) {
    return const _RepoContext.unavailable('未绑定工作区');
  }
  final (workspace, backend) = resolved;
  if (!backend.capabilities.canExec) {
    return const _RepoContext.unavailable(
      '当前工作区为纯 SAF 后端，无法执行 git；检查点仅在 SSH / PRoot 工作区可用',
    );
  }
  final top = await backend.exec(
    'git rev-parse --show-toplevel',
    workingDirectory: workspace.root,
    timeout: const Duration(seconds: 10),
  );
  final repoRoot = top.stdout.trim();
  if (top.exitCode != 0 || repoRoot.isEmpty) {
    return const _RepoContext.unavailable('工作区不在 git 仓库内，初始化 git 后可用检查点');
  }
  return _RepoContext.ok(backend, repoRoot);
}

/// 临时索引快照：不碰用户 index/HEAD/分支；含未跟踪文件（尊重
/// .gitignore）。commit 挂到 `refs/aetherlink/checkpoints/任务/时间戳`
/// 防 gc。返回 commit 哈希。
Future<String> _snapshot(
  WorkspaceBackend backend,
  String repoRoot,
  String taskId,
) async {
  final safeTask = taskId.replaceAll(RegExp(r'[^\w-]'), '_');
  final refName =
      'refs/aetherlink/checkpoints/$safeTask/'
      '${DateTime.now().millisecondsSinceEpoch}';
  const author =
      '-c user.name=AetherLink '
      '-c user.email=checkpoint@aetherlink.local';
  final result = await backend.exec(
    'idx=.git/aetherlink-ckpt-index && '
    '{ GIT_INDEX_FILE=\$idx git read-tree HEAD 2>/dev/null '
    '|| GIT_INDEX_FILE=\$idx git read-tree --empty; } && '
    'GIT_INDEX_FILE=\$idx git add -A . && '
    'tree=\$(GIT_INDEX_FILE=\$idx git write-tree) && '
    'rm -f \$idx && '
    'if git rev-parse -q --verify HEAD >/dev/null 2>&1; then '
    'commit=\$(git $author commit-tree \$tree -p HEAD -m aetherlink-checkpoint); '
    'else '
    'commit=\$(git $author commit-tree \$tree -m aetherlink-checkpoint); '
    'fi && '
    'git update-ref ${shellQuoteArg(refName)} \$commit && '
    'echo "AETHER_CKPT_OK:\$commit"',
    workingDirectory: repoRoot,
    timeout: const Duration(minutes: 2),
  );
  // 用标记行定位 commit，不受 profile/警告等无关输出干扰。
  final commit = RegExp(
    r'AETHER_CKPT_OK:([0-9a-f]{7,40})',
  ).firstMatch(result.stdout)?.group(1);
  if (result.timedOut) {
    throw const _GitFailure('git 快照超时（仓库过大或存储过慢）');
  }
  if (result.exitCode != 0 || commit == null) {
    final stderr = result.stderr.trim();
    final stdout = result.stdout.trim();
    final detail = [
      if (stderr.isNotEmpty) stderr,
      if (stderr.isEmpty && stdout.isNotEmpty)
        'stdout: ${stdout.length > 200 ? stdout.substring(stdout.length - 200) : stdout}',
    ].join('\n');
    throw _GitFailure(
      detail.isEmpty ? '未知错误（exit ${result.exitCode}）' : detail,
    );
  }
  return commit;
}
