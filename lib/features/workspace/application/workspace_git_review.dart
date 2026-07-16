// Git Review 面板（变更暂存/提交 + 历史浏览）的逻辑层。
//
// 与 workspace_git_status.dart（文件树染色的最小 status 快照）互补：这里
// 把 porcelain 的 X/Y 两列拆开成「已暂存 / 未暂存」两组条目，并封装
// stage / unstage / discard / commit / log 等命令。解析函数是纯 Dart（可单测），
// [GitReviewService] 负责经 [WorkspaceBackend.exec] 跑 git 命令——仅对
// canExec 的后端（SSH / PRoot / Termux）可用，与 gitStatusProvider 同前提。

import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// Which side of the index a change entry sits on.
enum GitChangeArea { staged, unstaged }

/// One file-level change, attributed to the staged or unstaged group.
/// [path] / [origPath] are repo-relative POSIX paths ([origPath] is the
/// rename origin, set only for renames/copies).
class GitChangeEntry {
  const GitChangeEntry({
    required this.path,
    required this.status,
    required this.area,
    this.origPath,
  });

  final String path;
  final GitFileStatus status;
  final GitChangeArea area;
  final String? origPath;

  String get name {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }

  String get directory {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }
}

/// Splits `git status --porcelain=v1 -z` output into staged (X column) and
/// unstaged (Y column) entries. One porcelain record can yield both — e.g.
/// `MM` is staged-modified *and* unstaged-modified. Untracked (`??`) is
/// always unstaged; ignored (`!!`) is skipped.
List<GitChangeEntry> parseGitChangeEntries(String out) {
  final entries = <GitChangeEntry>[];
  final tokens = out.split('\x00');
  for (var i = 0; i < tokens.length; i++) {
    final rec = tokens[i];
    if (rec.length < 4) continue;
    final x = rec[0];
    final y = rec[1];
    var rel = rec.substring(3);
    String? orig;
    if (x == 'R' || x == 'C') {
      i++;
      if (i < tokens.length) orig = tokens[i];
    }
    if (rel.endsWith('/')) rel = rel.substring(0, rel.length - 1);
    if (rel.isEmpty) continue;
    if (x == '!' && y == '!') continue;
    if (x == '?' && y == '?') {
      entries.add(GitChangeEntry(
        path: rel,
        status: GitFileStatus.untracked,
        area: GitChangeArea.unstaged,
      ));
      continue;
    }
    // 冲突条目（UU/AA/DD/含 U）：暂存区状态未定，归入未暂存组提示处理。
    if (x == 'U' ||
        y == 'U' ||
        (x == 'A' && y == 'A') ||
        (x == 'D' && y == 'D')) {
      entries.add(GitChangeEntry(
        path: rel,
        status: GitFileStatus.conflicted,
        area: GitChangeArea.unstaged,
        origPath: orig,
      ));
      continue;
    }
    final staged = _statusFromCode(x);
    if (staged != null) {
      entries.add(GitChangeEntry(
        path: rel,
        status: staged,
        area: GitChangeArea.staged,
        origPath: orig,
      ));
    }
    final unstaged = _statusFromCode(y);
    if (unstaged != null) {
      entries.add(GitChangeEntry(
        path: rel,
        status: unstaged,
        area: GitChangeArea.unstaged,
      ));
    }
  }
  return entries;
}

GitFileStatus? _statusFromCode(String c) => switch (c) {
      'M' || 'T' => GitFileStatus.modified,
      'A' => GitFileStatus.added,
      'D' => GitFileStatus.deleted,
      'R' || 'C' => GitFileStatus.renamed,
      _ => null,
    };

/// One commit in the 「历史」 tab list.
class GitCommitInfo {
  const GitCommitInfo({
    required this.sha,
    required this.shortSha,
    required this.author,
    required this.time,
    required this.subject,
  });

  final String sha;
  final String shortSha;
  final String author;
  final DateTime time;
  final String subject;
}

