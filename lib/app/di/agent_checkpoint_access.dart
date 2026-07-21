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

/// 检查点创建结果：成功给 [commits]（仓库根 → commit，多仓库工作区
/// 每个仓库各一个快照），不可用给 [unavailableReason]。
class AgentCheckpointResult {
  const AgentCheckpointResult.ok(Map<String, String> this.commits)
    : unavailableReason = null;

  const AgentCheckpointResult.unavailable(String this.unavailableReason)
    : commits = null;

  final Map<String, String>? commits;
  final String? unavailableReason;
}

/// 回滚结果：[safetyCommits] 是回滚前自动落的安全快照（仓库根 →
/// commit，可再回滚回来），[files] 是本次回滚实际触达的文件清单
///（检查点 vs 回滚前状态）。
class AgentRollbackResult {
  const AgentRollbackResult({
    required this.safetyCommits,
    required this.files,
  });

  final Map<String, String> safetyCommits;
  final List<RollbackFileChange> files;
}

/// 回滚会触达的一个文件（检查点与当前状态的差异条目）。
class RollbackFileChange {
  const RollbackFileChange({
    required this.path,
    required this.kind,
    this.repoRoot = '',
    this.repoName = '',
    this.insertions,
    this.deletions,
  });

  /// 仓库根相对路径。
  final String path;

  final RollbackFileKind kind;

  /// 所属仓库根（检查点 commits 的键；旧单仓库数据为空串）。
  final String repoRoot;

  /// 仓库根尾段，多仓库预览面板展示归属用。
  final String repoName;

  /// 检查点之后新增/删除的行数（numstat）；二进制或取不到时 null。
  final int? insertions;
  final int? deletions;

  RollbackFileChange withStats({int? insertions, int? deletions}) =>
      RollbackFileChange(
        path: path,
        kind: kind,
        repoRoot: repoRoot,
        repoName: repoName,
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

/// 为任务当前工作区创建检查点：对工作区下发现的**每个**仓库各落
/// 一个快照（多仓库容器工作区支持）。部分仓库快照失败不阻断其余；
/// 全部失败才报不可用。不可用（未绑定/SAF/无仓库）不抛错，由调用方
/// 决定是否提示。
Future<AgentCheckpointResult> createAgentCheckpoint(
  Ref ref,
  String taskId,
  String? workspaceId,
) async {
  final context = await _repoContext(ref, workspaceId);
  if (context.unavailableReason != null) {
    return AgentCheckpointResult.unavailable(context.unavailableReason!);
  }
  final (backend, roots) = (context.backend!, context.repoRoots!);
  final commits = <String, String>{};
  String? firstError;
  for (final repoRoot in roots) {
    try {
      commits[repoRoot] = await _snapshot(backend, repoRoot, taskId);
    } on _GitFailure catch (e) {
      firstError ??= e.message;
    }
  }
  if (commits.isEmpty) {
    return AgentCheckpointResult.unavailable('git 快照失败：$firstError');
  }
  return AgentCheckpointResult.ok(commits);
}

/// 回滚到检查点 [commits]（仓库根 → commit）：逐仓库先落安全快照，
/// 再删掉检查点之后新增的文件、还原被改/被删文件。旧单仓库数据
///（空键）回滚时从工作区根 rev-parse 解析仓库。失败抛 [StateError]
///（带用户可读原因）。
Future<AgentRollbackResult> rollbackAgentCheckpoint(
  Ref ref,
  String taskId,
  String? workspaceId,
  Map<String, String> commits,
) async {
  final context = await _repoContext(ref, workspaceId);
  if (context.unavailableReason != null) {
    throw StateError(context.unavailableReason!);
  }
  final backend = context.backend!;

  final resolved = await _resolveCommitRepos(context, commits);
  final safetyCommits = <String, String>{};
  final files = <RollbackFileChange>[];
  final multi = resolved.length > 1;

  // 先逐仓库验证 commit 还在 + 落安全快照，全部就绪后才开始还原：
  // 避免前面仓库已还原、后面仓库才发现快照失败的半成品状态。
  for (final (repoRoot, commit) in resolved) {
    final exists = await backend.exec(
      'git cat-file -e ${shellQuoteArg('$commit^{commit}')}',
      workingDirectory: repoRoot,
      timeout: const Duration(seconds: 10),
    );
    if (exists.exitCode != 0) {
      throw StateError(
        '检查点提交已不存在（可能被清理），无法回滚'
        '${multi ? '：${_repoName(repoRoot)}' : ''}',
      );
    }
    try {
      safetyCommits[repoRoot] = await _snapshot(backend, repoRoot, taskId);
    } on _GitFailure catch (e) {
      throw StateError('回滚前安全快照失败，已中止：${e.message}');
    }
  }

  for (final (repoRoot, commit) in resolved) {
    final safetyCommit = safetyCommits[repoRoot]!;
    // 两个快照都含未跟踪文件，这个 diff 就是本次回滚实际触达的清单。
    final quotedCommit = shellQuoteArg(commit);
    final diff = await backend.exec(
      'git -c core.quotepath=off diff --name-status --no-renames -z '
      '$quotedCommit ${shellQuoteArg(safetyCommit)}',
      workingDirectory: repoRoot,
      timeout: const Duration(minutes: 1),
    );
    if (diff.exitCode == 0) {
      files.addAll(_withRepo(parseNameStatusZ(diff.stdout), repoRoot));
    }

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
        '还原失败${multi ? '（${_repoName(repoRoot)}）' : ''}：'
        '${restore.stderr.trim()}\n'
        '当前状态已保存为安全快照 ${_short(safetyCommit)}',
      );
    }
  }
  return AgentRollbackResult(safetyCommits: safetyCommits, files: files);
}

