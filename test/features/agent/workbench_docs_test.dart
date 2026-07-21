import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/workbench_docs.dart';
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
  test('write 成功的 .md 文件进入文档列表', () {
    final docs = deriveAgentDocs([
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
        argsDetail: jsonEncode({'path': 'main.dart', 'content': 'void'}),
      ),
    ]);
    expect(docs, hasLength(1));
    expect(docs.single.path, 'docs/报告.md');
    expect(docs.single.state, AgentDocState.done);
    expect(docs.single.name, '报告.md');
    expect(docs.single.dir, 'docs');
  });

  test('running 状态为创建中并提取流式正文（未闭合 JSON）', () {
    final docs = deriveAgentDocs([
      tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.running,
        argsDetail: '{"path":"分析.md","content":"# 分析\\n\\n第一段正',
      ),
    ]);
    expect(docs.single.state, AgentDocState.creating);
    expect(docs.single.streamingContent, '# 分析\n\n第一段正');
  });

  test('同一路径多次写入按最新事件去重，最新在前', () {
    final docs = deriveAgentDocs([
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
        argsDetail: jsonEncode({'path': 'b.md', 'content': 'x'}),
      ),
      tool(
        seq: 3,
        name: 'edit',
        state: AgentToolCallState.running,
        argsDetail: jsonEncode({'path': 'a.md'}),
      ),
    ]);
    expect(docs.map((d) => d.path), ['a.md', 'b.md']);
    expect(docs.first.state, AgentDocState.creating);
    expect(docs.first.seq, 3);
    // edit 工具创建中不提供流式正文预览。
    expect(docs.first.streamingContent, isNull);
  });

  test('失败写入标记为失败；非文档工具与非 md 路径忽略', () {
    final docs = deriveAgentDocs([
      tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.failure,
        argsDetail: jsonEncode({'path': 'x.md', 'content': ''}),
      ),
      tool(
        seq: 2,
        name: 'read_file',
        state: AgentToolCallState.success,
        argsDetail: jsonEncode({'path': 'y.md'}),
      ),
    ]);
    expect(docs.single.path, 'x.md');
    expect(docs.single.state, AgentDocState.failed);
  });

  test('argsDetail 缺失时回退用 argSummary 中的 md 路径', () {
    final docs = deriveAgentDocs([
      tool(
        seq: 1,
        name: 'write',
        state: AgentToolCallState.success,
        argSummary: 'notes/README.md',
      ),
    ]);
    expect(docs.single.path, 'notes/README.md');
  });

  test('docContentOfArgs：完整 JSON 与转义字符', () {
    expect(
      docContentOfArgs(jsonEncode({'path': 'a.md', 'content': '第1行\n"引"'})),
      '第1行\n"引"',
    );
    expect(docContentOfArgs('{"path":"a.md","content":"abc\\"def'), 'abc"def');
    expect(docContentOfArgs('{"path":"a.md"}'), isNull);
    expect(docContentOfArgs(null), isNull);
  });

  test('docPathOfArgs：未闭合 JSON 的正则兜底', () {
    expect(docPathOfArgs('{"path":"docs/a.md","content":"...'), 'docs/a.md');
    expect(docPathOfArgs('{"content":"..."}'), isNull);
  });
}
