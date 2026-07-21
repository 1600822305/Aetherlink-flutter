import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_compaction_file_restore.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/compaction/agent_microcompact.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

ToolCallEvent _read(
  int seq,
  String path, {
  String? content,
  AgentToolCallState state = AgentToolCallState.success,
  String toolName = 'read_file',
}) =>
    ToolCallEvent(
      id: 'tc-$seq',
      seq: seq,
      at: DateTime(2026, 1, 1),
      toolName: toolName,
      argSummary: path,
      state: state,
      resultSummary: 'ok',
      argsDetail: jsonEncode({'path': path}),
      resultDetail: content ?? '$path 的内容',
    );

void main() {
  group('selectRestoredFiles', () {
    test('从覆盖区间取最近读过的文件，同路径取最近一次', () {
      final restored = selectRestoredFiles(
        covered: [
          _read(1, 'a.dart', content: '旧内容'),
          _read(2, 'b.dart'),
          _read(3, 'a.dart', content: '新内容'),
        ],
        kept: const [],
      );
      expect(restored, hasLength(2));
      expect(restored.first.path, 'a.dart'); // seq 更大者优先
      expect(restored.first.content, '新内容');
      expect(restored[1].path, 'b.dart');
    });

    test('kept 尾部已读过的路径跳过；失败/被清除/非读取工具不取', () {
      final restored = selectRestoredFiles(
        covered: [
          _read(1, 'kept.dart'),
          _read(2, 'fail.dart', state: AgentToolCallState.failure),
          _read(3, 'cleared.dart',
              content: kMicroCompactClearedPlaceholder),
          _read(4, 'x.dart', toolName: 'terminal_execute'),
          _read(5, 'ok.dart'),
        ],
        kept: [_read(9, 'kept.dart')],
      );
      expect(restored.map((f) => f.path), ['ok.dart']);
    });

    test('受 maxFiles 与总预算约束，单文件超限截断', () {
      final restored = selectRestoredFiles(
        covered: [
          for (var i = 1; i <= 8; i++) _read(i, 'f$i.dart', content: 'x' * 100),
        ],
        kept: const [],
        maxFiles: 3,
        maxCharsPerFile: 50,
        totalBudgetChars: 200,
      );
      expect(restored.length, lessThanOrEqualTo(3));
      for (final f in restored) {
        expect(f.content.length, lessThanOrEqualTo(50 + '\n…（已截断）'.length));
      }
    });

    test('批量读取 files 数组的路径也参与去重与提取', () {
      final batch = ToolCallEvent(
        id: 'tc-b',
        seq: 2,
        at: DateTime(2026, 1, 1),
        toolName: 'read_file',
        argSummary: '批量',
        state: AgentToolCallState.success,
        resultSummary: 'ok',
        argsDetail: jsonEncode({
          'files': [
            {'path': 'm.dart'},
            {'path': 'n.dart'},
          ],
        }),
        resultDetail: '两个文件的内容',
      );
      final restored = selectRestoredFiles(
        covered: [batch],
        kept: const [],
      );
      // 一条批量事件只存一份快照。
      expect(restored, hasLength(1));
      expect(restored.first.content, '两个文件的内容');
    });
  });
}
