import 'dart:convert';
import 'dart:typed_data';

import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/adapters/anthropic_adapter.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/adapters/gemini_adapter.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/adapters/openai_compatible_adapter.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/llm_protocol.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/provider_factory.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/reasoning_tag_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_content_image.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// A dio [HttpClientAdapter] that replays a recorded SSE body instead of
/// hitting the network. It deliberately emits the bytes in two chunks so the
/// handwritten SSE decoder is exercised across chunk boundaries, and captures
/// the outgoing request so adapters' body/header/url construction can be
/// asserted. No API key or socket is involved.
class _ReplayAdapter implements HttpClientAdapter {
  _ReplayAdapter(this.sse);

  final String sse;
  RequestOptions? request;
  String requestBody = '';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      requestBody = utf8.decode(chunks.expand((c) => c).toList());
    }

    final bytes = utf8.encode(sse);
    final mid = bytes.length ~/ 2;
    final stream = Stream<Uint8List>.fromIterable([
      Uint8List.fromList(bytes.sublist(0, mid)),
      Uint8List.fromList(bytes.sublist(mid)),
    ]);
    return ResponseBody(
      stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }
}

Model _model({
  required String provider,
  String id = 'test-model',
  String baseUrl = 'https://api.example.test/v1',
  String apiKey = 'secret-key',
}) {
  return Model(
    id: id,
    name: id,
    provider: provider,
    providerType: provider,
    apiKey: apiKey,
    baseUrl: baseUrl,
  );
}

LlmChatRequest _request(Model model) {
  return LlmChatRequest(
    model: model,
    system: 'You are concise.',
    messages: const [LlmMessage(role: MessageRole.user, content: 'Hi')],
    temperature: 0.5,
    maxTokens: 256,
  );
}

Dio _dioWith(_ReplayAdapter adapter) => Dio()..httpClientAdapter = adapter;

String _text(List<LlmStreamChunk> chunks) =>
    chunks.whereType<LlmTextDelta>().map((c) => c.text).join();

String _reasoning(List<LlmStreamChunk> chunks) =>
    chunks.whereType<LlmReasoningDelta>().map((c) => c.text).join();

LlmDone _done(List<LlmStreamChunk> chunks) =>
    chunks.whereType<LlmDone>().single;

