import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/reasoning_tag_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements LlmGateway {
  _FakeGateway(this.chunks);

  final List<LlmStreamChunk> chunks;

  @override
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  }) =>
      Stream.fromIterable(chunks);
}

LlmChatRequest _request() => const LlmChatRequest(
  model: Model(id: 'm', name: 'm', provider: 'p'),
  messages: [],
);

Future<(String text, String reasoning)> _collect(
  List<LlmStreamChunk> chunks,
) async {
  final gateway = ReasoningTagGateway(_FakeGateway(chunks));
  final text = StringBuffer();
  final reasoning = StringBuffer();
  await for (final chunk in gateway.streamChat(_request())) {
    switch (chunk) {
      case LlmTextDelta(text: final delta):
        text.write(delta);
      case LlmReasoningDelta(text: final delta):
        reasoning.write(delta);
      case LlmToolCallDelta():
      case LlmToolCallChunk():
      case LlmDone():
        break;
    }
  }
  return (text.toString(), reasoning.toString());
}

void main() {
  group('ReasoningTagGateway', () {
    test('splits inline <think> into reasoning', () async {
      final (text, reasoning) = await _collect([
        const LlmStreamChunk.textDelta('<think>deep thought</think>你好！'),
        const LlmStreamChunk.done(),
      ]);
      expect(reasoning, 'deep thought');
      expect(text, '你好！');
    });

    test('matches a tag split across chunks', () async {
      final (text, reasoning) = await _collect([
        const LlmStreamChunk.textDelta('<th'),
        const LlmStreamChunk.textDelta('ink>a'),
        const LlmStreamChunk.textDelta('b</th'),
        const LlmStreamChunk.textDelta('ink>after'),
        const LlmStreamChunk.done(),
      ]);
      expect(reasoning, 'ab');
      expect(text, 'after');
    });

    test('passes tag-free text through unchanged', () async {
      final (text, reasoning) = await _collect([
        const LlmStreamChunk.textDelta('plain '),
        const LlmStreamChunk.textDelta('answer'),
        const LlmStreamChunk.done(),
      ]);
      expect(reasoning, isEmpty);
      expect(text, 'plain answer');
    });

    test('flushes an unclosed tag as reasoning', () async {
      final (text, reasoning) = await _collect([
        const LlmStreamChunk.textDelta('<think>never closed'),
        const LlmStreamChunk.done(),
      ]);
      expect(reasoning, 'never closed');
      expect(text, isEmpty);
    });

    test('keeps native reasoning deltas untouched', () async {
      final (text, reasoning) = await _collect([
        const LlmStreamChunk.reasoningDelta('native'),
        const LlmStreamChunk.textDelta('answer'),
        const LlmStreamChunk.done(),
      ]);
      expect(reasoning, 'native');
      expect(text, 'answer');
    });
  });
}
