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
  injectDepth: depth,
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

  test('system positions wrap the base prompt in priority order', () {
    final entries = [
      entry('B1', position: WorldBookInjectionPosition.beforeSystemPrompt),
      entry('A1', position: WorldBookInjectionPosition.afterSystemPrompt),
      entry('B2', position: WorldBookInjectionPosition.beforeSystemPrompt),
    ];
    expect(WorldBookInjector.injectSystem('base', entries), 'B1\nB2\nbase\nA1');
    expect(WorldBookInjector.injectSystem(null, entries), 'B1\nB2\nA1');
    expect(WorldBookInjector.injectSystem('', entries), 'B1\nB2\nA1');
  });

  test('top and bottom of chat sit at the first / before the last segment', () {
    final out = WorldBookInjector.injectMessages(history, [
      entry('T', position: WorldBookInjectionPosition.topOfChat),
      entry('B', position: WorldBookInjectionPosition.bottomOfChat),
    ]);
    expect(contents(out), [
      '<system>\nT\n</system>',
      'u1',
      'a1',
      '<system>\nB\n</system>',
      'u2',
    ]);
    expect(out.first.role, MessageRole.user);
  });

  test('at depth counts user turns from the end and clamps to the top', () {
    List<String> at(int depth) => contents(
      WorldBookInjector.injectMessages(history, [entry('D', depth: depth)]),
    );
    expect(at(0), ['u1', 'a1', 'u2', '<system>\nD\n</system>']);
    expect(at(1), ['u1', 'a1', '<system>\nD\n</system>', 'u2']);
    expect(at(2), ['<system>\nD\n</system>', 'u1', 'a1', 'u2']);
    expect(at(50), ['<system>\nD\n</system>', 'u1', 'a1', 'u2']);
  });

  test('depth 0 never leaves a trailing assistant message', () {
    final out = WorldBookInjector.injectMessages(history, [
      entry('D', depth: 0, role: WorldBookInjectionRole.assistant),
    ]);
    expect(out.last.role, MessageRole.user);
    expect(out.last.content, '<system>\nD\n</system>');
  });

  test('assistant role keeps raw content; roles merge per slot', () {
    final out = WorldBookInjector.injectMessages(history, [
      entry('X', role: WorldBookInjectionRole.assistant),
      entry('Y'),
      entry('Z', role: WorldBookInjectionRole.assistant),
    ]);
    expect(contents(out), [
      'u1',
      'a1',
      'X\nZ',
      '<system>\nY\n</system>',
      'u2',
    ]);
    expect(out[2].role, MessageRole.assistant);
  });

  test('tool-call segments are never split, at any depth', () {
    final segments = [
      user('u1'),
      toolRound(),
      user('u2'),
      toolRound(),
      user('u3'),
    ];
    for (var depth = 0; depth <= 4; depth++) {
      final out = WorldBookInjector.injectMessages(segments, [
        entry('D', depth: depth),
        entry('B', position: WorldBookInjectionPosition.bottomOfChat),
        entry('T', position: WorldBookInjectionPosition.topOfChat),
      ]);
      for (var i = 0; i < out.length; i++) {
        final calls = out[i].toolCalls;
        if (calls == null || calls.isEmpty) continue;
        for (var k = 0; k < calls.length; k++) {
          expect(out[i + 1 + k].toolCallId, calls[k].id, reason: 'depth $depth');
        }
        expect(out[i + 1 + calls.length].content, 'done');
      }
      expect(out.where((m) => m.content.contains('<system>')), hasLength(3));
    }
  });

  test('empty history still receives chat injections', () {
    final out = WorldBookInjector.injectMessages(const [], [
      entry('D'),
      entry('T', position: WorldBookInjectionPosition.topOfChat),
    ]);
    expect(contents(out), ['<system>\nT\n</system>', '<system>\nD\n</system>']);
  });
}