void main() {
  group('OpenAiCompatibleAdapter', () {
    const sse = '''
data: {"choices":[{"delta":{"reasoning_content":"Let me think. "},"finish_reason":null}]}

data: {"choices":[{"delta":{"reasoning_content":"Done thinking."},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}

data: {"choices":[{"delta":{"content":", world!"},"finish_reason":null}]}

data: {"choices":[{"delta":{},"finish_reason":"stop"}]}

data: {"choices":[],"usage":{"prompt_tokens":12,"completion_tokens":8,"total_tokens":20}}

data: [DONE]
''';

    test('maps content/reasoning deltas, usage and finish_reason', () async {
      final adapter = _ReplayAdapter(sse);
      final gateway = OpenAiCompatibleAdapter(_dioWith(adapter));

      final chunks = await gateway
          .streamChat(_request(_model(provider: 'openai')))
          .toList();

      expect(chunks.map((c) => c.runtimeType).toList(), <Type>[
        LlmReasoningDelta,
        LlmReasoningDelta,
        LlmTextDelta,
        LlmTextDelta,
        LlmDone,
      ]);
      expect(_text(chunks), 'Hello, world!');
      expect(_reasoning(chunks), 'Let me think. Done thinking.');

      final done = _done(chunks);
      expect(done.finishReason, 'stop');
      expect(done.usage?.promptTokens, 12);
      expect(done.usage?.completionTokens, 8);
      expect(done.usage?.totalTokens, 20);

      // Request was built correctly without touching the network.
      expect(
        adapter.request!.uri.toString(),
        'https://api.example.test/v1/chat/completions',
      );
      expect(adapter.request!.headers['Authorization'], 'Bearer secret-key');
      expect(adapter.requestBody, contains('"stream":true'));
      expect(adapter.requestBody, contains('"model":"test-model"'));
    });

    test('appends /v1 to a versionless baseUrl; # opts out', () async {
      // Bare host → /v1 auto-appended (Cherry formatApiHost parity).
      final a1 = _ReplayAdapter(sse);
      await OpenAiCompatibleAdapter(_dioWith(a1))
          .streamChat(_request(_model(
            provider: 'openai',
            baseUrl: 'https://api.example.test',
          )))
          .toList();
      expect(
        a1.request!.uri.toString(),
        'https://api.example.test/v1/chat/completions',
      );

      // Trailing # → exact base, no /v1.
      final a2 = _ReplayAdapter(sse);
      await OpenAiCompatibleAdapter(_dioWith(a2))
          .streamChat(_request(_model(
            provider: 'openai',
            baseUrl: 'https://api.example.test#',
          )))
          .toList();
      expect(
        a2.request!.uri.toString(),
        'https://api.example.test/chat/completions',
      );
    });

    test('extracts text from content parts and message fallback', () async {
      const partsAndMessageSse = '''
data: {"choices":[{"delta":{"content":[{"type":"text","text":"Hello"},{"type":"image_url","image_url":{"url":"data:image/png;base64,AA=="}},{"type":"text","delta":", parts"}]},"finish_reason":null}]}

data: {"choices":[{"message":{"role":"assistant","content":[{"type":"text","text":" and message"}]},"finish_reason":"stop"}]}

data: [DONE]
''';
      final adapter = _ReplayAdapter(partsAndMessageSse);
      final gateway = OpenAiCompatibleAdapter(_dioWith(adapter));

      final chunks = await gateway
          .streamChat(_request(_model(provider: 'openai')))
          .toList();

      expect(_text(chunks), 'Hello, parts and message');
      expect(_done(chunks).finishReason, 'stop');
    });

    test('extracts Responses text from completed event fallback', () async {
      const completedOnlySse = '''
data: {"type":"response.completed","response":{"output":[{"type":"message","content":[{"type":"output_text","text":"completed text"}]}],"usage":{"input_tokens":3,"output_tokens":2,"total_tokens":5}}}

data: [DONE]
''';
      final adapter = _ReplayAdapter(completedOnlySse);
      final gateway = OpenAiCompatibleAdapter(_dioWith(adapter));

      final chunks = await gateway
          .streamChat(
            _request(
              _model(
                provider: 'openai',
                baseUrl: 'https://api.example.test/v1',
              ),
            ).copyWith(useResponsesAPI: true),
          )
          .toList();

      expect(_text(chunks), 'completed text');
      final done = _done(chunks);
      expect(done.finishReason, 'stop');
      expect(done.usage?.totalTokens, 5);
      expect(
        adapter.request!.uri.toString(),
        'https://api.example.test/v1/responses',
      );
    });
  });

  group('AnthropicAdapter', () {
    const sse = '''
event: message_start
data: {"type":"message_start","message":{"usage":{"input_tokens":15,"output_tokens":0}}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"I should greet. "}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" there"}}

event: message_delta
data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":5}}

event: message_stop
data: {"type":"message_stop"}
''';

    test('maps text/thinking deltas, split usage and stop_reason', () async {
      final adapter = _ReplayAdapter(sse);
      final gateway = AnthropicAdapter(_dioWith(adapter));

      final chunks = await gateway
          .streamChat(
            _request(
              _model(
                provider: 'anthropic',
                baseUrl: 'https://api.anthropic.test',
              ),
            ),
          )
          .toList();

      expect(chunks.map((c) => c.runtimeType).toList(), <Type>[
        LlmReasoningDelta,
        LlmTextDelta,
        LlmTextDelta,
        LlmDone,
      ]);
      expect(_text(chunks), 'Hi there');
      expect(_reasoning(chunks), 'I should greet. ');

      final done = _done(chunks);
      expect(done.finishReason, 'end_turn');
      expect(done.usage?.promptTokens, 15);
      expect(done.usage?.completionTokens, 5);
      expect(done.usage?.totalTokens, 20);

      expect(
        adapter.request!.uri.toString(),
        'https://api.anthropic.test/v1/messages',
      );
      expect(adapter.request!.headers['x-api-key'], 'secret-key');
      expect(adapter.request!.headers['anthropic-version'], '2023-06-01');
      // System prompt is a top-level field, not a message.
      expect(adapter.requestBody, contains('"system":"You are concise."'));
    });

    test('cacheControl marks system, last tool and user turns', () async {
      final adapter = _ReplayAdapter(sse);
      final gateway = AnthropicAdapter(_dioWith(adapter));

      final request = LlmChatRequest(
        model: _model(
          provider: 'anthropic',
          baseUrl: 'https://api.anthropic.test',
        ),
        system: 'You are concise.',
        cacheControl: true,
        messages: const [
          LlmMessage(role: MessageRole.user, content: 'First'),
          LlmMessage(role: MessageRole.assistant, content: 'Ok'),
          LlmMessage(role: MessageRole.user, content: 'Second'),
        ],
        tools: const [
          McpToolDefinition(name: 'a', description: 'a', inputSchema: {}),
          McpToolDefinition(name: 'b', description: 'b', inputSchema: {}),
        ],
      );
      await gateway.streamChat(request).toList();

      final body = jsonDecode(adapter.requestBody) as Map<String, dynamic>;
      const ephemeral = {'type': 'ephemeral'};

      final system = body['system'] as List;
      expect((system.single as Map)['cache_control'], ephemeral);

      final tools = body['tools'] as List;
      expect((tools[0] as Map).containsKey('cache_control'), isFalse);
      expect((tools[1] as Map)['cache_control'], ephemeral);

      // Both user turns get a breakpoint; the assistant turn stays a string.
      final messages = body['messages'] as List;
      final first = (messages[0] as Map)['content'] as List;
      expect((first.single as Map)['cache_control'], ephemeral);
      expect((messages[1] as Map)['content'], 'Ok');
      final second = (messages[2] as Map)['content'] as List;
      expect((second.single as Map)['cache_control'], ephemeral);
    });
  });

  group('GeminiAdapter', () {
    const sse = '''
data: {"candidates":[{"content":{"role":"model","parts":[{"text":"Thinking about it. ","thought":true}]}}]}

data: {"candidates":[{"content":{"role":"model","parts":[{"text":"Hey"}]}}]}

data: {"candidates":[{"content":{"role":"model","parts":[{"text":" friend"}]},"finishReason":"STOP"}],"usageMetadata":{"promptTokenCount":9,"candidatesTokenCount":4,"totalTokenCount":13}}
''';

    test('maps thought/text parts, usageMetadata and finishReason', () async {
      final adapter = _ReplayAdapter(sse);
      final gateway = GeminiAdapter(_dioWith(adapter));

      final chunks = await gateway
          .streamChat(
            _request(
              _model(provider: 'gemini', baseUrl: 'https://gemini.test/v1beta'),
            ),
          )
          .toList();

      expect(chunks.map((c) => c.runtimeType).toList(), <Type>[
        LlmReasoningDelta,
        LlmTextDelta,
        LlmTextDelta,
        LlmDone,
      ]);
      expect(_text(chunks), 'Hey friend');
      expect(_reasoning(chunks), 'Thinking about it. ');

      final done = _done(chunks);
      expect(done.finishReason, 'STOP');
      expect(done.usage?.promptTokens, 9);
      expect(done.usage?.completionTokens, 4);
      expect(done.usage?.totalTokens, 13);

      expect(
        adapter.request!.uri.toString(),
        'https://gemini.test/v1beta/models/test-model:streamGenerateContent?alt=sse',
      );
      expect(adapter.request!.headers['x-goog-api-key'], 'secret-key');
    });
  });

  group('image (vision) serialization', () {
    LlmChatRequest imageRequest(Model model, {bool responses = false}) {
      return LlmChatRequest(
        model: model,
        system: 'You are concise.',
        messages: const [
          LlmMessage(
            role: MessageRole.user,
            content: 'What is this?',
            images: [
              LlmContentImage(mimeType: 'image/png', base64Data: 'AAAA'),
            ],
          ),
        ],
        useResponsesAPI: responses,
      );
    }

    test('OpenAI chat completions emits an image_url content part', () async {
      final adapter = _ReplayAdapter('data: [DONE]\n');
      final gateway = OpenAiCompatibleAdapter(_dioWith(adapter));

      await gateway.streamChat(imageRequest(_model(provider: 'openai'))).drain<void>();

      expect(adapter.requestBody, contains('"type":"image_url"'));
      expect(
        adapter.requestBody,
        contains('data:image/png;base64,AAAA'),
      );
      expect(adapter.requestBody, contains('"type":"text","text":"What is this?"'));
    });

    test('OpenAI Responses emits an input_image content part', () async {
      final adapter = _ReplayAdapter('data: [DONE]\n');
      final gateway = OpenAiCompatibleAdapter(_dioWith(adapter));

      await gateway
          .streamChat(imageRequest(_model(provider: 'openai'), responses: true))
          .drain<void>();

      expect(adapter.requestBody, contains('"type":"input_image"'));
      expect(adapter.requestBody, contains('data:image/png;base64,AAAA'));
    });

    test('Anthropic emits a base64 image source block', () async {
      final adapter = _ReplayAdapter(
        'event: message_stop\ndata: {"type":"message_stop"}\n',
      );
      final gateway = AnthropicAdapter(_dioWith(adapter));

      await gateway
          .streamChat(imageRequest(_model(provider: 'anthropic')))
          .drain<void>();

      expect(adapter.requestBody, contains('"type":"image"'));
      expect(adapter.requestBody, contains('"media_type":"image/png"'));
      expect(adapter.requestBody, contains('"data":"AAAA"'));
    });

    test('Gemini emits an inlineData part', () async {
      final adapter = _ReplayAdapter(
        'data: {"candidates":[{"content":{"role":"model","parts":[{"text":"ok"}]},"finishReason":"STOP"}]}\n',
      );
      final gateway = GeminiAdapter(_dioWith(adapter));

      await gateway.streamChat(imageRequest(_model(provider: 'gemini'))).drain<void>();

      expect(adapter.requestBody, contains('"inlineData"'));
      expect(adapter.requestBody, contains('"mimeType":"image/png"'));
      expect(adapter.requestBody, contains('"data":"AAAA"'));
    });
  });

  group('protocol routing', () {
    test('groups vendors by protocol family (not one adapter per vendor)', () {
      expect(
        protocolForModel(_model(provider: 'openai')),
        LlmProtocol.openaiCompatible,
      );
      expect(
        protocolForModel(_model(provider: 'dashscope')),
        LlmProtocol.openaiCompatible,
      );
      expect(
        protocolForModel(_model(provider: 'grok')),
        LlmProtocol.openaiCompatible,
      );
      expect(
        protocolForModel(_model(provider: 'deepseek')),
        LlmProtocol.openaiCompatible,
      );
      expect(
        protocolForModel(_model(provider: 'anthropic')),
        LlmProtocol.anthropic,
      );
      expect(protocolForModel(_model(provider: 'gemini')), LlmProtocol.gemini);
    });

    test('factory returns the adapter for each protocol', () {
      final factory = LlmProviderFactory(dio: Dio());

      expect(
        factory.forModel(_model(provider: 'dashscope')),
        isA<ReasoningTagGateway>(),
      );
      expect(
        factory.forModel(_model(provider: 'anthropic')),
        isA<AnthropicAdapter>(),
      );
      expect(
        factory.forModel(_model(provider: 'gemini')),
        isA<ReasoningTagGateway>(),
      );
    });
  });
}
