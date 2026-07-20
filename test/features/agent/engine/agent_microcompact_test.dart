import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_microcompact.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';

ToolCallEvent _tool(
  int seq, {
  String name = 'terminal_execute',
  int detailChars = 5000,
}) =>
    ToolCallEvent(
      id: 'tool-$seq',
      seq: seq,
      at: DateTime(2026, 1, 1),
      toolName: name,
      argSummary: 'arg',
      state: AgentToolCallState.success,
      resultSummary: 'ok',
      argsDetail: '{}',
      resultDetail: 'x' * detailChars,
    );

UserMessageEvent _user(int seq, String text) => UserMessageEvent(
      id: 'user-$seq',
      seq: seq,
      at: DateTime(2026, 1, 1),
      text: text,
    );

void main() {
  group('microCompactEntries', () {
    test('未超阈值原样返回同一实例（零开销）', () {
      final entries = <AgentEvent>[_user(0, 'hi'), _tool(1)];
      final result = microCompactEntries(entries, triggerChars: 100000);
      expect(identical(result, entries), isTrue);
    });

    test('超阈值时从最旧开始清可清除工具输出，直到降到阈值内', () {
      final entries = <AgentEvent>[
        for (var i = 0; i < 20; i++) _tool(i),
      ];
      final result = microCompactEntries(entries, triggerChars: 60000);
      expect(totalContextChars(result), lessThanOrEqualTo(60000));
      // 最旧的先被清。
      final first = result.first as ToolCallEvent;
      expect(first.resultDetail, kMicroCompactClearedPlaceholder);
      // 事件流本体（原列表）未被改写。
      expect((entries.first as ToolCallEvent).resultDetail, 'x' * 5000);
    });

    test('最近 N 条工具调用受保护不清（即使仍超阈值）', () {
      final entries = <AgentEvent>[
        for (var i = 0; i < 6; i++) _tool(i, detailChars: 20000),
      ];
      // 阈值极低：即使全清也超，但只允许清到保护窗口前。
      final result = microCompactEntries(
        entries,
        triggerChars: 1,
        keepRecentToolCalls: 5,
      );
      expect(
        (result[0] as ToolCallEvent).resultDetail,
        kMicroCompactClearedPlaceholder,
      );
      for (var i = 1; i < 6; i++) {
        expect((result[i] as ToolCallEvent).resultDetail, 'x' * 20000,
            reason: '近期第 $i 条应受保护');
      }
    });

    test('白名单外工具与小输出不清', () {
      final entries = <AgentEvent>[
        _tool(0, name: 'edit', detailChars: 50000),
        _tool(1, detailChars: 100), // 低于 minClearChars
        _tool(2, detailChars: 50000),
        for (var i = 3; i < 9; i++) _tool(i, detailChars: 10000),
      ];
      final result = microCompactEntries(entries, triggerChars: 1);
      expect((result[0] as ToolCallEvent).resultDetail, 'x' * 50000,
          reason: 'edit 不在白名单');
      expect((result[1] as ToolCallEvent).resultDetail, 'x' * 100,
          reason: '小输出不清');
      expect(
        (result[2] as ToolCallEvent).resultDetail,
        kMicroCompactClearedPlaceholder,
      );
    });

    test('确定性：同一输入两次调用结果一致（引擎/重放两侧无需同步状态）', () {
      final entries = <AgentEvent>[
        _user(0, 'go'),
        for (var i = 1; i < 15; i++) _tool(i),
      ];
      final a = microCompactEntries(entries, triggerChars: 30000);
      final b = microCompactEntries(entries, triggerChars: 30000);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        final ea = a[i];
        final eb = b[i];
        if (ea is ToolCallEvent && eb is ToolCallEvent) {
          expect(ea.resultDetail, eb.resultDetail);
        }
      }
    });

    test('applyToolResultBudget：未超预算原样返回同一实例', () {
      final entries = <AgentEvent>[_user(0, 'hi'), _tool(1)];
      final result = applyToolResultBudget(entries, budgetChars: 100000);
      expect(identical(result, entries), isTrue);
    });

    test('applyToolResultBudget：超预算从最旧省略（不限白名单）到预算内', () {
      final entries = <AgentEvent>[
        _tool(0, name: 'edit', detailChars: 30000),
        for (var i = 1; i < 10; i++) _tool(i, detailChars: 10000),
      ];
      final result = applyToolResultBudget(entries, budgetChars: 60000);
      // edit 不在 microcompact 白名单，但预算兜底照样省略。
      expect(
        (result[0] as ToolCallEvent).resultDetail,
        kToolResultBudgetStub,
      );
      var total = 0;
      for (final e in result) {
        if (e is ToolCallEvent) total += e.resultDetail?.length ?? 0;
      }
      expect(total, lessThanOrEqualTo(60000));
      // 事件流本体未改写。
      expect((entries[0] as ToolCallEvent).resultDetail, 'x' * 30000);
    });

    test('applyToolResultBudget：最近 N 条工具调用受保护', () {
      final entries = <AgentEvent>[
        for (var i = 0; i < 6; i++) _tool(i, detailChars: 20000),
      ];
      final result = applyToolResultBudget(
        entries,
        budgetChars: 1,
        keepRecentToolCalls: 5,
      );
      expect(
        (result[0] as ToolCallEvent).resultDetail,
        kToolResultBudgetStub,
      );
      for (var i = 1; i < 6; i++) {
        expect((result[i] as ToolCallEvent).resultDetail, 'x' * 20000,
            reason: '近期第 $i 条应受保护');
      }
    });

    test('清除只动 resultDetail，其余字段原样保留', () {
      final entries = <AgentEvent>[
        for (var i = 0; i < 8; i++) _tool(i),
      ];
      final result = microCompactEntries(entries, triggerChars: 1);
      final cleared = result[0] as ToolCallEvent;
      final original = entries[0] as ToolCallEvent;
      expect(cleared.id, original.id);
      expect(cleared.toolName, original.toolName);
      expect(cleared.argSummary, original.argSummary);
      expect(cleared.resultSummary, original.resultSummary);
      expect(cleared.argsDetail, original.argsDetail);
    });
  });
}
