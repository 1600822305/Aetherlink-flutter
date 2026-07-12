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
  const AgentCheckpointResult.ok(String this.commit)
      : unavailableReason = null;

  const AgentCheckpointResult.unavailable(String this.unavailableReason)
      : commit = null;

  final String? commit;
  final String? unavailableReason;
}

/// 回滚结果：[safetyCommit] 是回滚前自动落的安全快照（可再回滚回来）。
class AgentRollbackResult {
  const AgentRollbackResult({required this.safetyCommit});

  final String safetyCommit;
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

  // 删掉检查点之后新增的文件（安全快照已保住它们），再整树还原。
  // --worktree 只动工作树，不碰用户的 index/暂存区。
  final quotedCommit = shellQuoteArg(commit);
  final restore = await backend.exec(
    'git diff --name-only -z --diff-filter=A '
    '$quotedCommit ${shellQuoteArg(safetyCommit)} '
    '| xargs -0 -r rm -f -- && '
    'git restore --source=$quotedCommit --worktree -- :/',
    workingDirectory: repoRoot,
    timeout: const Duration(minutes: 2),
  );
  if (restore.exitCode != 0) {
    throw StateError('还原失败：${restore.stderr.trim()}\n'
        '当前状态已保存为安全快照 ${_short(safetyCommit)}');
  }
  return AgentRollbackResult(safetyCommit: safetyCommit);
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
    return const _RepoContext.unavailable(
      '工作区不在 git 仓库内，初始化 git 后可用检查点',
    );
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
  final refName = 'refs/aetherlink/checkpoints/$safeTask/'
      '${DateTime.now().millisecondsSinceEpoch}';
  const author = '-c user.name=AetherLink '
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
    'echo \$commit',
    workingDirectory: repoRoot,
    timeout: const Duration(minutes: 2),
  );
  final commit = result.stdout.trim().split('\n').last.trim();
  if (result.exitCode != 0 || commit.isEmpty) {
    throw _GitFailure(result.stderr.trim().isEmpty
        ? '未知错误（exit ${result.exitCode}）'
        : result.stderr.trim());
  }
  return commit;
}
