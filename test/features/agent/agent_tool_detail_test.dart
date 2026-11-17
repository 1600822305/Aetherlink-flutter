import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_tool_detail.dart';

void main() {
  test('commands are copied verbatim only for command tools', () {
    expect(toolCommandText('terminal_execute', r'{"command":" echo hi\n"}'), ' echo hi\n');
    expect(toolCommandText('run_command', '{"command":"pwd"}'), 'pwd');
    expect(toolCommandText('terminal_session', '{"command":"ls"}'), 'ls');
    expect(toolCommandText('write', '{"command":"no"}'), isNull);
    for (final args in ['{}', '{"command":3}', '{"command":" "}', '{', '[]']) {
      expect(toolCommandText('terminal_execute', args), isNull);
    }
  });

  test('file editor results use resolved paths before argument paths', () {
    for (final tool in ['write', 'edit', 'delete_file', 'create_directory']) {
      expect(
        toolChangedFilePaths(
          tool,
          '{"path":"a.txt"}',
          resultText: '{"success":true,"data":{"path":"/work/a.txt"}}',
        ),
        ['/work/a.txt'],
      );
      expect(toolChangedFilePaths(tool, '{"file":"b.txt"}'), ['b.txt']);
    }
    expect(toolChangedFilePaths('write', '{"parent_path":"src","name":"a.dart"}'), ['src/a.dart']);
    expect(
      toolChangedFilePaths(
        'edit',
        '{"path":"a"}',
        resultText: '{"success":false,"data":{"path":"wrong"}}',
      ),
      ['a'],
    );
  });

  test('moves expose both affected paths without duplicates', () {
    expect(toolChangedFilePaths('move', '{"path":"a","new_name":"b"}'), ['a', 'b']);
    expect(
      toolChangedFilePaths(
        'move',
        '{"path":"src/a","destination_path":"dst"}',
        resultText: '{"success":true,"data":{"path":"/work/dst/a"}}',
      ),
      ['/work/dst/a', 'src/a'],
    );
    expect(toolChangedFilePaths('move', '{"path":"a"}'), ['a']);
  });

  test('presentation tools report write targets, not read-only sources', () {
    expect(toolChangedFilePaths('pptx_modify', '{"path":"in.pptx","output":"out.pptx"}'), ['out.pptx']);
    expect(toolChangedFilePaths('pptx_render', '{"source":"in.json","path":"out.pptx"}'), ['out.pptx']);
    expect(toolChangedFilePaths('pptx_render', '{"path":"out.pptx","preview":true}'), ['out.pptx', 'out.preview.html']);
    expect(
      toolChangedFilePaths(
        'pptx_render',
        '{"path":"out.pptx","preview":true}',
        resultText: '{"success":true,"data":{"path":"/w/out.pptx","previewPath":"/w/out.preview.html"}}',
      ),
      ['/w/out.pptx', '/w/out.preview.html'],
    );
    expect(toolChangedFilePaths('pptx_edit', '{"source":"in.json","export":"out.pptx"}'), ['in.json', 'out.pptx']);
    expect(toolChangedFilePaths('pptx_edit', '{"source":"in.json","dry_run":true}'), isEmpty);
    for (final tool in ['pptx_draft', 'pptx_illustrate']) {
      expect(toolChangedFilePaths(tool, '{"path":"out"}'), ['out']);
    }
  });

  test('incomplete, malformed and read-only calls invent no paths', () {
    for (final args in ['', '{', '[]', '{"path":4}', '{}', '{"path":" "}']) {
      expect(toolChangedFilePaths('write', args, resultText: 'failed'), isEmpty);
    }
    expect(toolChangedFilePaths('read_file', '{"path":"a"}'), isEmpty);
    expect(toolChangedFilePaths('terminal_execute', '{"command":"touch a"}'), isEmpty);
    expect(
      toolChangedFilePaths(
        'edit',
        '{',
        resultText: '{"success":true,"data":{"path":"a"}}',
      ),
      ['a'],
    );
  });

  const files = [
    '/work/repo1/src/a.dart',
    '/work/repo2/src/a.dart',
    '/work/repo1/b.dart',
  ];
  test('diff focus matches absolute, normalized and workspace-relative paths', () {
    expect(findToolDiffFileIndex('/work/repo2/src/a.dart', files, workspaceRoot: '/work'), 1);
    expect(findToolDiffFileIndex('./b.dart', files, workspaceRoot: '/work/repo1'), 2);
    expect(findToolDiffFileIndex('repo2/src/a.dart', files, workspaceRoot: '/work'), 1);
    expect(findToolDiffFileIndex(r'repo2\src\a.dart', files, workspaceRoot: '/work'), 1);
    expect(findToolDiffFileIndex('../repo2/src/a.dart', files, workspaceRoot: '/work/repo1'), 1);
  });
  test('ambiguous, unavailable and unrelated files do not focus the wrong row', () {
    for (final path in ['src/a.dart', '/elsewhere/b.dart', 'missing', '', '.']) {
      expect(findToolDiffFileIndex(path, files, workspaceRoot: '/work'), isNull);
    }
    expect(findToolDiffFileIndex('b.dart', [], workspaceRoot: '/work'), isNull);
    expect(findToolDiffFileIndex('src/a.dart', [files[1]], workspaceRoot: '/work/repo1'), isNull);
  });
  test('home-relative paths never resolve beneath the workspace', () {
    for (final path in ['~', '~/deck.json', r'~\deck.json']) {
      expect(
        findToolDiffFileIndex(
          path,
          ['/work/~', '/work/~/deck.json', '/home/user/deck.json'],
          workspaceRoot: '/work',
        ),
        isNull,
      );
    }
  });
  test('focus brings the complete repository group forward without splitting it', () {
    const entries = ['a/1', 'a/2', 'b/1', 'b/2', 'b/3', 'c/1'];
    String root(String file) => file.split('/').first;
    expect(
      prioritizeToolDiffRepository(entries, 3, repoRootOf: root),
      ['b/2', 'b/1', 'b/3', 'a/1', 'a/2', 'c/1'],
    );
    expect(entries, ['a/1', 'a/2', 'b/1', 'b/2', 'b/3', 'c/1']);
    expect(
      prioritizeToolDiffRepository(entries, 0, repoRootOf: root),
      entries,
    );
    expect(prioritizeToolDiffRepository(<String>[], 0, repoRootOf: root), isEmpty);
    expect(prioritizeToolDiffRepository(entries, -1, repoRootOf: root), entries);
    expect(prioritizeToolDiffRepository(entries, 6, repoRootOf: root), entries);
  });
}
