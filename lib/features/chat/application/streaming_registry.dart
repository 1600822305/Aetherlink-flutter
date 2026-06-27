import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/shared/services/streaming_keepalive_service.dart';

part 'streaming_registry.g.dart';

/// Immutable snapshot of which topics are currently generating a reply and the
/// latest live view of each one.
///
/// Streaming is decoupled from "which topic is on screen": the [ChatController]
/// writes the in-flight conversation for a topic here (keyed by topic id) on
/// every chunk, regardless of whether that topic is the one being displayed.
/// This mirrors the web original, where messages live in a per-topic store and
/// the message list merely subscribes to the current topic — so switching
/// topics mid-stream is instant, the old topic keeps generating in the
/// background, and the topic list can show a "generating" indicator (the green
/// dot) by reading [isStreaming] per topic.
class StreamingRegistryState {
  const StreamingRegistryState({
    this.liveByTopic = const <String, List<ChatMessageView>>{},
  });

  /// Latest live conversation snapshot per streaming topic. A topic's presence
  /// here means it is currently generating.
  final Map<String, List<ChatMessageView>> liveByTopic;

  /// Whether [topicId] currently has a reply being generated.
  bool isStreaming(String topicId) => liveByTopic.containsKey(topicId);

  /// The latest live conversation for [topicId], or `null` when not streaming.
  List<ChatMessageView>? viewsFor(String topicId) => liveByTopic[topicId];
}

/// Keep-alive registry of in-flight streams keyed by topic id.
///
/// Holds both the rendered live views (immutable [state], drives the green dot
/// and switch-back) and the per-topic [LlmCancelToken] handles (kept off the
/// rebuild path) so a topic's stream can be aborted independently.
@Riverpod(keepAlive: true)
class StreamingRegistry extends _$StreamingRegistry {
  final Map<String, LlmCancelToken> _tokens = <String, LlmCancelToken>{};

  @override
  StreamingRegistryState build() => const StreamingRegistryState();

  /// Records the latest live [views] for [topicId], marking it as streaming.
  /// Starts the background keep-alive service when the first topic begins.
  void update(String topicId, List<ChatMessageView> views) {
    final wasIdle = state.liveByTopic.isEmpty;
    final next = Map<String, List<ChatMessageView>>.of(state.liveByTopic);
    next[topicId] = List<ChatMessageView>.of(views);
    state = StreamingRegistryState(liveByTopic: next);
    if (wasIdle) unawaited(StreamingKeepAliveService.begin());
  }

  /// Clears [topicId]'s streaming state (it finished, was stopped, or errored).
  /// Stops the keep-alive service once no topic is streaming.
  void finish(String topicId) {
    _tokens.remove(topicId);
    if (!state.liveByTopic.containsKey(topicId)) return;
    final next = Map<String, List<ChatMessageView>>.of(state.liveByTopic)
      ..remove(topicId);
    state = StreamingRegistryState(liveByTopic: next);
    if (next.isEmpty) unawaited(StreamingKeepAliveService.end());
  }

  /// Binds the cancellation handle for [topicId]'s in-flight request so
  /// [cancel] can abort it.
  void bindToken(String topicId, LlmCancelToken token) {
    _tokens[topicId] = token;
  }

  /// Aborts [topicId]'s in-flight request, if any.
  void cancel(String topicId) {
    final token = _tokens[topicId];
    if (token == null || token.isCancelled) return;
    token.cancel();
  }
}
