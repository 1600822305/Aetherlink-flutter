import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/provider_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../../support/llm/llm_fixtures.dart';
import '../../../../../../support/llm/mock_sse_server.dart';

/// End-to-end streaming tests for M2 (M4.3 network validation).
///
/// Unlike `llm_adapters_test.dart` (which feeds bytes through a fake dio
/// `HttpClientAdapter`), these drive the **whole chain over a real socket**:
/// `buildLlmDio()` → a localhost [MockSseServer] replaying a recorded fixture →
/// the handwritten [decodeSse] → the protocol adapter → normalised
/// `LlmStreamChunk`s. No UI, no persistence, no real API key. This is the
/// runnable proof that "M2 is alive".
String _text(List<LlmStreamChunk> chunks) =>
    chunks.whereType<LlmTextDelta>().map((c) => c.text).join();

String _reasoning(List<LlmStreamChunk> chunks) =>
    chunks.whereType<LlmReasoningDelta>().map((c) => c.text).join();

LlmDone _done(List<LlmStreamChunk> chunks) =>
    chunks.whereType<LlmDone>().single;

/// Streams [providerType] against [server] through the real factory + dio.
Future<List<LlmStreamChunk>> _stream(
  MockSseServer server,
  String providerType, {
  Dio? dio,
}) {
  final model = llmTestModel(
    providerType: providerType,
    baseUrl: server.baseUri.toString(),
  );
  final gateway = LlmProviderFactory(dio: dio ?? buildLlmDio()).forModel(model);
  return gateway.streamChat(llmTestRequest(model)).toList();
}

/// A valid prefix followed by an unparseable `data:` line, per protocol.
const _malformedBodies = <String, String>{
  'openai':
      'data: {"choices":[{"delta":{"content":"部分"},"finish_reason":null}]}\n'
      '\n'
      'data: {"choices":[{"delta":{"content": NOT_JSON\n'
      '\n',
  'anthropic':
      'event: content_block_delta\n'
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"部分"}}\n'
      '\n'
      'event: content_block_delta\n'
      'data: {"type":"content_block_delta", NOT_JSON\n'
      '\n',
  'gemini':
      'data: {"candidates":[{"content":{"role":"model","parts":[{"text":"部分"}]}}]}\n'
      '\n'
      'data: {"candidates": NOT_JSON\n'
      '\n',
};

/// Text deltas with no terminal event ([DONE] / finishReason / message_stop):
/// the server simply closes the connection afterwards.
const _truncatedBodies = <String, String>{
  'openai':
      'data: {"choices":[{"delta":{"content":"半句"},"finish_reason":null}]}\n'
      '\n'
      'data: {"choices":[{"delta":{"content":"话"},"finish_reason":null}]}\n'
      '\n',
  'anthropic':
      'event: content_block_delta\n'
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"半句"}}\n'
      '\n'
      'event: content_block_delta\n'
      'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"话"}}\n'
      '\n',
  'gemini':
      'data: {"candidates":[{"content":{"role":"model","parts":[{"text":"半句"}]}}]}\n'
      '\n'
      'data: {"candidates":[{"content":{"role":"model","parts":[{"text":"话"}]}}]}\n'
      '\n',
};

