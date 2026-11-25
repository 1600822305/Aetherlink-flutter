// @深度注入（world_book_injector.dart），对照 SillyTavern chat completion 的
// `populationInjectionPrompts`：深度按消息计、同一深度按 assistant / user / system
// 合成消息、深的在前；以及本应用的供应商兼容（system 降级、深度 0 不留助手预填）。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message_segment.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/world_book/application/world_book_injector.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

LlmMessageSegment user(String text) => LlmMessageSegment(
  role: MessageRole.user,
  messages: [LlmMessage(role: MessageRole.user, content: text)],
);

LlmMessageSegment assistant(String text) => LlmMessageSegment(
  role: MessageRole.assistant,
  messages: [LlmMessage(role: MessageRole.assistant, content: text)],
);

/// One assistant view holding a function-call round: the call, two results,
/// and the trailing prose — exactly what `toolHistoryMessages` emits.
LlmMessageSegment toolRound() => const LlmMessageSegment(
  role: MessageRole.assistant,
  messages: [
    LlmMessage(
      role: MessageRole.assistant,
      content: '',
      toolCalls: [
        LlmToolCall(id: 'c1', name: 'a', arguments: '{}'),
        LlmToolCall(id: 'c2', name: 'b', arguments: '{}'),
      ],
    ),
    LlmMessage(role: MessageRole.user, content: 'r1', toolCallId: 'c1'),
    LlmMessage(role: MessageRole.user, content: 'r2', toolCallId: 'c2'),
    LlmMessage(role: MessageRole.assistant, content: 'done'),
  ],
);

WorldBookEntry entry(
  String content, {
  WorldBookInjectionPosition position = WorldBookInjectionPosition.atDepth,
  int depth = 1,
  WorldBookInjectionRole role = WorldBookInjectionRole.user,
}) => WorldBookEntry(
  id: content,
  content: content,
  position: position,
  depth: depth,
  role: role,
);

List<String> contents(List<LlmMessage> messages) =>
    [for (final m in messages) m.content];

