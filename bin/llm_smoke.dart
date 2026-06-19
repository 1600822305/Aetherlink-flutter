import 'dart:io';

import 'package:aetherlink_flutter/core/network/dio_client.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/provider_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';

import '../test/support/llm/llm_fixtures.dart';
import '../test/support/llm/mock_sse_server.dart';

/// Dev smoke entry for M2 streaming — a runnable "M2 is alive" proof that needs
/// no UI and no real API key.
///
/// For each wire protocol it boots a local [MockSseServer] replaying a recorded
/// fixture, streams it through the real `buildLlmDio()` + `decodeSse` + adapter
/// chain, and prints the streamed text as it arrives.
///
/// The switch is **off by default** (so it never runs as a side effect). Turn
/// it on with either:
///   dart run bin/llm_smoke.dart --run
///   dart run --define=llm_smoke=true bin/llm_smoke.dart
const _enabledByDefine = bool.fromEnvironment('llm_smoke');

const _usage = '''
llm_smoke — M2 streaming smoke test (off by default)

Streams the recorded SSE fixtures through the real dio + decodeSse + adapter
chain against a local mock server. No UI, no real API key.

Enable with one of:
  dart run bin/llm_smoke.dart --run
  dart run --define=llm_smoke=true bin/llm_smoke.dart
''';

Future<void> main(List<String> args) async {
  final enabled =
      _enabledByDefine || args.contains('--run') || args.contains('--all');
  if (!enabled) {
    stdout.write(_usage);
    return;
  }

  stdout.writeln('M2 streaming smoke — mock server, no real key, no UI.\n');

  var allOk = true;
  for (final fx in llmFixtureCases) {
    final ok = await _smokeOne(fx);
    allOk = allOk && ok;
  }

  stdout.writeln('');
  if (allOk) {
    stdout.writeln(
      'M2 streaming chain: ALIVE — '
      'all ${llmFixtureCases.length} protocols streamed as expected.',
    );
  } else {
    stdout.writeln('M2 streaming chain: MISMATCH — see above.');
    exitCode = 1;
  }
}

Future<bool> _smokeOne(LlmFixtureCase fx) async {
  final server = await MockSseServer.start(body: fx.readBody());
  try {
    final model = llmTestModel(
      providerType: fx.providerType,
      baseUrl: server.baseUri.toString(),
    );
    final gateway = LlmProviderFactory(dio: buildLlmDio()).forModel(model);

    final text = StringBuffer();
    final reasoning = StringBuffer();
    String? finishReason;
    var usageText = 'n/a';

    stdout.writeln('── ${fx.label}  (${server.baseUri}) ──');
    var deltaCount = 0;
    await for (final chunk in gateway.streamChat(llmTestRequest(model))) {
      switch (chunk) {
        case LlmTextDelta(text: final delta):
          text.write(delta);
          deltaCount++;
        case LlmReasoningDelta(text: final delta):
          reasoning.write(delta);
        case LlmToolCallChunk():
          break;
        case LlmDone(usage: final usage, finishReason: final reason):
          finishReason = reason;
          if (usage != null) {
            usageText =
                '${usage.promptTokens}/${usage.completionTokens}/${usage.totalTokens}';
          }
      }
    }

    stdout.writeln('  text ($deltaCount deltas): $text');
    stdout.writeln('  reasoning: ${reasoning.isEmpty ? '(none)' : reasoning}');
    stdout.writeln('  finishReason: $finishReason   usage(p/c/t): $usageText');

    final ok =
        text.toString() == fx.expectedText &&
        reasoning.toString() == fx.expectedReasoning &&
        finishReason == fx.expectedFinishReason;
    stdout.writeln('  => ${ok ? 'PASS' : 'MISMATCH'}\n');
    return ok;
  } finally {
    await server.stop();
  }
}
