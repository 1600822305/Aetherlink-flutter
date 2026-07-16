// workspace_git_review.dart 纯解析逻辑的单测：porcelain X/Y 拆分、
// log / name-status 解析、分支头解析。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_git_review.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_git_status.dart';

void main() {
  group('parseGitChangeEntries', () {
    test('splits X/Y columns into staged and unstaged entries', () {
      // `MM a.txt` → staged-modified + unstaged-modified；`M  b.txt` → 仅暂存；
      // ` M c.txt` → 仅未暂存；`?? d.txt` → 未跟踪。
      final out = 'MM a.txt\x00M  b.txt\x00 M c.txt\x00?? d.txt\x00';
      final entries = parseGitChangeEntries(out);

      GitChangeEntry one(String path, GitChangeArea area) => entries.singleWhere(
            (e) => e.path == path && e.area == area,
          );

      expect(entries, hasLength(5));
      expect(one('a.txt', GitChangeArea.staged).status, GitFileStatus.modified);
      expect(
          one('a.txt', GitChangeArea.unstaged).status, GitFileStatus.modified);
      expect(one('b.txt', GitChangeArea.staged).status, GitFileStatus.modified);
      expect(
          one('c.txt', GitChangeArea.unstaged).status, GitFileStatus.modified);
      expect(
          one('d.txt', GitChangeArea.unstaged).status, GitFileStatus.untracked);
    });

    test('rename records carry the origin path and skip its token', () {
      final out = 'R  new/name.txt\x00old/name.txt\x00A  added.txt\x00';
      final entries = parseGitChangeEntries(out);

      expect(entries, hasLength(2));
      expect(entries[0].path, 'new/name.txt');
      expect(entries[0].origPath, 'old/name.txt');
      expect(entries[0].status, GitFileStatus.renamed);
      expect(entries[0].area, GitChangeArea.staged);
      expect(entries[1].path, 'added.txt');
      expect(entries[1].status, GitFileStatus.added);
    });

    test('conflicts go to the unstaged group; ignored entries are skipped', () {
      final out = 'UU conflict.txt\x00!! ignored.txt\x00';
      final entries = parseGitChangeEntries(out);

      expect(entries, hasLength(1));
      expect(entries.single.path, 'conflict.txt');
      expect(entries.single.status, GitFileStatus.conflicted);
      expect(entries.single.area, GitChangeArea.unstaged);
    });

    test('name/directory helpers split the relative path', () {
      const entry = GitChangeEntry(
        path: 'lib/src/util.dart',
        status: GitFileStatus.modified,
        area: GitChangeArea.unstaged,
      );
      expect(entry.name, 'util.dart');
      expect(entry.directory, 'lib/src');

      const top = GitChangeEntry(
        path: 'README.md',
        status: GitFileStatus.modified,
        area: GitChangeArea.unstaged,
      );
      expect(top.name, 'README.md');
      expect(top.directory, '');
    });
  });

  group('parseGitLog', () {
    test('parses unit-separated records', () {
      final out = 'abc123full\x1fabc123\x1fLisa\x1f1700000000\x1f'
          'feat: 初始提交\x1e'
          'def456full\x1fdef456\x1fBob\x1f1700000100\x1ffix: bug\x1e';
      final commits = parseGitLog(out);

      expect(commits, hasLength(2));
      expect(commits[0].sha, 'abc123full');
      expect(commits[0].shortSha, 'abc123');
      expect(commits[0].author, 'Lisa');
      expect(
        commits[0].time,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      );
      expect(commits[0].subject, 'feat: 初始提交');
      expect(commits[1].subject, 'fix: bug');
    });

    test('skips malformed records', () {
      expect(parseGitLog(''), isEmpty);
      expect(parseGitLog('garbage'), isEmpty);
    });
  });

  group('parseGitNameStatusZ', () {
    test('parses status/path pairs and rename triples', () {
      final out = 'M\x00lib/a.dart\x00R100\x00old.dart\x00new.dart\x00'
          'A\x00b.dart\x00D\x00c.dart\x00';
      final files = parseGitNameStatusZ(out);

      expect(files, hasLength(4));
      expect(files[0].path, 'lib/a.dart');
      expect(files[0].status, GitFileStatus.modified);
      expect(files[1].path, 'new.dart');
      expect(files[1].origPath, 'old.dart');
      expect(files[1].status, GitFileStatus.renamed);
      expect(files[2].status, GitFileStatus.added);
      expect(files[3].status, GitFileStatus.deleted);
    });
  });

  group('GitStatusOverview', () {
    test('resolves ownership by longest repo-root prefix', () {
      final outer = GitStatusSnapshot(
        repoRoot: '/ws/app',
        files: {'/ws/app/a.txt': GitFileStatus.modified},
      );
      final nested = GitStatusSnapshot(
        repoRoot: '/ws/app/vendor/lib',
        files: {'/ws/app/vendor/lib/b.txt': GitFileStatus.added},
      );
      final overview = GitStatusOverview(repos: [outer, nested]);

      expect(overview.repoOf('/ws/app/a.txt')?.repoRoot, '/ws/app');
      expect(
        overview.repoOf('/ws/app/vendor/lib/b.txt')?.repoRoot,
        '/ws/app/vendor/lib',
      );
      expect(overview.repoOf('/ws/other/c.txt'), isNull);
      expect(overview.statusOf('/ws/app/vendor/lib/b.txt'),
          GitFileStatus.added);
      expect(overview.totalChanges, 2);
    });

    test('sibling repo roots do not swallow each other', () {
      final a = GitStatusSnapshot(repoRoot: '/ws/app', files: const {});
      final b = GitStatusSnapshot(repoRoot: '/ws/app2', files: const {});
      final overview = GitStatusOverview(repos: [a, b]);

      expect(overview.repoOf('/ws/app2/x.txt')?.repoRoot, '/ws/app2');
      expect(overview.repoOf('/ws/app/x.txt')?.repoRoot, '/ws/app');
    });
  });

  group('batch status', () {
    test('command quotes roots and delimits records', () {
      final cmd = buildBatchStatusCommand(['/ws/a', "/ws/it's"]);
      expect(cmd, contains("printf '\\001%s\\002' '/ws/a';"));
      expect(cmd, contains("git -C '/ws/a'"));
      expect(cmd, contains("'/ws/it'\\''s'"));
    });

    test('parses multi-repo delimited output', () {
      final out = '\x01/ws/a\x02 M x.txt\x00'
          '\x01/ws/b\x02?? y.txt\x00 M z.txt\x00'
          '\x01/ws/clean\x02';
      final snaps = parseBatchStatusOutput(out);

      expect(snaps, hasLength(3));
      expect(snaps[0].repoRoot, '/ws/a');
      expect(snaps[0].files['/ws/a/x.txt'], GitFileStatus.modified);
      expect(snaps[1].files['/ws/b/y.txt'], GitFileStatus.untracked);
      expect(snaps[1].files['/ws/b/z.txt'], GitFileStatus.modified);
      expect(snaps[2].files, isEmpty);
    });
  });

  group('parseGitBranches', () {
    test('marks the current branch and skips detached HEAD rows', () {
      final out = '*main\n dev\n feature/x\n*(HEAD detached at 1a2b3c)\n';
      final branches = parseGitBranches(out);

      expect(branches.map((b) => b.name), ['main', 'dev', 'feature/x']);
      expect(branches[0].isCurrent, isTrue);
      expect(branches[1].isCurrent, isFalse);
    });
  });

  group('parseGitBranchHeader', () {
    test('parses branch with upstream and ahead/behind', () {
      final info =
          parseGitBranchHeader('## main...origin/main [ahead 2, behind 1]');
      expect(info.branch, 'main');
      expect(info.ahead, 2);
      expect(info.behind, 1);
    });

    test('parses plain branch and detached HEAD', () {
      expect(parseGitBranchHeader('## feature/x').branch, 'feature/x');
      expect(parseGitBranchHeader('## feature/x').ahead, 0);
      expect(
        parseGitBranchHeader('## HEAD (no branch)').branch,
        'HEAD (no branch)',
      );
    });
  });
}
