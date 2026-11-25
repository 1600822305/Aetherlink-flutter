import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message_segment.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/world_book/application/world_book_injector.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

LlmMessageSegment seg(MessageRole role, String text) => LlmMessageSegment(
  role: role,
  messages: [LlmMessage(role: role, content: text)],
);

const _toolRound = LlmMessageSegment(
  role: MessageRole.assistant,
  messages: [
    LlmMessage(
      role: MessageRole.assistant,
      content: '',
      toolCalls: [LlmToolCall(id: 'c1', name: 'a', arguments: '{}')],
    ),
    LlmMessage(role: MessageRole.user, content: 'r1', toolCallId: 'c1'),
  ],
);

WorldBookEntry at(
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

void main() {
  final history = [
    seg(MessageRole.user, 'u1'),
    seg(MessageRole.assistant, 'a1'),
    seg(MessageRole.user, 'u2'),
  ];

  test('merge is off by default', () {
    final out = WorldBookInjector.injectMessages(history, [at('D')]);
    expect(out, hasLength(4));
  });

  test('production default merges adjacent user turns', () {
    expect(kWorldBookMergeAdjacentUser, isTrue);
  });

  test('user injection folds into the following user turn', () {
    final out = WorldBookInjector.injectMessages(history, [
      at('D'),
    ], mergeAdjacentUser: true);
    expect([for (final m in out) m.content], ['u1', 'a1', 'D\n\nu2']);
  });

  test('depth 0 folds into the preceding user turn', () {
    final out = WorldBookInjector.injectMessages(history, [
      at('Z', depth: 0),
    ], mergeAdjacentUser: true);
    expect(out.last.content, 'u2\n\nZ');
    expect(out, hasLength(3));
  });

  test('never merges into tool results', () {
    final segments = [seg(MessageRole.user, 'u1'), _toolRound];
    final out = WorldBookInjector.injectMessages(segments, [
      at('Z', depth: 0),
      at('A', role: WorldBookInjectionRole.assistant, depth: 0),
    ], mergeAdjacentUser: true);
    // 前一段是工具回合、不是普通用户消息：两条注入都独立放在最后。
    expect(out[1].toolCalls, isNotEmpty);
    expect(out[2].toolCallId, 'c1');
    final tail = out.sublist(3);
    expect([for (final m in tail) m.content], ['Z', '<system>\nA\n</system>']);
    for (final m in tail) {
      expect(m.role, MessageRole.user);
      expect(m.toolCallId, isNull);
    }
  });

  test('assistant-role injection before a user turn keeps its order', () {
    final out = WorldBookInjector.injectMessages(history, [
      at('X', role: WorldBookInjectionRole.assistant),
      at('Y'),
    ], mergeAdjacentUser: true);
    expect([for (final m in out) m.content], ['u1', 'a1', 'X', 'Y\n\nu2']);
  });

  test('native system messages stay standalone; user ones still fold', () {
    final out = WorldBookInjector.injectMessages(
      history,
      [at('S', role: WorldBookInjectionRole.system), at('Y')],
      mergeAdjacentUser: true,
      nativeSystem: true,
    );
    expect([for (final m in out) m.content], ['u1', 'a1', 'S', 'Y\n\nu2']);
    expect(out[2].role, MessageRole.system);
  });
}
