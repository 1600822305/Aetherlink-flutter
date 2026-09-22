import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/features/chat/application/send/chat_error_capture.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/chat_error.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

void main() {
  const capture = ChatErrorCapture(appVersion: '0.7.0+70');
  const provider = ModelProvider(id: 'xai', name: 'xAI', avatar: '', color: '');
  const model = Model(id: 'grok-4.7', name: 'Grok 4.7', provider: 'xai');

  group('ChatErrorCapture.capture', () {
    test('keeps type, message, stack and context', () {
      late StackTrace stack;
      late Object thrown;
      final Object fromJson = 10.0;
      try {
        // The exact cast the pre-c4e615ce web-search tool did on the model's
        // `maxResults` argument.
        final _ = fromJson as int?;
      } on Object catch (e, s) {
        thrown = e;
        stack = s;
      }
      final error = capture.capture(
        thrown,
        stack,
        phase: ChatErrorPhase.tool,
        provider: provider,
        model: model,
        round: 2,
        toolName: 'builtin_web_search',
        toolArguments: {'query': '今天的新闻', 'maxResults': 10.0},
      );
      expect(error.type, thrown.runtimeType.toString());
      expect(error.message, contains("type 'double' is not a subtype"));
      expect(error.stackTrace, contains('chat_error_capture_test.dart'));
      expect(error.providerId, 'xai');
      expect(error.providerName, 'xAI');
      expect(error.modelId, 'grok-4.7');
      expect(error.round, 2);
      expect(error.toolName, 'builtin_web_search');
      expect(error.toolArguments, contains('"maxResults": 10.0'));
      expect(error.appVersion, '0.7.0+70');
      expect(error.platform, isNotEmpty);
    });

    test('unwraps Failure message and NetworkFailure status', () {
      final error = capture.capture(
        const NetworkFailure('Too Many Requests', statusCode: 429),
        null,
        phase: ChatErrorPhase.request,
      );
      expect(error.type, 'NetworkFailure');
      expect(error.message, 'Too Many Requests');
      expect(error.statusCode, 429);
      expect(error.stackTrace, isNull);
    });

    test('treats StackTrace.empty as no stack', () {
      final error = capture.capture(
        StateError('x'),
        StackTrace.empty,
        phase: ChatErrorPhase.stream,
      );
      expect(error.stackTrace, isNull);
    });

    test('falls back to model.provider when no provider is given', () {
      final error = capture.capture(
        StateError('x'),
        null,
        phase: ChatErrorPhase.stream,
        model: model,
      );
      expect(error.providerId, 'xai');
      expect(error.providerName, isNull);
    });

    test('truncates oversized stack traces and messages', () {
      final error = capture.capture(
        Exception('m' * (kChatErrorTextLimit + 100)),
        StackTrace.fromString('#0 frame\n' * 2000),
        phase: ChatErrorPhase.stream,
      );
      expect(error.stackTrace!.length, lessThan(kChatErrorStackLimit + 100));
      expect(error.stackTrace, contains('已截断'));
      expect(error.message, contains('已截断'));
    });

    test('records failover attempts', () {
      final attempt = capture.attempt(
        1,
        const NetworkFailure('401', statusCode: 401),
        keyId: 'k1',
      );
      expect(attempt.attempt, 1);
      expect(attempt.type, 'NetworkFailure');
      expect(attempt.keyId, 'k1');
    });
  });

  group('ChatErrorCapture.redact', () {
    test('masks vendor keys, bearer tokens and key= params', () {
      const text =
          'Authorization: Bearer abcdef1234567890 '
          'sk-proj-ABCDEFGHIJKLMNOPQRSTUVWXYZ '
          'xai-abcdefghijklmnopqrstuvwxyz '
          'AIzaSyA1234567890abcdefghijklmnop '
          'https://api.example.com/v1?key=supersecretvalue123&q=hi '
          '"api_key": "sk-live-000000000000000000"';
      final out = ChatErrorCapture.redact(text);
      expect(out, isNot(contains('abcdef1234567890')));
      expect(out, isNot(contains('ABCDEFGHIJKLMNOPQRSTUVWXYZ')));
      expect(out, isNot(contains('abcdefghijklmnopqrstuvwxyz')));
      expect(out, isNot(contains('1234567890abcdefghijklmnop')));
      expect(out, isNot(contains('supersecretvalue123')));
      expect(out, isNot(contains('000000000000000000')));
      expect(out, contains('key=***'));
      expect(out, contains('&q=hi'));
    });

    test('leaves ordinary text alone', () {
      const text =
          "type 'double' is not a subtype of type 'int?' in type cast "
          'maxResults=10.0 keyboard shortcut';
      expect(ChatErrorCapture.redact(text), text);
    });
  });

  group('ChatError', () {
    test('round-trips through JSON', () {
      final error = capture.capture(
        const NetworkFailure('boom', statusCode: 500),
        StackTrace.current,
        phase: ChatErrorPhase.tool,
        provider: provider,
        model: model,
        round: 1,
        toolName: 't',
        toolArguments: {'a': 1},
        attempts: [capture.attempt(1, StateError('first'), keyId: 'k')],
      );
      expect(ChatError.fromJson(error.toJson()), error);
      expect(error.toJson()['phase'], 'tool');
    });

    test(
      'fromBlock reads structured error and falls back to legacy fields',
      () {
        final now = DateTime(2026, 9, 22);
        final structured = capture.capture(
          StateError('structured'),
          null,
          phase: ChatErrorPhase.stream,
        );
        final block = MessageBlock.error(
          id: 'b',
          messageId: 'm',
          status: MessageBlockStatus.error,
          createdAt: now,
          content: '',
          message: 'structured',
          error: structured.toJson(),
        );
        expect(ChatError.fromBlock(block as ErrorBlock), structured);

        final legacy = MessageBlock.error(
          id: 'b',
          messageId: 'm',
          status: MessageBlockStatus.error,
          createdAt: now,
          content: '',
          message: 'old message',
          code: '429',
        );
        final fromLegacy = ChatError.fromBlock(legacy as ErrorBlock);
        expect(fromLegacy.message, 'old message');
        expect(fromLegacy.statusCode, 429);
        expect(fromLegacy.occurredAt, now);

        final malformed = MessageBlock.error(
          id: 'b',
          messageId: 'm',
          status: MessageBlockStatus.error,
          createdAt: now,
          content: 'raw',
          error: {'phase': 'nope'},
        );
        expect(ChatError.fromBlock(malformed as ErrorBlock).message, 'raw');
      },
    );

    test('toReport contains every section in a stable layout', () {
      final error = ChatError(
        phase: ChatErrorPhase.tool,
        type: 'TypeError',
        message: "type 'double' is not a subtype of type 'int?' in type cast",
        occurredAt: DateTime.utc(2026, 9, 22, 8),
        providerId: 'xai',
        providerName: 'xAI',
        modelId: 'grok-4.7',
        modelName: 'Grok 4.7',
        round: 1,
        toolName: 'builtin_web_search',
        toolArguments: '{\n  "maxResults": 10.0\n}',
        attempts: const [
          ChatErrorAttempt(attempt: 1, type: 'NetworkFailure', message: '401'),
        ],
        stackTrace: '#0 main',
        appVersion: '0.7.0+70',
        platform: 'android 14',
      );
      final report = error.toReport();
      expect(report, startsWith('## AetherLink 错误报告'));
      expect(report, contains('- 阶段: tool'));
      expect(report, contains('- 提供商: xAI (xai)'));
      expect(report, contains('- 模型: Grok 4.7 (grok-4.7)'));
      expect(report, contains('- 工具: builtin_web_search'));
      expect(
        report,
        contains('### 工具参数\n\n```json\n{\n  "maxResults": 10.0\n}\n```'),
      );
      expect(report, contains('- #1 NetworkFailure: 401'));
      expect(report, contains('### 堆栈\n\n```\n#0 main\n```'));
    });

    test('toReport omits absent fields', () {
      final report = ChatError(
        phase: ChatErrorPhase.stream,
        type: 'unknown',
        message: 'm',
        occurredAt: DateTime.utc(2026),
      ).toReport();
      expect(report, isNot(contains('提供商')));
      expect(report, isNot(contains('堆栈')));
      expect(report, isNot(contains('重试')));
      expect(report, endsWith('### 错误信息\n\nm'));
    });
  });
}