/// Parses `git log --pretty=format:%H%x1f%h%x1f%an%x1f%ct%x1f%s%x1e` output.
List<GitCommitInfo> parseGitLog(String out) {
  final commits = <GitCommitInfo>[];
  for (final rec in out.split('\x1e')) {
    final fields = rec.trim().split('\x1f');
    if (fields.length < 5) continue;
    final epoch = int.tryParse(fields[3]);
    if (epoch == null) continue;
    commits.add(GitCommitInfo(
      sha: fields[0],
      shortSha: fields[1],
      author: fields[2],
      time: DateTime.fromMillisecondsSinceEpoch(epoch * 1000),
      subject: fields[4],
    ));
  }
  return commits;
}

/// A file touched by one commit (`git show --name-status`).
class GitCommitFile {
  const GitCommitFile({required this.path, required this.status, this.origPath});

  final String path;
  final GitFileStatus status;
  final String? origPath;
}

/// Parses `git show --name-status -z --pretty=format:` output:
/// NUL-separated `STATUS`, `path` (renames carry an extra origin path).
List<GitCommitFile> parseGitNameStatusZ(String out) {
  final files = <GitCommitFile>[];
  final tokens =
      out.split('\x00').where((t) => t.isNotEmpty).toList(growable: false);
  var i = 0;
  while (i < tokens.length) {
    final code = tokens[i];
    if (code.isEmpty || i + 1 >= tokens.length) break;
    final c = code[0];
    if (c == 'R' || c == 'C') {
      if (i + 2 >= tokens.length) break;
      files.add(GitCommitFile(
        path: tokens[i + 2],
        origPath: tokens[i + 1],
        status: GitFileStatus.renamed,
      ));
      i += 3;
      continue;
    }
    final status = _statusFromCode(c);
    if (status != null) {
      files.add(GitCommitFile(path: tokens[i + 1], status: status));
    }
    i += 2;
  }
  return files;
}

/// Branch line of `git status --porcelain=v1 -z -b`'s first record, e.g.
/// `## main...origin/main [ahead 2, behind 1]` / `## HEAD (no branch)`.
class GitBranchInfo {
  const GitBranchInfo({required this.branch, this.ahead = 0, this.behind = 0});

  final String branch;
  final int ahead;
  final int behind;
}

GitBranchInfo parseGitBranchHeader(String header) {
  var s = header.trim();
  if (s.startsWith('##')) s = s.substring(2).trim();
  var ahead = 0;
  var behind = 0;
  final bracket = RegExp(r'\[([^\]]*)\]$').firstMatch(s);
  if (bracket != null) {
    final inner = bracket.group(1)!;
    final a = RegExp(r'ahead (\d+)').firstMatch(inner);
    final b = RegExp(r'behind (\d+)').firstMatch(inner);
    ahead = a == null ? 0 : int.parse(a.group(1)!);
    behind = b == null ? 0 : int.parse(b.group(1)!);
    s = s.substring(0, bracket.start).trim();
  }
  final dots = s.indexOf('...');
  if (dots >= 0) s = s.substring(0, dots);
  return GitBranchInfo(branch: s, ahead: ahead, behind: behind);
}

/// One local branch in the 切换分支 sheet.
class GitBranchItem {
  const GitBranchItem({required this.name, required this.isCurrent});

  final String name;
  final bool isCurrent;
}

/// Parses `git branch --list --format='%(HEAD)%(refname:short)'` output:
/// one branch per line, `*` prefix marks the checked-out one.
List<GitBranchItem> parseGitBranches(String out) {
  final branches = <GitBranchItem>[];
  for (final line in out.split('\n')) {
    if (line.isEmpty) continue;
    final isCurrent = line[0] == '*';
    final name = line.substring(1).trim();
    if (name.isEmpty || name.startsWith('(')) continue; // detached HEAD row
    branches.add(GitBranchItem(name: name, isCurrent: isCurrent));
  }
  return branches;
}

