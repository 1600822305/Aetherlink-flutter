import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/send/llm_history_builder.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_type.dart';

/// A vision-capable chat model: the OCR fallback short-circuits before reading
/// any provider, so the builder runs without settings / model stores.
const _model = Model(
  id: 'm',
  name: 'M',
  provider: 'p',
  modelTypes: [ModelType.chat, ModelType.vision],
);

final _ts = DateTime.utc(2026);

MessageBlock _text(String id, String content) => MessageBlock.mainText(
  id: id,
  messageId: 'x',
  status: MessageBlockStatus.success,
  createdAt: _ts,
  content: content,
);

MessageBlock _tool(String id, {String? round, String? mode}) =>
    MessageBlock.tool(
  id: 'b-$id',
  messageId: 'x',
  status: MessageBlockStatus.success,
  createdAt: _ts,
  toolId: id,
  toolName: 'tool_$id',
  arguments: {'q': id},
  content: 'result $id',
  metadata: {
    if (round != null) kToolRoundMetadataKey: round,
    if (mode != null) kToolModeMetadataKey: mode,
  },
);

ChatMessageView _view(
  String id,
  MessageRole role, {
  String text = '',
  List<MessageBlock> blocks = const [],
}) => ChatMessageView(
  id: id,
  role: role,
  status: MessageStatus.success,
  text: text,
  blocks: blocks,
);

/// Field-wise snapshot so the comparison never depends on equality semantics.
List<String> _snapshot(List<LlmMessage> messages) => [
  for (final m in messages)
    jsonEncode({
      'role': m.role.name,
      'content': m.content,
      'images': m.images?.length,
      'toolCalls': [
        for (final c in m.toolCalls ?? const []) [c.id, c.name, c.arguments],
      ],
      'toolCallId': m.toolCallId,
      'toolName': m.toolName,
    }),
];

final _builderProvider = Provider<LlmHistoryBuilder>(
  (ref) => LlmHistoryBuilder(() => ref),
);

void main() {
  late ProviderContainer container;
  late LlmHistoryBuilder builder;

  setUp(() {
    container = ProviderContainer();
    builder = container.read(_builderProvider);
  });

  tearDown(() => container.dispose());

  final views = [
    _view('u1', MessageRole.user, text: 'hello'),
    _view('a0', MessageRole.assistant),
    _view(
      'a1',
      MessageRole.assistant,
      text: 'checking',
      blocks: [
        _text('t1', 'checking'),
        _tool('c1', round: 'r1'),
        _tool('c2', round: 'r1'),
        _text('t2', 'found it'),
      ],
    ),
    _view('u2', MessageRole.user, text: 'again'),
    _view(
      'a2',
      MessageRole.assistant,
      blocks: [_tool('c3', mode: 'prompt'), _text('t3', 'ok')],
    ),
    _view('u3', MessageRole.user, text: 'thanks'),
  ];

  test('flattened segments equal the pinned buildLlmMessages output', () async {
    final messages = await builder.buildLlmMessages(
      views,
      chatModel: _model,
      toolMode: McpMode.function,
    );
    final segments = await builder.buildLlmMessageSegments(
      views,
      chatModel: _model,
      toolMode: McpMode.function,
    );
    expect(
      _snapshot([for (final s in segments) ...s.messages]),
      _snapshot(messages),
    );
    // Pinned pre-refactor shape: the empty assistant is dropped, the
    // function-call round keeps call→results adjacent, the prompt-mode round
    // becomes <tool_use> + a user result.
    expect([for (final m in messages) m.role.name], [
      'user',
      'assistant',
      'user',
      'user',
      'assistant',
      'user',
      'assistant',
      'user',
      'assistant',
      'user',
    ]);
    expect(messages[1].content, 'checking');
    expect(messages[1].toolCalls!.map((c) => c.id), ['c1', 'c2']);
    expect(messages[2].toolCallId, 'c1');
    expect(messages[3].toolCallId, 'c2');
    expect(messages[4].content, 'found it');
    expect(messages[6].content, contains('<tool_use>'));
    expect(messages[7].toolCallId, isNull);
    expect(messages.last.content, 'thanks');
  });

  test('one segment per serialised view, carrying the view role', () async {
    final segments = await builder.buildLlmMessageSegments(
      views,
      chatModel: _model,
      toolMode: McpMode.function,
    );
    expect([for (final s in segments) s.role.name], [
      'user',
      'assistant',
      'user',
      'assistant',
      'user',
    ]);
    expect(segments[1].messages, hasLength(4));
  });

  test('dropEmptyAssistant=false keeps the empty assistant segment', () async {
    final messages = await builder.buildLlmMessages(
      views.take(2),
      chatModel: _model,
      toolMode: McpMode.function,
      dropEmptyAssistant: false,
    );
    expect(messages.map((m) => m.role), [
      MessageRole.user,
      MessageRole.assistant,
    ]);
  });
}
