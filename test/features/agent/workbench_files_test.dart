import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/workbench_files.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

ToolCallEvent tool({
  required int seq,
  required String name,
  required AgentToolCallState state,
  String? argsDetail,
  String argSummary = '',
}) =>
    ToolCallEvent(
      id: 'e$seq',
      seq: seq,
      at: DateTime(2026, 1, 1).add(Duration(seconds: seq)),
      toolName: name,
      argSummary: argSummary,
      state: state,
      argsDetail: argsDetail,
    );

void main() {
  test('write 成功的文件进入列表（不限 md），非写工具忽略', () {
    final files = deriveAgentFiles([
      tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'docs/报告.md', 'content': '# 标题'}),
      ),
      tool(
        seq: 2,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'lib/main.dart', 'content': 'void'}),
      ),
      tool(
        seq: 3,
        name: 'read_file',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'ignored.txt'}),
      ),
    ]);
    expect(files.map((f) => f.path), ['lib/main.dart', 'docs/报告.md']);
    final md = files.firstWhere((f) => f.path == 'docs/报告.md');
    expect(md.isMarkdown, isTrue);
    expect(md.name, '报告.md');
    expect(md.dir, 'docs');
    final dart = files.firstWhere((f) => f.path == 'lib/main.dart');
    expect(dart.isMarkdown, isFalse);
    expect(dart.ext, 'dart');
  });

  test('running 状态为创建中并提取流式正文（未闭合 JSON）', () {
    final files = deriveAgentFiles([
      tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.running,
        argsDetail: '{"path":"分析.md","content":"# 分析\\n\\n第一段正',
      ),
    ]);
    expect(files.single.state, AgentFileState.creating);
    expect(files.single.streamingContent, '# 分析\n\n第一段正');
  });

  test('同一路径多次写入按最新事件去重，最新在前', () {
    final files = deriveAgentFiles([
      tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'a.md', 'content': 'v1'}),
      ),
      tool(
        seq: 2,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'b.json', 'content': '{}'}),
      ),
      tool(
        seq: 3,
        name: 'edit',
        state: AgentToolCallState.running,
        argsDetail: jsonEncode({'path': 'a.md'}),
      ),
    ]);
    expect(files.map((f) => f.path), ['a.md', 'b.json']);
    expect(files.first.state, AgentFileState.creating);
    expect(files.first.seq, 3);
    // edit 工具创建中不提供流式正文预览。
    expect(files.first.streamingContent, isNull);
  });

  test('失败写入标记为失败', () {
    final files = deriveAgentFiles([
      tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.failure,
        argsDetail: jsonEncode({'path': 'x.txt', 'content': ''}),
      ),
    ]);
    expect(files.single.path, 'x.txt');
    expect(files.single.state, AgentFileState.failed);
  });

  test('argsDetail 缺失时回退用 argSummary 中的路径', () {
    final files = deriveAgentFiles([
      tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.success,
        argSummary: 'notes/README.md',
      ),
    ]);
    expect(files.single.path, 'notes/README.md');
  });

  test('fileContentOfArgs：完整 JSON 与转义字符', () {
    expect(
      fileContentOfArgs(jsonEncode({'path': 'a.md', 'content': '第1行\n"引"'})),
      '第1行\n"引"',
    );
    expect(fileContentOfArgs('{"path":"a.md","content":"abc\\"def'), 'abc"def');
    expect(fileContentOfArgs('{"path":"a.md"}'), isNull);
    expect(fileContentOfArgs(null), isNull);
  });

  test('filePathOfArgs：未闭合 JSON 的正则兜底', () {
    expect(filePathOfArgs('{"path":"docs/a.md","content":"...'), 'docs/a.md');
    expect(filePathOfArgs('{"content":"..."}'), isNull);
  });

  group('AgentFilesFold 增量折叠', () {
    test('结果与全量推导一致，含创建中尾部', () {
      final fold = AgentFilesFold();
      final e1 = tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'a.md', 'content': 'v1'}),
      );
      final e2 = tool(
        seq: 2,
        name: 'write',
        state: AgentToolCallState.running,
        argsDetail: '{"path":"b.md","content":"部分正',
      );
      for (final events in [
        [e1],
        [e1, e2],
      ]) {
        final incremental = fold.fold(events);
        final full = deriveAgentFiles(events);
        expect(incremental.map((f) => f.path), full.map((f) => f.path));
        expect(incremental.map((f) => f.state), full.map((f) => f.state));
      }
      expect(fold.fold([e1, e2]).first.streamingContent, '部分正');
    });

    test('创建中事件原地完结后状态被刷新', () {
      final fold = AgentFilesFold();
      final running = tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.running,
        argsDetail: jsonEncode({'path': 'a.md', 'content': 'v1'}),
      );
      expect(fold.fold([running]).single.state, AgentFileState.creating);
      final done = tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'a.md', 'content': 'v1'}),
      );
      final files = fold.fold([done]);
      expect(files.single.state, AgentFileState.done);
      expect(files.single.streamingContent, isNull);
    });

    test('无关事件追加时返回同一列表实例（不通知依赖方）', () {
      final fold = AgentFilesFold();
      final write = tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'a.md', 'content': 'v1'}),
      );
      final read = tool(
        seq: 2,
        name: 'read_file',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'x.txt'}),
      );
      final first = fold.fold([write]);
      final second = fold.fold([write, read]);
      expect(identical(first, second), isTrue);
    });

    test('事件被删减后整体重扫', () {
      final fold = AgentFilesFold();
      final e1 = tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'a.md', 'content': 'v1'}),
      );
      final e2 = tool(
        seq: 2,
        name: 'write',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'b.md', 'content': 'v2'}),
      );
      expect(fold.fold([e1, e2]).length, 2);
      expect(fold.fold([e1]).map((f) => f.path), ['a.md']);
    });
  });
}