void main() {
  final history = [user('u1'), assistant('a1'), user('u2')];

  test('nothing triggered returns the flattened input unchanged', () {
    expect(
      WorldBookInjector.injectMessages(history, const []),
      [for (final s in history) ...s.messages],
    );
    expect(WorldBookInjector.injectSystem('base', const []), 'base');
    expect(WorldBookInjector.injectSystem(null, const []), isNull);
  });

  test('system positions wrap the base prompt in injection order', () {
    final entries = [
      entry('B1', position: WorldBookInjectionPosition.beforeSystemPrompt),
      entry('A1', position: WorldBookInjectionPosition.afterSystemPrompt),
      entry('B2', position: WorldBookInjectionPosition.beforeSystemPrompt),
    ];
    expect(WorldBookInjector.injectSystem('base', entries), 'B1\nB2\nbase\nA1');
    expect(WorldBookInjector.injectSystem(null, entries), 'B1\nB2\nA1');
    expect(WorldBookInjector.injectSystem('', entries), 'B1\nB2\nA1');
  });

  test('深度按消息计：深度 n 插在最后 n 条之前，不够时放到最前', () {
    List<String> at(int depth) => contents(
      WorldBookInjector.injectMessages(history, [entry('D', depth: depth)]),
    );
    expect(at(0), ['u1', 'a1', 'u2', 'D']);
    expect(at(1), ['u1', 'a1', 'D', 'u2']);
    expect(at(2), ['u1', 'D', 'a1', 'u2']);
    expect(at(3), ['D', 'u1', 'a1', 'u2']);
    expect(at(50), ['D', 'u1', 'a1', 'u2']);

    final longer = [user('u1'), assistant('a1'), user('u2'), assistant('a2'), user('u3')];
    expect(
      contents(WorldBookInjector.injectMessages(longer, [entry('D', depth: 2)])),
      ['u1', 'a1', 'u2', 'D', 'a2', 'u3'],
    );
  });

  test('user 角色原样作为用户消息插入', () {
    final out = WorldBookInjector.injectMessages(history, [entry('U')]);
    expect(out[2].role, MessageRole.user);
    expect(out[2].content, 'U');
  });

  test('同一深度按 assistant、user、system 的顺序各合成一条', () {
    final out = WorldBookInjector.injectMessages(history, [
      entry('S1', role: WorldBookInjectionRole.system),
      entry('U1'),
      entry('A1', role: WorldBookInjectionRole.assistant),
      entry('U2'),
      entry('A2', role: WorldBookInjectionRole.assistant),
    ], nativeSystem: true);
    expect(contents(out), ['u1', 'a1', 'A1\nA2', 'U1\nU2', 'S1', 'u2']);
    expect([for (final m in out.sublist(2, 5)) m.role], [
      MessageRole.assistant,
      MessageRole.user,
      MessageRole.system,
    ]);
  });

  test('不同深度落在同一位置时深的在前', () {
    final out = WorldBookInjector.injectMessages(history, [
      entry('X', depth: 5),
      entry('Y', depth: 9),
    ]);
    expect(contents(out), ['Y', 'X', 'u1', 'a1', 'u2']);
  });

  group('供应商兼容', () {
    test('nativeSystem 时 system 角色原样发送', () {
      final out = WorldBookInjector.injectMessages(history, [
        entry('S', role: WorldBookInjectionRole.system),
      ], nativeSystem: true);
      expect(out[2].role, MessageRole.system);
      expect(out[2].content, 'S');
    });

    test('否则 system 改为 user 并包在 <system> 里', () {
      final out = WorldBookInjector.injectMessages(history, [
        entry('S', role: WorldBookInjectionRole.system),
        entry('U'),
      ]);
      expect(contents(out), ['u1', 'a1', 'U', '<system>\nS\n</system>', 'u2']);
      expect(out[3].role, MessageRole.user);
    });

    test('深度 0 的 assistant 按 system 处理，末尾不会是助手消息', () {
      final degraded = WorldBookInjector.injectMessages(history, [
        entry('D', depth: 0, role: WorldBookInjectionRole.assistant),
      ]);
      expect(degraded.last.role, MessageRole.user);
      expect(degraded.last.content, '<system>\nD\n</system>');
      final native = WorldBookInjector.injectMessages(history, [
        entry('D', depth: 0, role: WorldBookInjectionRole.assistant),
      ], nativeSystem: true);
      expect(native.last.role, MessageRole.system);
    });
  });

  test('tool-call segments are never split, at any depth', () {
    final segments = [
      user('u1'),
      toolRound(),
      user('u2'),
      toolRound(),
      user('u3'),
    ];
    for (var depth = 0; depth <= 5; depth++) {
      final out = WorldBookInjector.injectMessages(segments, [
        entry('D', depth: depth),
        entry('E', depth: depth + 1),
        entry('S', depth: depth, role: WorldBookInjectionRole.system),
      ]);
      for (var i = 0; i < out.length; i++) {
        final calls = out[i].toolCalls;
        if (calls == null || calls.isEmpty) continue;
        for (var k = 0; k < calls.length; k++) {
          expect(out[i + 1 + k].toolCallId, calls[k].id, reason: 'depth $depth');
        }
        expect(out[i + 1 + calls.length].content, 'done');
      }
      final all = contents(out);
      expect(all, containsAll(['D', 'E', '<system>\nS\n</system>']), reason: 'depth $depth');
    }
  });

  test('positions without a counterpart in this app are not injected', () {
    final skipped = [
      WorldBookInjectionPosition.authorNoteTop,
      WorldBookInjectionPosition.authorNoteBottom,
      WorldBookInjectionPosition.examplesBefore,
      WorldBookInjectionPosition.examplesAfter,
      WorldBookInjectionPosition.outlet,
    ];
    final entries = [for (final p in skipped) entry('X', position: p)];
    expect(
      WorldBookInjector.injectMessages(history, entries),
      [for (final s in history) ...s.messages],
    );
    expect(WorldBookInjector.injectSystem('base', entries), 'base');
  });

  test('empty history still receives chat injections', () {
    final out = WorldBookInjector.injectMessages(const [], [entry('D')]);
    expect(contents(out), ['D']);
  });
}
