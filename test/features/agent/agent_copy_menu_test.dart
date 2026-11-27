import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_copy_menu.dart';

ToolCallEvent _tool(
  String name, {
  String args = '{}',
  String? result,
  String summary = '',
}) => ToolCallEvent(
  id: 't1',
  seq: 1,
  at: DateTime(2026),
  toolName: name,
  argSummary: '',
  state: AgentToolCallState.success,
  argsDetail: args,
  resultDetail: result,
  resultSummary: summary,
);

Map<String, String> _byLabel(List<CopyEntry> entries) => {
  for (final e in entries)
    if (e.text.trim().isNotEmpty) e.label: e.text,
};

void main() {
  group('readableToolResult', () {
    test('取 data.stdout 并去掉 ANSI', () {
      expect(
        readableToolResult('{"success":true,"data":{"stdout":"\\u001b[32mok\\u001b[0m"}}'),
        'ok',
      );
    });

    test('有 stderr 时拼在后面；error 优先', () {
      expect(
        readableToolResult('{"data":{"stdout":"a","stderr":"warn"}}'),
        'a\nwarn',
      );
      expect(readableToolResult('{"success":false,"error":"boom"}'), 'boom');
    });

    test('非 JSON / 空 原样或空串', () {
      expect(readableToolResult('plain'), 'plain');
      expect(readableToolResult(null), '');
    });
  });

  group('toolCopyEntries', () {
    test('终端命令：命令 / 输出 / 参数', () {
      final m = _byLabel(
        toolCopyEntries(
          _tool(
            'terminal_execute',
            args: '{"command":"npm run build"}',
            result: '{"data":{"stdout":"done"}}',
          ),
        ),
      );
      expect(m['命令'], 'npm run build');
      expect(m['输出'], 'done');
      expect(m['参数'], contains('"command": "npm run build"'));
      expect(m.keys, isNot(contains('路径')));
    });

    test('读文件：从参数里取路径', () {
      final m = _byLabel(
        toolCopyEntries(_tool('read_file', args: '{"path":"lib/main.dart"}')),
      );
      expect(m['路径'], 'lib/main.dart');
      expect(m.keys, isNot(contains('命令')));
    });

    test('没有结果正文时输出回退到摘要', () {
      final m = _byLabel(
        toolCopyEntries(_tool('web_search', summary: '5 条结果')),
      );
      expect(m['输出'], '5 条结果');
    });
  });

  test('planToText：三态标记', () {
    expect(
      planToText(const [
        AgentPlanItem(content: '装依赖', status: AgentPlanItemStatus.completed),
        AgentPlanItem(content: '构建', status: AgentPlanItemStatus.inProgress),
        AgentPlanItem(content: '测试', status: AgentPlanItemStatus.pending),
      ]),
      '[x] 装依赖\n[~] 构建\n[ ] 测试',
    );
  });

  test('prettyArgs：缩进美化，非法 JSON 原样', () {
    expect(prettyArgs('{"a":1}'), '{\n  "a": 1\n}');
    expect(prettyArgs('oops'), 'oops');
  });
}