/// 把检查点 commits 的键解析成可用的仓库根：空键（旧单仓库数据）
/// 回退到发现列表的首个仓库（与旧行为一致：工作区所在仓库）。
Future<List<(String, String)>> _resolveCommitRepos(
  _RepoContext context,
  Map<String, String> commits,
) async {
  final resolved = <(String, String)>[];
  for (final MapEntry(key: root, value: commit) in commits.entries) {
    if (commit.isEmpty) continue;
    if (root.isNotEmpty) {
      resolved.add((root, commit));
      continue;
    }
    final fallback = context.repoRoots!.firstOrNull;
    if (fallback == null) {
      throw StateError('工作区里没有发现 git 仓库，无法回滚旧检查点');
    }
    resolved.add((fallback, commit));
  }
  if (resolved.isEmpty) {
    throw StateError('检查点没有可用的 commit 记录，无法回滚');
  }
  return resolved;
}

List<RollbackFileChange> _withRepo(
  List<RollbackFileChange> files,
  String repoRoot,
) => [
  for (final f in files)
    RollbackFileChange(
      path: f.path,
      kind: f.kind,
      repoRoot: repoRoot,
      repoName: _repoName(repoRoot),
      insertions: f.insertions,
      deletions: f.deletions,
    ),
];

String _repoName(String repoRoot) => repoRoot.contains('/')
    ? repoRoot.substring(repoRoot.lastIndexOf('/') + 1)
    : repoRoot;

/// 回滚预览：检查点 vs 当前工作区会触达的文件清单（不改任何状态），
/// 多仓库逐仓库聚合。失败抛 [StateError]。
Future<List<RollbackFileChange>> previewAgentRollback(
  Ref ref,
  String? workspaceId,
  Map<String, String> commits,
) async {
  final context = await _repoContext(ref, workspaceId);
  if (context.unavailableReason != null) {
    throw StateError(context.unavailableReason!);
  }
  final backend = context.backend!;
  final resolved = await _resolveCommitRepos(context, commits);
  final files = <RollbackFileChange>[];
  for (final (repoRoot, commit) in resolved) {
    files.addAll(
      _withRepo(await _previewRepo(backend, repoRoot, commit), repoRoot),
    );
  }
  files.sort(
    (a, b) => a.repoName != b.repoName
        ? a.repoName.compareTo(b.repoName)
        : a.path.compareTo(b.path),
  );
  return files;
}

