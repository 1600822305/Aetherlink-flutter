import 'dart:io';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';

/// Expected token usage a fixture's terminal event should normalise to.
class ExpectedUsage {
  const ExpectedUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
}

/// A recorded happy-path SSE stream for one wire protocol, plus the normalised
/// [LlmStreamChunk] values the M2 chain should produce from it.
///
/// Shared by the E2E integration test and the `bin/llm_smoke.dart` dev entry so
/// both assert/print against the same source of truth. Lives in `test/support`
/// per `docs/TESTING.md` §2 (recorded responses are shared test doubles).
class LlmFixtureCase {
  const LlmFixtureCase({
    required this.label,
    required this.providerType,
    required this.fixtureFile,
    required this.expectedText,
    required this.expectedReasoning,
    required this.expectedFinishReason,
    required this.expectedUsage,
  });

  /// Human-readable protocol name for test/print output.
  final String label;

  /// `Model.providerType` value that routes to this protocol's adapter.
  final String providerType;

  /// File under `test/support/llm/fixtures/` holding the raw SSE body.
  final String fixtureFile;

  /// Accumulated `LlmTextDelta` text the fixture should yield.
  final String expectedText;

  /// Accumulated `LlmReasoningDelta` text the fixture should yield.
  final String expectedReasoning;

  /// `LlmDone.finishReason` the fixture should yield.
  final String expectedFinishReason;

  /// `LlmDone.usage` the fixture should yield.
  final ExpectedUsage expectedUsage;

  /// Reads the raw recorded SSE body from disk.
  String readBody() => readSseFixture(fixtureFile);
}

/// The three recorded happy-path streams — one per wire protocol (ADR-0006).
const llmFixtureCases = <LlmFixtureCase>[
  LlmFixtureCase(
    label: 'OpenAI-compatible',
    providerType: 'openai',
    fixtureFile: 'openai_compatible.sse',
    expectedText: '你好，世界！',
    expectedReasoning: '先想一下用户在问什么。好,可以回答了。',
    expectedFinishReason: 'stop',
    expectedUsage: ExpectedUsage(
      promptTokens: 11,
      completionTokens: 7,
      totalTokens: 18,
    ),
  ),
  LlmFixtureCase(
    label: 'Anthropic',
    providerType: 'anthropic',
    fixtureFile: 'anthropic.sse',
    expectedText: '你好，朋友',
    expectedReasoning: '先组织一下措辞。',
    expectedFinishReason: 'end_turn',
    expectedUsage: ExpectedUsage(
      promptTokens: 14,
      completionTokens: 6,
      totalTokens: 20,
    ),
  ),
  LlmFixtureCase(
    label: 'Gemini',
    providerType: 'gemini',
    fixtureFile: 'gemini.sse',
    expectedText: '你好，世界',
    expectedReasoning: '让我先想想。',
    expectedFinishReason: 'STOP',
    expectedUsage: ExpectedUsage(
      promptTokens: 8,
      completionTokens: 3,
      totalTokens: 11,
    ),
  ),
];

/// Builds a [Model] pointed at a local mock server. No real key or endpoint —
/// [providerType] selects the protocol adapter, [baseUrl] points at the mock.
Model llmTestModel({
  required String providerType,
  required String baseUrl,
  String id = 'mock-model',
  String apiKey = 'mock-no-key',
}) {
  return Model(
    id: id,
    name: id,
    provider: providerType,
    providerType: providerType,
    apiKey: apiKey,
    baseUrl: baseUrl,
  );
}

/// A small, provider-neutral chat request used to drive the adapters.
LlmChatRequest llmTestRequest(Model model) {
  return LlmChatRequest(
    model: model,
    system: 'You are a concise assistant.',
    messages: const [LlmMessage(role: MessageRole.user, content: '你好')],
    temperature: 0.3,
    maxTokens: 128,
  );
}

/// Reads a recorded SSE body from `test/support/llm/fixtures/`.
///
/// Resolves the path from the package root (located by walking up to the
/// nearest `pubspec.yaml`) so it works under both `flutter test` and
/// `dart run bin/llm_smoke.dart` regardless of the current directory.
String readSseFixture(String file) {
  final path = '${_packageRoot().path}/test/support/llm/fixtures/$file';
  final fixture = File(path);
  if (!fixture.existsSync()) {
    throw StateError('SSE fixture not found: $path');
  }
  return fixture.readAsStringSync();
}

Directory _packageRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current;
    }
    dir = parent;
  }
}
