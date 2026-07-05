import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';

/// A reasoning open/close tag pair a model may inline in its answer text.
class ReasoningTagPair {
  const ReasoningTagPair(this.opening, this.closing);

  final String opening;
  final String closing;
}

/// Tags recognised by default, mirroring the web's `DEFAULT_REASONING_TAGS`
/// (e.g. MiniMax-M 系列 / Qwen3 inline `<think>`, some gateways `<thinking>` /
/// `<reasoning>`).
const List<ReasoningTagPair> kDefaultReasoningTags = [
  ReasoningTagPair('<think>', '</think>'),
  ReasoningTagPair('<thinking>', '</thinking>'),
  ReasoningTagPair('<reasoning>', '</reasoning>'),
];

/// Splits inline reasoning tags out of streamed answer text: content inside a
/// [ReasoningTagPair] becomes [LlmReasoningDelta], everything else stays
/// [LlmTextDelta]. Stateful across chunks — a tag split over several deltas is
/// still matched, by holding back a small unemitted tail until it can be ruled
/// out as a tag prefix. Port of the web `ThinkTagParser`.
class ReasoningTagParser {
  ReasoningTagParser({this.tags = kDefaultReasoningTags})
    : _maxOpeningLength = tags
          .map((t) => t.opening.length)
          .reduce((a, b) => a > b ? a : b);

  final List<ReasoningTagPair> tags;
  final int _maxOpeningLength;

  final StringBuffer _pending = StringBuffer();
  ReasoningTagPair? _active;

  /// Consumes one answer-text delta and returns the chunks safe to emit now.
  List<LlmStreamChunk> processText(String text) {
    _pending.write(text);
    final out = <LlmStreamChunk>[];
    var buffer = _pending.toString();
    var progressed = true;

    while (progressed && buffer.isNotEmpty) {
      progressed = false;
      final active = _active;

      if (active == null) {
        // Outside a tag: route text up to the earliest opening tag, keeping a
        // tail that could still turn out to be a split tag.
        ReasoningTagPair? found;
        var foundAt = -1;
        for (final tag in tags) {
          final at = buffer.indexOf(tag.opening);
          if (at != -1 && (foundAt == -1 || at < foundAt)) {
            found = tag;
            foundAt = at;
          }
        }
        if (found != null) {
          if (foundAt > 0) out.add(LlmStreamChunk.textDelta(buffer.substring(0, foundAt)));
          _active = found;
          buffer = buffer.substring(foundAt + found.opening.length);
          progressed = true;
        } else if (buffer.length > _maxOpeningLength + 5) {
          final safe = buffer.length - (_maxOpeningLength + 5);
          out.add(LlmStreamChunk.textDelta(buffer.substring(0, safe)));
          buffer = buffer.substring(safe);
          progressed = true;
        }
      } else {
        // Inside a tag: route reasoning up to the closing tag, same holdback.
        final at = buffer.indexOf(active.closing);
        if (at != -1) {
          if (at > 0) out.add(LlmStreamChunk.reasoningDelta(buffer.substring(0, at)));
          _active = null;
          buffer = buffer.substring(at + active.closing.length);
          progressed = true;
        } else if (buffer.length > active.closing.length + 5) {
          final safe = buffer.length - (active.closing.length + 5);
          out.add(LlmStreamChunk.reasoningDelta(buffer.substring(0, safe)));
          buffer = buffer.substring(safe);
          progressed = true;
        }
      }
    }

    _pending
      ..clear()
      ..write(buffer);
    return out;
  }

  /// Drains the held-back tail — call before any non-text event (tool call /
  /// done) so ordering is preserved. Inside an unclosed tag the remainder
  /// counts as reasoning, mirroring the web parser's flush.
  List<LlmStreamChunk> flush() {
    if (_pending.isEmpty) return const [];
    final rest = _pending.toString();
    _pending.clear();
    return [
      if (_active != null)
        LlmStreamChunk.reasoningDelta(rest)
      else
        LlmStreamChunk.textDelta(rest),
    ];
  }
}

/// Decorates an [LlmGateway] with [ReasoningTagParser] so models that inline
/// their thinking as `<think>…</think>` in the answer stream (instead of a
/// dedicated `reasoning_content` field) still render a folded thinking card.
class ReasoningTagGateway implements LlmGateway {
  ReasoningTagGateway(this._inner);

  final LlmGateway _inner;

  @override
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  }) async* {
    final parser = ReasoningTagParser();
    await for (final chunk in _inner.streamChat(
      request,
      cancelToken: cancelToken,
    )) {
      switch (chunk) {
        case LlmTextDelta(:final text):
          for (final split in parser.processText(text)) {
            yield split;
          }
        // Native reasoning passes through untouched; it goes to a separate
        // block, so it never needs the held-back text tail flushed first.
        case LlmReasoningDelta():
          yield chunk;
        case LlmToolCallChunk():
        case LlmDone():
          for (final split in parser.flush()) {
            yield split;
          }
          yield chunk;
      }
    }
  }
}