/// 单仓库预览：`git diff <commit>` 看不到检查点之后新增的未跟踪
/// 文件，单独用 ls-files/ls-tree 补齐。
Future<List<RollbackFileChange>> _previewRepo(
  WorkspaceBackend backend,
  String repoRoot,
  String commit,
) async {
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

/// 取单文件「检查点 vs 当前工作区」的文本 diff（预览面板看内容用），
/// 按 [file] 的所属仓库从 [commits] 取对应基线。未跟踪新增文件
/// git diff 看不到，返回空串由 UI 降级提示。
Future<String> loadRollbackFileDiff(
  Ref ref,
  String? workspaceId,
  Map<String, String> commits,
  RollbackFileChange file,
) async {
  final context = await _repoContext(ref, workspaceId);
  if (context.unavailableReason != null) {
    throw StateError(context.unavailableReason!);
  }
  final backend = context.backend!;
  final resolved = await _resolveCommitRepos(context, commits);
  final (repoRoot, commit) = resolved.firstWhere(
    (r) => file.repoRoot.isEmpty || r.$1 == file.repoRoot,
    orElse: () => resolved.first,
  );
  final diff = await backend.exec(
    'git -c core.quotepath=off diff --no-color --no-renames '
    '${shellQuoteArg(commit)} -- ${shellQuoteArg(file.path)}',
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
  const _RepoContext.ok(
    WorkspaceBackend this.backend,
    List<String> this.repoRoots,
  ) : unavailableReason = null;

  const _RepoContext.unavailable(String this.unavailableReason)
    : backend = null,
      repoRoots = null;

  final WorkspaceBackend? backend;

  /// 工作区下发现的全部仓库根（工作区在仓库内 / 多仓库容器都支持）。
  final List<String>? repoRoots;
  final String? unavailableReason;
}

Future<_RepoContext> _repoContext(Ref ref, String? workspaceId) async {
  // 检查点/回滚是破坏性操作，绑定解析失败不回退到其他工作区。
  final resolved =
      await resolveAgentWorkspace(ref, workspaceId, allowFallback: false);
  if (resolved == null) {
    return const _RepoContext.unavailable('绑定的工作区不可用（未绑定或已被移除）');
  }
  final (workspace, backend) = resolved;
  if (!backend.capabilities.canExec) {
    return const _RepoContext.unavailable(
      '当前工作区为纯 SAF 后端，无法执行 git；检查点仅在 SSH / PRoot 工作区可用',
    );
  }
  final roots = await discoverGitRepos(backend, workspace.root);
  if (roots.isEmpty) {
    return const _RepoContext.unavailable('工作区里没有发现 git 仓库，初始化 git 后可用检查点');
  }
  return _RepoContext.ok(backend, roots);
}

/// 删除某任务在其工作区下的全部检查点 ref（删任务时联动），
/// 释放 checkpoint commit 交给 gc 回收。失败静默忽略（尽力而为，
/// 不阻断删除流程）。
Future<void> cleanupAgentCheckpointRefs(
  Ref ref,
  String taskId,
  String? workspaceId,
) async {
  try {
    final context = await _repoContext(ref, workspaceId);
    if (context.unavailableReason != null) return;
    final (backend, roots) = (context.backend!, context.repoRoots!);
    final safeTask = taskId.replaceAll(RegExp(r'[^\w-]'), '_');
    final prefix = 'refs/aetherlink/checkpoints/$safeTask/';
    for (final repoRoot in roots) {
      await backend.exec(
        'git for-each-ref --format="%(refname)" ${shellQuoteArg(prefix)} '
        '| while read -r r; do git update-ref -d "\$r"; done',
        workingDirectory: repoRoot,
        timeout: const Duration(minutes: 1),
      );
    }
  } catch (_) {}
}

/// 每个任务保留的检查点 ref 上限；新快照落地后把更早的修剪掉，
/// 长期使用不会让 .git 无限膨胀。
const int kMaxCheckpointRefsPerTask = 50;

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
  // 索引文件名带任务与时间戳：同一仓库并发任务（父任务/子代理）互不
  // 踩索引；末尾无条件删除，失败路径不留残留。
  final idxName =
      '.git/aetherlink-ckpt-index-$safeTask-'
      '${DateTime.now().millisecondsSinceEpoch}';
  final result = await backend.exec(
    'idx=${shellQuoteArg(idxName)} && '
    '{ GIT_INDEX_FILE=\$idx git read-tree HEAD 2>/dev/null '
    '|| GIT_INDEX_FILE=\$idx git read-tree --empty; } && '
    'GIT_INDEX_FILE=\$idx git add -A . && '
    'tree=\$(GIT_INDEX_FILE=\$idx git write-tree) && '
    'if git rev-parse -q --verify HEAD >/dev/null 2>&1; then '
    'commit=\$(git $author commit-tree \$tree -p HEAD -m aetherlink-checkpoint); '
    'else '
    'commit=\$(git $author commit-tree \$tree -m aetherlink-checkpoint); '
    'fi && '
    'git update-ref ${shellQuoteArg(refName)} \$commit && '
    'echo "AETHER_CKPT_OK:\$commit"; '
    'rc=\$?; rm -f \$idx 2>/dev/null; exit \$rc',
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
  // 修剪本任务超出保留上限的旧 ref（ref 名是毫秒时间戳，字典序即
  // 时间序）；失败静默忽略，不影响快照结果。
  try {
    await backend.exec(
      'git for-each-ref --format="%(refname)" --sort=-refname '
      '${shellQuoteArg('refs/aetherlink/checkpoints/$safeTask/')} '
      '| tail -n +${kMaxCheckpointRefsPerTask + 1} '
      '| while read -r r; do git update-ref -d "\$r"; done',
      workingDirectory: repoRoot,
      timeout: const Duration(seconds: 30),
    );
  } catch (_) {}
  return commit;
}