void main() {
  group('happy path — recorded fixture over the real chain', () {
    for (final fx in llmFixtureCases) {
      test('${fx.label}: deltas, reasoning, usage and finish reason', () async {
        final server = await MockSseServer.start(body: fx.readBody());
        addTearDown(server.stop);

        final chunks = await _stream(server, fx.providerType);

        expect(_text(chunks), fx.expectedText);
        expect(_reasoning(chunks), fx.expectedReasoning);

        final done = _done(chunks);
        expect(chunks.last, isA<LlmDone>());
        expect(done.finishReason, fx.expectedFinishReason);
        expect(done.usage?.promptTokens, fx.expectedUsage.promptTokens);
        expect(done.usage?.completionTokens, fx.expectedUsage.completionTokens);
        expect(done.usage?.totalTokens, fx.expectedUsage.totalTokens);
      });
    }
  });

  group('request construction over the real socket', () {
    test(
      'OpenAI-compatible posts to /chat/completions with bearer auth',
      () async {
        final server = await MockSseServer.start(body: 'data: [DONE]\n\n');
        addTearDown(server.stop);

        await _stream(server, 'openai');

        final req = server.lastRequest!;
        expect(req.method, 'POST');
        expect(req.uri.path, '/chat/completions');
        expect(req.headers['authorization'], 'Bearer mock-no-key');
        expect(req.body, contains('"stream":true'));
        expect(req.body, contains('"model":"mock-model"'));
        // OpenAI carries the system prompt as a message, not a top-level field.
        expect(req.body, contains('"role":"system"'));
        expect(req.body, contains('"content":"You are a concise assistant."'));
      },
    );

    test(
      'Anthropic posts to /v1/messages with x-api-key and version',
      () async {
        final server = await MockSseServer.start(
          body: 'event: message_stop\ndata: {"type":"message_stop"}\n\n',
        );
        addTearDown(server.stop);

        await _stream(server, 'anthropic');

        final req = server.lastRequest!;
        expect(req.uri.path, '/v1/messages');
        expect(req.headers['x-api-key'], 'mock-no-key');
        expect(req.headers['anthropic-version'], '2023-06-01');
        // Anthropic carries the system prompt as a top-level field.
        expect(req.body, contains('"system":"You are a concise assistant."'));
      },
    );

    test(
      'Gemini posts to :streamGenerateContent?alt=sse with goog key',
      () async {
        final server = await MockSseServer.start(body: '');
        addTearDown(server.stop);

        await _stream(server, 'gemini');

        final req = server.lastRequest!;
        expect(req.uri.path, '/models/mock-model:streamGenerateContent');
        expect(req.uri.queryParameters['alt'], 'sse');
        expect(req.headers['x-goog-api-key'], 'mock-no-key');
      },
    );
  });

  group('empty stream', () {
    for (final fx in llmFixtureCases) {
      test('${fx.label}: yields a single LlmDone and no text', () async {
        final server = await MockSseServer.start(body: '');
        addTearDown(server.stop);

        final chunks = await _stream(server, fx.providerType);

        expect(chunks, hasLength(1));
        expect(chunks.single, isA<LlmDone>());
        expect(_text(chunks), isEmpty);
        expect(_reasoning(chunks), isEmpty);
      });
    }
  });

  group('malformed chunk mid-stream', () {
    for (final entry in _malformedBodies.entries) {
      test(
        '${entry.key}: a bad JSON chunk surfaces as a stream error',
        () async {
          final server = await MockSseServer.start(body: entry.value);
          addTearDown(server.stop);

          await expectLater(
            _stream(server, entry.key),
            throwsA(isA<FormatException>()),
          );
        },
      );
    }
  });

  group('truncated stream — server closes before a terminal event', () {
    for (final entry in _truncatedBodies.entries) {
      test(
        '${entry.key}: partial text is preserved and closed with LlmDone',
        () async {
          final server = await MockSseServer.start(body: entry.value);
          addTearDown(server.stop);

          final chunks = await _stream(server, entry.key);

          expect(_text(chunks), '半句话');
          expect(chunks.last, isA<LlmDone>());
          expect(_done(chunks).finishReason, isNull);
        },
      );
    }
  });

  group('aborted stream — connection dropped mid-body', () {
    for (final providerType in const ['openai', 'anthropic', 'gemini']) {
      test(
        '$providerType: a mid-stream disconnect surfaces as an error',
        () async {
          // No terminal event, so the adapter keeps reading until the socket is
          // dropped — a graceful close would otherwise just end the stream.
          final server = await MockSseServer.start(
            body: _truncatedBodies[providerType]!,
            mode: MockSseMode.abort,
          );
          addTearDown(server.stop);

          await expectLater(_stream(server, providerType), throwsA(anything));
        },
      );
    }
  });

  group('transport errors surface as NetworkFailure', () {
    for (final providerType in const ['openai', 'anthropic', 'gemini']) {
      test('$providerType: HTTP 500 maps to NetworkFailure', () async {
        final server = await MockSseServer.start(
          body: '',
          mode: MockSseMode.errorStatus,
          statusCode: 500,
        );
        addTearDown(server.stop);

        await expectLater(
          _stream(server, providerType),
          throwsA(
            isA<NetworkFailure>().having(
              (f) => f.statusCode,
              'statusCode',
              500,
            ),
          ),
        );
      });
    }

    test('a refused connection maps to NetworkFailure', () async {
      final model = llmTestModel(
        providerType: 'openai',
        baseUrl: 'http://127.0.0.1:1',
      );
      final gateway = LlmProviderFactory(dio: buildLlmDio()).forModel(model);

      await expectLater(
        gateway.streamChat(llmTestRequest(model)).toList(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