/// The full 「变更」 tab state loaded in one pass.
class GitReviewSnapshot {
  const GitReviewSnapshot({
    required this.repoRoot,
    required this.branch,
    required this.staged,
    required this.unstaged,
  });

  final String repoRoot;
  final GitBranchInfo branch;
  final List<GitChangeEntry> staged;
  final List<GitChangeEntry> unstaged;

  bool get isClean => staged.isEmpty && unstaged.isEmpty;
}

/// Raised when a git command exits non-zero; [message] carries stderr.
class GitCommandException implements Exception {
  GitCommandException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Runs git commands for the review panel over a [WorkspaceBackend].
/// All paths passed in are repo-relative; [repoRoot] anchors the commands.
class GitReviewService {
  GitReviewService({required this.backend, required this.repoRoot});

  final WorkspaceBackend backend;
  final String repoRoot;

  static const _git = 'git -c core.quotepath=off';

  Future<WorkspaceExecResult> _run(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final result = await backend.exec(
      command,
      workingDirectory: repoRoot,
      timeout: timeout,
    );
    if (result.exitCode != 0) {
      final err = result.stderr.trim();
      throw GitCommandException(err.isEmpty ? '命令失败（exit ${result.exitCode}）' : err);
    }
    return result;
  }

  Future<GitReviewSnapshot> loadStatus() async {
    final result = await _run('$_git status --porcelain=v1 -z -b');
    final tokens = result.stdout.split('\x00');
    final branch =
        parseGitBranchHeader(tokens.isEmpty ? '' : tokens.first);
    final rest = tokens.length > 1
        ? tokens.sublist(1).join('\x00')
        : '';
    final entries = parseGitChangeEntries(rest);
    return GitReviewSnapshot(
      repoRoot: repoRoot,
      branch: branch,
      staged: entries
          .where((e) => e.area == GitChangeArea.staged)
          .toList(growable: false),
      unstaged: entries
          .where((e) => e.area == GitChangeArea.unstaged)
          .toList(growable: false),
    );
  }

  Future<void> stage(String path) =>
      _run('$_git add -A -- ${shellQuoteArg(path)}');

  Future<void> stageAll() => _run('$_git add -A');

  Future<void> unstage(String path) =>
      _run('$_git reset -q -- ${shellQuoteArg(path)}');

  Future<void> unstageAll() => _run('$_git reset -q');

  /// Discards an unstaged change: untracked files are removed, tracked
  /// files restored from the index.
  Future<void> discard(GitChangeEntry entry) async {
    if (entry.status == GitFileStatus.untracked) {
      await _run('$_git clean -fd -- ${shellQuoteArg(entry.path)}');
    } else {
      await _run('$_git checkout -- ${shellQuoteArg(entry.path)}');
    }
  }

  /// Discards *all* working-tree changes（未暂存组）: tracked files restored,
  /// untracked files removed. Staged entries are left untouched.
  Future<void> discardAll() async {
    await _run('$_git checkout -- .');
    await _run('$_git clean -fd');
  }

  Future<void> commit(String message) =>
      _run('$_git commit -m ${shellQuoteArg(message)}');

  Future<List<GitCommitInfo>> log({int limit = 100}) async {
    final result = await _run(
      '$_git log -$limit --pretty=format:%H%x1f%h%x1f%an%x1f%ct%x1f%s%x1e',
      timeout: const Duration(seconds: 20),
    );
    return parseGitLog(result.stdout);
  }

  Future<List<GitCommitFile>> commitFiles(String sha) async {
    final result = await _run(
      '$_git show --name-status -z --pretty=format: ${shellQuoteArg(sha)}',
      timeout: const Duration(seconds: 20),
    );
    return parseGitNameStatusZ(result.stdout);
  }

  /// `git show <rev>:<path>` — empty string when the blob doesn't exist at
  /// that revision (e.g. the file was added later).
  Future<String> showFileAt(String rev, String path) async {
    final result = await backend.exec(
      '$_git show ${shellQuoteArg('$rev:$path')}',
      workingDirectory: repoRoot,
      timeout: const Duration(seconds: 20),
    );
    return result.exitCode == 0 ? result.stdout : '';
  }

  /// Old/new contents for a change entry's diff view.
  /// - staged   : HEAD → index (`:path`)
  /// - unstaged : index → working tree
  Future<(String, String)> diffTexts(GitChangeEntry entry) async {
    if (entry.area == GitChangeArea.staged) {
      final oldText = entry.status == GitFileStatus.added
          ? ''
          : await showFileAt('HEAD', entry.origPath ?? entry.path);
      final newText = entry.status == GitFileStatus.deleted
          ? ''
          : await showFileAt('', entry.path); // ':path' = index
      return (oldText, newText);
    }
    final oldText = entry.status == GitFileStatus.untracked
        ? ''
        : await showFileAt('', entry.path);
    var newText = '';
    if (entry.status != GitFileStatus.deleted) {
      try {
        newText = await backend.readFile('$repoRoot/${entry.path}');
      } catch (_) {
        newText = '';
      }
    }
    return (oldText, newText);
  }

  // ===== v2：同步 / 分支 / 回滚 =====

  static const _syncTimeout = Duration(seconds: 120);

  Future<void> fetch() =>
      _run('$_git fetch --all --prune', timeout: _syncTimeout);

  /// `git pull --ff-only`：只快进，分叉时报错提示用户处理而不是默默
  /// 产生 merge commit。
  Future<void> pull() =>
      _run('$_git pull --ff-only', timeout: _syncTimeout);

  /// `git push`；新分支没有 upstream 时自动补 `-u origin <branch>`。
  Future<void> push(String branch) async {
    try {
      await _run('$_git push', timeout: _syncTimeout);
    } on GitCommandException catch (e) {
      if (!e.message.contains('no upstream')) rethrow;
      await _run(
        '$_git push -u origin ${shellQuoteArg(branch)}',
        timeout: _syncTimeout,
      );
    }
  }

  Future<List<GitBranchItem>> branches() async {
    final result = await _run(
      "$_git branch --list --format='%(HEAD)%(refname:short)'",
      timeout: const Duration(seconds: 20),
    );
    return parseGitBranches(result.stdout);
  }

  Future<void> checkout(String branch) =>
      _run('$_git checkout ${shellQuoteArg(branch)}');

  Future<void> createBranch(String name) =>
      _run('$_git checkout -b ${shellQuoteArg(name)}');

  /// `git revert --no-edit <sha>`：用一个新提交撤销 [sha] 的改动，历史不丢。
  Future<void> revertCommit(String sha) =>
      _run('$_git revert --no-edit ${shellQuoteArg(sha)}');

  /// `git reset --hard <sha>`：把当前分支回退到 [sha]，丢弃之后的提交与
  /// 未提交改动（UI 层红色二次确认）。
  Future<void> resetHard(String sha) =>
      _run('$_git reset --hard ${shellQuoteArg(sha)}');

  /// 把单个文件恢复到 [sha] 时的内容（写入工作区与暂存区）。
  Future<void> restoreFileAt(String sha, String path) =>
      _run('$_git checkout ${shellQuoteArg(sha)} -- ${shellQuoteArg(path)}');

  /// Old/new contents of [file] in commit [sha] (parent → commit).
  Future<(String, String)> commitDiffTexts(String sha, GitCommitFile file) async {
    final oldText = file.status == GitFileStatus.added
        ? ''
        : await showFileAt('$sha^', file.origPath ?? file.path);
    final newText = file.status == GitFileStatus.deleted
        ? ''
        : await showFileAt(sha, file.path);
    return (oldText, newText);
  }
}
