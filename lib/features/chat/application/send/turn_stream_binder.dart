import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/send/llm_history_builder.dart';
import 'package:aetherlink_flutter/features/chat/application/streaming_registry.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_confirmation.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_executor.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_manager.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_prompt.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/running_commands_service.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_auth_policy.dart'
    show toolAuthPolicyProvider;
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart'
    show terminalCommandIsHighRisk;

/// Raised when a provider has a multi-key pool but every key is disabled,
/// errored or still cooling down and there is no single-key fallback — surfaced
/// as the assistant message's error so the user knows to re-enable / add a key.
class NoUsableApiKeyException implements Exception {
  const NoUsableApiKeyException();

  @override
  String toString() => '没有可用的 API Key：所有 Key 已禁用、失败或处于冷却中。';
}

/// Drives one assistant reply's stream: the gateway subscription + MCP
/// tool-call loop (multi-key load balancing / failover, thinking blocks,
/// checkpoint persistence, auto-continue, terminal persistence). Extracted from
/// the `_ChatStreaming` part of [ChatController]; state mutations and post-turn
/// side effects are injected as callbacks so the binder stays a stateless
/// collaborator (aligned with the agent engine's `loop/turn_stream_binder`).
/// The [Ref] is a getter callback because the controller's Ref is replaced on
/// every provider rebuild while a turn routinely spans rebuilds.
class TurnStreamBinder {
  const TurnStreamBinder(
    this._refOf, {
    required ChatToolExecutor Function() toolExecutor,
    required StreamingRegistry Function() registry,
    required void Function(
      String turnTopicId,
      List<ChatMessageView> views, {
      required bool streaming,
    })
    emitTurn,
    required void Function(List<ChatMessageView> views, ChatMessageView view)
    replace,
    required Future<ChatMessageView> Function(
      String messageId,
      ChatMessageView fallback,
    )
    reloadView,
    required Future<void> Function({
      required String messageId,
      required MessageStatus status,
      required List<MessageBlock> blocks,
      Usage? usage,
      Metrics? metrics,
    })
    persistMessageBlocks,
    required String Function(Object error) errorMessage,
    required void Function(String messageId) markTruncated,
    required Future<void> Function(String turnTopicId) refreshTopicPreview,
    required Future<void> Function(String turnTopicId) generateTitle,
    required Future<void> Function(
      String turnTopicId,
      List<ChatMessageView> views,
    )
    maybeGenerateSuggestions,
    required Future<void> Function(String turnTopicId) maybeExtractMemory,
  }) : _toolExecutorOf = toolExecutor,
       _registryOf = registry,
       _emitTurn = emitTurn,
       _replace = replace,
       _reloadView = reloadView,
       _persistMessageBlocks = persistMessageBlocks,
       _errorMessage = errorMessage,
       _markTruncated = markTruncated,
       _refreshTopicPreview = refreshTopicPreview,
       _generateTitle = generateTitle,
       _maybeGenerateSuggestions = maybeGenerateSuggestions,
       _maybeExtractMemory = maybeExtractMemory;

  final Ref Function() _refOf;
  final ChatToolExecutor Function() _toolExecutorOf;
  final StreamingRegistry Function() _registryOf;
  final void Function(
    String turnTopicId,
    List<ChatMessageView> views, {
    required bool streaming,
  })
  _emitTurn;
  final void Function(List<ChatMessageView> views, ChatMessageView view)
  _replace;
  final Future<ChatMessageView> Function(
    String messageId,
    ChatMessageView fallback,
  )
  _reloadView;
  final Future<void> Function({
    required String messageId,
    required MessageStatus status,
    required List<MessageBlock> blocks,
    Usage? usage,
    Metrics? metrics,
  })
  _persistMessageBlocks;
  final String Function(Object error) _errorMessage;
  final void Function(String messageId) _markTruncated;
  final Future<void> Function(String turnTopicId) _refreshTopicPreview;
  final Future<void> Function(String turnTopicId) _generateTitle;
  final Future<void> Function(String turnTopicId, List<ChatMessageView> views)
  _maybeGenerateSuggestions;
  final Future<void> Function(String turnTopicId) _maybeExtractMemory;

  Ref get _ref => _refOf();
  ChatToolExecutor get _toolExecutor => _toolExecutorOf();
  StreamingRegistry get _registry => _registryOf();

  /// The most rounds the tool-call loop will run before forcing a final answer.
  /// Raised to 25 to match the web's agentic mode; complex multi-tool tasks
  /// (e.g. "create a provider and add 3 models") easily exceed 5 rounds.
  static const int _kMaxToolRounds = 25;

  /// How many times we auto-continue when the model hits the token limit
  /// (`finishReason == 'length'`). After exhaustion the message is persisted
  /// with `metadata['truncated'] = true` so the UI can show a
  /// "继续生成" button.
  static const int _kMaxAutoContinues = 3;

  /// 流式过程中把已生成内容检查点写入数据库的最小间隔。对齐 Cherry Studio 的
  /// 崩溃安全策略：闪退/被系统杀死时最多丢最后几秒的增量，而不是整轮回复
  /// （MCP 工具执行可能耗时数分钟，期间尤其需要落盘）。
  static const Duration _kCheckpointInterval = Duration(seconds: 2);

  /// Subscribes to the gateway stream for [request] and drives the MCP tool-call
  /// loop. Each round accumulates assistant text into a `main_text` block and
  /// reasoning into a single `thinking` card; if the model asks for a tool
  /// ([mcp] decides whether that arrives as a function-calling [LlmToolCall] or
  /// as parsed `<tool_use>` XML in 提示词注入 mode), each runnable built-in is
  /// executed locally, rendered as a `tool` block, and its result is appended to
  /// the conversation so the model can continue — up to [_kMaxToolRounds]. When
  /// no (more) tools are requested the turn finalizes: blocks are persisted and
  /// the view reloaded; a stream error keeps any completed blocks and appends an
  /// `error` block. Shared by [send], [regenerate] and [resend].
  Future<void> streamInto({
    required String turnTopicId,
    required LlmChatRequest request,
    required Model effective,
    required ModelProvider provider,
    required String assistantMessageId,
    required String assistantBlockId,
    required DateTime assistantTime,
    required List<ChatMessageView> views,
    required ChatMessageView assistantView,
    required McpSetup mcp,
    List<MessageBlock> leadingBlocks = const <MessageBlock>[],
    // When false this stream is one sibling of a multi-model turn: it persists
    // its own message and updates its own view but does NOT end the topic's
    // streaming state or run the once-per-turn side effects (title / 建议模型 /
    // preview / memory) — the coordinator does that after all siblings settle.
    bool finalizeTurn = true,
  }) async {
    // 帧级合并：SSE delta 的到达速率可远高于屏幕刷新率，两次 vsync 之间的
    // 多个 delta 合并为一次 emit：空闲时的首个 delta 立即发射（leading edge，
    // 无可感知延迟），已有帧在排时后续 delta 挂到下一帧的 frame callback——
    // 合帧窗口严格等于一个 vsync 周期，自适应 60/90/120Hz，不再写死 8ms。
    // 这不是旧的 100ms 节流——每一帧依然拿到最新内容，只是不再在一帧内
    // 重复构建同一个气泡。
    int? pendingEmitFrame;
    // 纯 Dart 测试环境没有 binding（也就没有 vsync），此时退化为每个 delta
    // 直接 emit。
    SchedulerBinding? frameScheduler;
    try {
      frameScheduler = SchedulerBinding.instance;
    } catch (_) {
      frameScheduler = null;
    }
    void cancelScheduledUpdate() {
      if (pendingEmitFrame != null) {
        frameScheduler?.cancelFrameCallbackWithId(pendingEmitFrame!);
        pendingEmitFrame = null;
      }
    }

    // Terminal emit at the end of *this* stream. For a single-model turn it ends
    // the topic's streaming state (streaming:false → registry.finish); for a
    // multi-model sibling it keeps the turn alive (streaming:true) so the other
    // siblings stay visible until the coordinator finishes.
    void emitTurnEnd() {
      cancelScheduledUpdate();
      _emitTurn(turnTopicId, views, streaming: !finalizeTurn);
    }

    // Multi-key load balancing + failover. When the provider carries a multi-key
    // pool, each attempt strategy-selects a usable key ([ApiKeyManager]); a
    // connection-time failure (before anything streamed) fails over to the next
    // usable key, and per-key usage/cooldown is recorded then persisted through
    // the model store so the multi-key UI's stats reflect real traffic. With no
    // pool this collapses to a single attempt on [effective]'s key — the
    // original single-key behaviour. Mirrors the web `EnhancedApiProvider`.
    final keyManager = ApiKeyManager.instance;
    final keyPool = provider.apiKeys ?? const <ApiKeyConfig>[];
    final keyConfig = provider.keyManagement;
    // 单 Key 模式（keyManagement.enabled == false）下池数据保留但不参与请求。
    final useKeyPool = keyPool.isNotEmpty && (keyConfig?.enabled ?? true);
    final keyStrategy = keyConfig?.strategy ?? 'round_robin';
    final hasSingleKeyFallback = (effective.apiKey ?? '').trim().isNotEmpty;
    // Every pool key gets at most one try per send (failed keys are excluded
    // from re-selection below), plus one trailing slot for the single-key
    // fallback when the whole pool is unusable.
    final maxAttempts = useKeyPool ? keyPool.length + 1 : 1;
    final workingKeys = List<ApiKeyConfig>.of(keyPool);
    final failedKeyIds = <String>{};
    final keyUpdates = <String, ApiKeyConfig>{};

    Future<void> persistKeyUpdates() async {
      if (keyUpdates.isEmpty) return;
      await _ref
          .read(modelStoreProvider.notifier)
          .updateApiKeys(
            providerId: provider.id,
            keys: keyUpdates.values.toList(),
          );
    }

    void recordKeyOutcome(
      int index, {
      required bool success,
      bool rateLimited = false,
      String? error,
    }) {
      if (index < 0 || index >= workingKeys.length) return;
      final updated = keyManager.updateKeyStatus(
        workingKeys[index],
        success: success,
        rateLimited: rateLimited,
        config: keyConfig,
        error: error,
      );
      workingKeys[index] = updated;
      keyUpdates[updated.id] = updated;
    }

    // Each tool round finalizes its thinking into a separate ThinkingBlock in
    // [completed], mirroring the web's BlockStateManager.resetThinkingBlock().
    // [thinking] holds only the *current* round's reasoning; once the round
    // ends with tool calls it is flushed into [completed] and cleared so the
    // next round gets a fresh block.
    final thinking = StringBuffer();
    var thinkingBlockId = '$assistantMessageId::thinking';
    // Reasoning timing for the current round's thinking block: [thinkingStartAt]
    // is the first reasoning token (excludes time-to-first-token), [thinkingEndAt]
    // is the first answer/tool chunk (reasoning stopped growing). Their delta is
    // the pure thinking duration, frozen so the timer doesn't run until the whole
    // reply finishes. Both reset whenever a new thinking block starts.
    DateTime? thinkingStartAt;
    DateTime? thinkingEndAt;
    // Seed with the leading memory-injection block (if any) so it stays first
    // in every live/persisted block list — aggregateText/aggregateThinking
    // ignore it (it is neither MainText nor Thinking).
    final completed = <MessageBlock>[...leadingBlocks];
    var messages = List<LlmMessage>.of(request.messages);
    var view = assistantView;

    // The first round streams into the placeholder block already attached to the
    // message; later rounds mint a fresh id.
    var roundBlockId = assistantBlockId;
    final buffer = StringBuffer();

    // Token usage / latency for the finished reply, mirroring the web message's
    // `usage` + `metrics`: [capturedUsage] is the most recent provider usage
    // ([LlmDone]); [firstTokenMs] is time-to-first-token; [stopwatch] times the
    // whole reply. All reset per failover attempt.
    final stopwatch = Stopwatch();
    Usage? capturedUsage;
    int? firstTokenMs;

    String roundDisplay() => mcp.usePromptInjection
        ? removeToolUseTags(buffer.toString())
        : buffer.toString();

    // [completed] 只会整体重置或尾部追加，所以已完成块的聚合前缀按长度缓存，
    // 每个 delta 只拼接当前轮的增量，不再全量 join。
    var aggregatedForCount = -1;
    var completedTextPrefix = '';
    var completedThinkingPrefix = '';
    void refreshAggregatePrefixes() {
      if (completed.length == aggregatedForCount) return;
      aggregatedForCount = completed.length;
      completedTextPrefix = <String>[
        for (final block in completed)
          if (block is MainTextBlock && block.content.isNotEmpty) block.content,
      ].join('\n\n');
      completedThinkingPrefix = <String>[
        for (final block in completed)
          if (block is ThinkingBlock && block.content.isNotEmpty) block.content,
      ].join('\n\n');
    }

    String aggregateText(String current) {
      refreshAggregatePrefixes();
      if (current.isEmpty) return completedTextPrefix;
      if (completedTextPrefix.isEmpty) return current;
      return '$completedTextPrefix\n\n$current';
    }

    String aggregateThinking() {
      refreshAggregatePrefixes();
      final current = thinking.toString();
      if (current.isEmpty) return completedThinkingPrefix;
      if (completedThinkingPrefix.isEmpty) return current;
      return '$completedThinkingPrefix\n\n$current';
    }

    void update() {
      cancelScheduledUpdate();
      final current = roundDisplay();
      final liveBlocks = <MessageBlock>[
        ...completed,
        if (thinking.isNotEmpty)
          MessageBlock.thinking(
            id: thinkingBlockId,
            messageId: assistantMessageId,
            status: thinkingEndAt == null
                ? MessageBlockStatus.streaming
                : MessageBlockStatus.success,
            // Count from the first reasoning token, not message creation.
            createdAt: thinkingStartAt ?? assistantTime,
            updatedAt: thinkingEndAt,
            thinkingMillsec: thinkingStartAt != null && thinkingEndAt != null
                ? thinkingEndAt.difference(thinkingStartAt).inMilliseconds
                : null,
            content: thinking.toString(),
          ),
        MessageBlock.mainText(
          id: roundBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.streaming,
          createdAt: assistantTime,
          content: current,
        ),
      ];
      view = view.copyWith(
        text: aggregateText(current),
        thinking: aggregateThinking(),
        blocks: liveBlocks,
      );
      _replace(views, view);
      _emitTurn(turnTopicId, views, streaming: true);
    }

    void scheduleUpdate() {
      if (pendingEmitFrame != null) return;
      final scheduler = frameScheduler;
      // Leading edge：无 binding，或空闲且没有帧在排时直接发射（emit 本身会把
      // 下一帧排上，后续 delta 自然落入下面的合帧分支）。
      if (scheduler == null ||
          (scheduler.schedulerPhase == SchedulerPhase.idle &&
              !scheduler.hasScheduledFrame)) {
        update();
        return;
      }
      pendingEmitFrame = scheduler.scheduleFrameCallback((_) {
        pendingEmitFrame = null;
        update();
      });
    }

    // 崩溃安全检查点（对齐 Cherry Studio）：把目前已生成的块（完成块 + 进行中的
    // thinking / 正文）以 streaming 状态写入数据库，让闪退/杀进程只丢最后一个
    // 节流窗口内的增量。写入串行排队（chained future），保证与终态落盘不交错；
    // 终态落盘前先 await [checkpointChain] 再整体覆盖。检查点失败只记录不打断
    // 流式（落盘是尽力而为的兜底，不能影响正常回复）。
    var checkpointChain = Future<void>.value();
    var lastCheckpointAt = DateTime.fromMillisecondsSinceEpoch(0);

    List<MessageBlock> checkpointBlocks() {
      final current = roundDisplay();
      return <MessageBlock>[
        ...completed,
        if (thinking.isNotEmpty)
          MessageBlock.thinking(
            id: thinkingBlockId,
            messageId: assistantMessageId,
            status: MessageBlockStatus.streaming,
            createdAt: thinkingStartAt ?? assistantTime,
            content: thinking.toString(),
          ),
        if (current.isNotEmpty)
          MessageBlock.mainText(
            id: roundBlockId,
            messageId: assistantMessageId,
            status: MessageBlockStatus.streaming,
            createdAt: assistantTime,
            content: current,
          ),
      ];
    }

    void checkpoint({bool force = false}) {
      if (!force &&
          DateTime.now().difference(lastCheckpointAt) < _kCheckpointInterval) {
        return;
      }
      lastCheckpointAt = DateTime.now();
      final blocks = checkpointBlocks();
      checkpointChain = checkpointChain.then((_) async {
        try {
          await _persistMessageBlocks(
            messageId: assistantMessageId,
            status: MessageStatus.streaming,
            blocks: blocks,
          );
        } on Object catch (_) {
          // Best-effort durability; never disrupt the live stream.
        }
      });
    }

    // Finalize an aborted turn: keep whatever streamed so far (flush the live
    // thinking + prose into [completed]) and persist as a normal success, then
    // drop the streaming state. Mirrors Cherry Studio — Stop preserves output.
    Future<void> persistStopped() async {
      stopwatch.stop();
      if (thinking.isNotEmpty) {
        completed.add(
          _thinkingBlock(
            messageId: assistantMessageId,
            createdAt: assistantTime,
            content: thinking.toString(),
            startedAt: thinkingStartAt,
            endedAt: thinkingEndAt ?? DateTime.now(),
          ),
        );
        thinking.clear();
      }
      final partial = roundDisplay();
      if (partial.isNotEmpty || completed.isEmpty) {
        completed.add(
          _mainTextBlock(
            id: roundBlockId,
            messageId: assistantMessageId,
            createdAt: assistantTime,
            content: partial,
          ),
        );
      }
      _ref.read(toolConfirmationProvider.notifier).rejectAll();
      _ref.read(runningCommandsProvider.notifier).cancelAll();
      await checkpointChain;
      await _persistMessageBlocks(
        messageId: assistantMessageId,
        status: MessageStatus.success,
        usage: capturedUsage,
        metrics: Metrics(
          latency: stopwatch.elapsedMilliseconds,
          firstTokenLatency: firstTokenMs,
        ),
        blocks: [...completed],
      );
      await persistKeyUpdates();
      view = await _reloadView(assistantMessageId, view);
      _replace(views, view);
      emitTurnEnd();
      if (finalizeTurn) unawaited(_refreshTopicPreview(turnTopicId));
    }

    final cancelToken = LlmCancelToken();
    _registry.bindToken(turnTopicId, cancelToken);
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // Pick the key for this attempt. With a pool: strategy-select a usable
      // key; if none is usable, fall back once to the single [effective] key
      // (mirroring the web `enableFallback`), else surface 没有可用的 Key.
      var effectiveForAttempt = effective;
      var selectedIndex = -1;
      var isFallbackAttempt = false;
      if (useKeyPool) {
        final selected = keyManager.selectApiKey(
          workingKeys,
          keyStrategy,
          excludeIds: failedKeyIds,
          config: keyConfig,
        );
        if (selected != null) {
          selectedIndex = workingKeys.indexWhere((k) => k.id == selected.id);
          effectiveForAttempt = effective.copyWith(apiKey: selected.key);
        } else if (hasSingleKeyFallback) {
          effectiveForAttempt = effective;
          isFallbackAttempt = true;
        } else {
          lastError ??= const NoUsableApiKeyException();
          break;
        }
      }

      final gateway = _ref
          .read(llmGatewayFactoryProvider)
          .forModel(effectiveForAttempt);

      // Reset the per-attempt accumulators so a failover retry starts clean,
      // re-seeding the leading memory-injection block so it survives retries.
      thinking.clear();
      thinkingBlockId = '$assistantMessageId::thinking';
      thinkingStartAt = null;
      thinkingEndAt = null;
      completed
        ..clear()
        ..addAll(leadingBlocks);
      aggregatedForCount = -1;
      buffer.clear();
      messages = List<LlmMessage>.of(request.messages);
      view = assistantView;
      roundBlockId = assistantBlockId;
      capturedUsage = null;
      firstTokenMs = null;
      stopwatch
        ..reset()
        ..start();
      // Once any chunk has streamed we are committed to this attempt: failing
      // over would duplicate already-rendered output, so we only retry on a
      // failure that happens before the first chunk.
      var committed = false;

      try {
        var autoContinueCount = 0;
        // Index in [messages] of the assistant partial fed back for auto-
        // continue, so consecutive continuations replace it (one assistant
        // message holding the full accumulated prose) instead of stacking
        // overlapping copies.
        var continuationIndex = -1;
        for (var round = 0; ; round++) {
          // NB: [buffer] is NOT cleared here — an auto-continue round resumes
          // into the same buffer/block so the reply stays one seamless
          // MainText. Tool rounds clear it below after flushing prose, and
          // each failover attempt resets it before the loop.
          String? lastFinishReason;
          final structuredCalls = <LlmToolCall>[];
          await for (final chunk in gateway.streamChat(
            request.copyWith(messages: messages, model: effectiveForAttempt),
            cancelToken: cancelToken,
          )) {
            switch (chunk) {
              case LlmTextDelta(:final text):
                committed = true;
                firstTokenMs ??= stopwatch.elapsedMilliseconds;
                if (thinking.isNotEmpty) thinkingEndAt ??= DateTime.now();
                buffer.write(text);
                scheduleUpdate();
                checkpoint();
              case LlmReasoningDelta(:final text):
                committed = true;
                firstTokenMs ??= stopwatch.elapsedMilliseconds;
                thinkingStartAt ??= DateTime.now();
                thinking.write(text);
                scheduleUpdate();
                checkpoint();
              case LlmToolCallDelta():
                break;
              case LlmToolCallChunk(:final call):
                committed = true;
                if (thinking.isNotEmpty) thinkingEndAt ??= DateTime.now();
                structuredCalls.add(call);
              case LlmDone(:final usage, :final finishReason):
                if (usage != null) capturedUsage = usage;
                lastFinishReason = finishReason;
                break;
            }
          }

          final roundText = buffer.toString();
          // 提示词注入 mode parses the model's XML; function mode gets the calls as
          // structured stream events.
          final requested = mcp.usePromptInjection
              ? [
                  for (final use in parseToolUseBlocks(roundText, mcp.tools))
                    LlmToolCall(
                      id: '',
                      name: use.name,
                      arguments: use.arguments,
                    ),
                ]
              : structuredCalls;
          final runnable = <LlmToolCall>[
            for (final call in requested)
              if (mcp.routes.containsKey(call.name)) call,
          ];

          // No (more) tools to run, or the round budget is spent: this round's
          // prose is the final answer — unless the model was truncated
          // (finishReason == 'length'), in which case we auto-continue.
          if (runnable.isEmpty || round >= _kMaxToolRounds - 1) {
            final truncated = lastFinishReason == 'length';

            // Auto-continue: append partial output as assistant message and
            // re-request so the model resumes from the truncation point.
            if (truncated && autoContinueCount < _kMaxAutoContinues) {
              autoContinueCount++;
              // The partial prose stays in [buffer] (same block id): the
              // continuation appends to it seamlessly, so no '\n\n' seam is
              // introduced mid-sentence by aggregateText's join.
              final partial = roundDisplay();
              if (thinking.isNotEmpty) {
                completed.add(
                  _thinkingBlock(
                    messageId: assistantMessageId,
                    createdAt: assistantTime,
                    content: thinking.toString(),
                    startedAt: thinkingStartAt,
                    endedAt: thinkingEndAt,
                  ),
                );
                thinking.clear();
                thinkingBlockId = generateId('thinking');
                thinkingStartAt = null;
                thinkingEndAt = null;
              }
              // Feed partial output back so the model continues from where it
              // was cut off; replace the previous continuation partial (if
              // any) since [partial] already contains it.
              final partialMessage = LlmMessage(
                role: MessageRole.assistant,
                content: partial,
              );
              if (continuationIndex >= 0) {
                messages = List<LlmMessage>.of(messages)
                  ..[continuationIndex] = partialMessage;
              } else {
                continuationIndex = messages.length;
                messages = <LlmMessage>[...messages, partialMessage];
              }
              update();
              continue; // next round = continuation
            }

            // Flush this round's thinking before the final text so block order
            // is correct: ...prev → ThinkingBlockN → MainText(final).
            if (thinking.isNotEmpty) {
              completed.add(
                _thinkingBlock(
                  messageId: assistantMessageId,
                  createdAt: assistantTime,
                  content: thinking.toString(),
                  startedAt: thinkingStartAt,
                  endedAt: thinkingEndAt,
                ),
              );
              thinking.clear();
              thinkingStartAt = null;
              thinkingEndAt = null;
            }
            final display = roundDisplay();
            if (display.isNotEmpty || completed.isEmpty) {
              completed.add(
                _mainTextBlock(
                  id: roundBlockId,
                  messageId: assistantMessageId,
                  createdAt: assistantTime,
                  content: display,
                ),
              );
            }
            // Record whether the response was still truncated after all auto-
            // continues so the UI can show a "继续生成" button.
            if (truncated) _markTruncated(assistantMessageId);
            break;
          }

          // Finalize this round's thinking (if any) into a separate block
          // before the tool blocks, so the render order mirrors the web:
          // ThinkingBlock₁ → ToolBlock₁ → ThinkingBlock₂ → ToolBlock₂ → …
          if (thinking.isNotEmpty) {
            completed.add(
              _thinkingBlock(
                messageId: assistantMessageId,
                createdAt: assistantTime,
                content: thinking.toString(),
                startedAt: thinkingStartAt,
                endedAt: thinkingEndAt,
              ),
            );
            thinking.clear();
            thinkingStartAt = null;
            thinkingEndAt = null;
            thinkingBlockId = generateId('thinking');
          }

          // Persist this round's prose (if any) before the tool blocks so the
          // render order is prose → tool result → next round.
          final display = roundDisplay();
          if (display.isNotEmpty) {
            completed.add(
              _mainTextBlock(
                id: roundBlockId,
                messageId: assistantMessageId,
                createdAt: assistantTime,
                content: display,
              ),
            );
          }
          // The prose now lives in [completed]; clear the buffer so the trailing
          // live MainText block in update() doesn't re-render the same text after
          // the tool blocks while the tools are still executing. roundText is
          // already captured above for the message history.
          buffer.clear();

          // Run each requested tool — built-ins in-process, remote tools over a
          // live connection — and render a 工具 block per call.
          // Every tool block is shown immediately in "processing" state so the
          // user sees real-time feedback, then replaced with the final result.
          // Settings tools with `confirm` permission additionally pause for
          // user approval before execution.
          final results = <({LlmToolCall call, McpToolResult result})>[];
          for (final call in runnable) {
            final route = mcp.routes[call.name]!;
            final args = decodeToolArguments(call.arguments);
            final blockId = generateId('block');
            final toolId = call.id.isEmpty ? call.name : call.id;

            final turnWorkspaces =
                _ref.read(workspaceStoreProvider).value ?? const <Workspace>[];
            // 用户白名单（工作区管理页 → 工具授权）里的工具跳过审批；
            // 高危终端命令不受白名单覆盖。
            final needsConfirm =
                toolNeedsConfirmation(
                  route,
                  call.name,
                  args,
                  // 终端工具按目标工作区 scope 分级审批（双作用域设计稿 §3.2）。
                  workspaces: turnWorkspaces,
                ) &&
                !toolAutoApprovedByPolicy(
                  _ref.read(toolAuthPolicyProvider),
                  route,
                  call.name,
                  args,
                  workspaces: turnWorkspaces,
                );

            // `terminal_execute` can be aborted mid-flight:
            // register a cancel signal
            // (keyed by this block) before running so the block's 中断 button
            // can kill the remote session, then deregister once it settles.
            // Output chunks stream into commandLiveOutputProvider while the
            // command runs so the block renders live output.
            final isCancelableCommand = isCancelableCommandCall(
              route,
              call.name,
            );
            Future<McpToolResult> runRoute() async {
              if (!isCancelableCommand) {
                return _toolExecutor.runTool(route, call.name, args);
              }
              final running = _ref.read(runningCommandsProvider.notifier);
              final liveOutput = _ref.read(commandLiveOutputProvider.notifier);
              final cancelSignal = running.start(blockId);
              try {
                return await _toolExecutor.runTool(
                  route,
                  call.name,
                  args,
                  cancelSignal: cancelSignal,
                  onOutput: (chunk) => liveOutput.append(blockId, chunk),
                );
              } finally {
                running.finish(blockId);
                liveOutput.clear(blockId);
              }
            }

            // Show a processing block immediately so the user sees the tool
            // call in real-time (spinner + tool name).
            completed.add(
              MessageBlock.tool(
                id: blockId,
                messageId: assistantMessageId,
                status: MessageBlockStatus.processing,
                createdAt: assistantTime,
                toolId: toolId,
                toolName: call.name,
                arguments: args,
                metadata: {
                  kToolModeMetadataKey: mcp.mode.storageValue,
                  kToolRoundMetadataKey: roundBlockId,
                  if (needsConfirm) 'needsConfirmation': true,
                },
              ),
            );
            update();
            // MCP 工具可能跑很久：执行前强制落盘一次，保证前面各轮的正文/思考/
            // 工具结果在执行期间闪退也不丢。
            checkpoint(force: true);

            McpToolResult result;
            if (needsConfirm) {
              final confirm = _ref.read(toolConfirmationProvider.notifier);
              // A 免确认 window opened earlier for this same tool lets it run
              // without prompting again (per-tool, per-conversation)。高危
              // 终端命令不受免确认窗口覆盖，必须逐条审批。
              final graceUsable =
                  confirm.isGraceActive(turnTopicId, call.name) &&
                  !(route is TerminalToolRoute &&
                      terminalCommandIsHighRisk(call.name, args));
              final approved = graceUsable
                  ? true
                  : await confirm.request(
                      ToolConfirmationRequest(
                        id: blockId,
                        conversationId: turnTopicId,
                        toolName: call.name,
                        summary: toolConfirmSummary(call.name, args),
                        args: args,
                      ),
                    );

              if (approved) {
                result = await runRoute();
              } else {
                result = const McpToolResult('用户拒绝了此操作', isError: true);
              }
            } else {
              result = await runRoute();
            }

            // Replace the processing block with the final result.
            completed.removeWhere((b) => b is ToolBlock && b.id == blockId);
            results.add((call: call, result: result));
            completed.add(
              MessageBlock.tool(
                id: blockId,
                messageId: assistantMessageId,
                status: result.isError
                    ? MessageBlockStatus.error
                    : MessageBlockStatus.success,
                createdAt: assistantTime,
                updatedAt: DateTime.now(),
                toolId: toolId,
                toolName: call.name,
                arguments: args,
                content: result.text,
                metadata: {
                  kToolModeMetadataKey: mcp.mode.storageValue,
                  kToolRoundMetadataKey: roundBlockId,
                },
              ),
            );
            update();
            checkpoint(force: true);
          }

          // Feed the assistant turn + tool results back so the model can
          // continue. [roundText] already contains any auto-continued partial
          // of this prose block, so drop the placeholder fed back earlier.
          if (continuationIndex >= 0) {
            messages = List<LlmMessage>.of(messages)
              ..removeAt(continuationIndex);
            continuationIndex = -1;
          }
          if (mcp.usePromptInjection) {
            messages = <LlmMessage>[
              ...messages,
              LlmMessage(role: MessageRole.assistant, content: roundText),
              for (final entry in results)
                LlmMessage(
                  role: MessageRole.user,
                  content: formatToolUseResult(
                    entry.call.name,
                    entry.result.text,
                  ),
                ),
            ];
          } else {
            messages = <LlmMessage>[
              ...messages,
              LlmMessage(
                role: MessageRole.assistant,
                content: roundText,
                toolCalls: runnable,
              ),
              for (final entry in results)
                LlmMessage(
                  role: MessageRole.user,
                  content: entry.result.text,
                  toolCallId: entry.call.id.isEmpty
                      ? entry.call.name
                      : entry.call.id,
                  toolName: entry.call.name,
                ),
            ];
          }

          roundBlockId = generateId('block');
          update();
        }

        stopwatch.stop();
        await checkpointChain;
        await _persistMessageBlocks(
          messageId: assistantMessageId,
          status: MessageStatus.success,
          usage: capturedUsage,
          metrics: Metrics(
            latency: stopwatch.elapsedMilliseconds,
            firstTokenLatency: firstTokenMs,
          ),
          blocks: [...completed],
        );
        if (selectedIndex != -1) {
          recordKeyOutcome(selectedIndex, success: true);
        }
        await persistKeyUpdates();
        view = await _reloadView(assistantMessageId, view);
        _replace(views, view);
        emitTurnEnd();
        if (finalizeTurn) {
          unawaited(_refreshTopicPreview(turnTopicId));
          unawaited(_generateTitle(turnTopicId));
          unawaited(_maybeGenerateSuggestions(turnTopicId, List.of(views)));
          // 自动提取本轮的长期记忆 —— best-effort, off the turn's critical path.
          unawaited(_maybeExtractMemory(turnTopicId));
        }
        return;
      } on Object catch (error) {
        // User pressed Stop: cancelling the token aborts the HTTP request, which
        // surfaces here as a stream error. Keep the partial output rather than
        // treating it as a failure.
        if (cancelToken.isCancelled) {
          await persistStopped();
          return;
        }
        lastError = error;
        if (selectedIndex != -1) {
          failedKeyIds.add(workingKeys[selectedIndex].id);
          recordKeyOutcome(
            selectedIndex,
            success: false,
            rateLimited: ApiKeyManager.isRateLimitError(error),
            error: _errorMessage(error),
          );
        }
        // The single-key fallback is a one-shot last resort — once it fails
        // there is nothing left to fail over to.
        if (isFallbackAttempt) break;
        // Fail over to the next key only if nothing streamed yet and another
        // attempt remains; otherwise fall through to the terminal error below.
        if (useKeyPool && !committed && attempt < maxAttempts - 1) {
          await Future<void>.delayed(_keyRetryDelay(attempt));
          continue;
        }
        break;
      }
    }

    // Terminal failure: reject any pending confirmations, persist any key stat
    // changes, then mark the message errored.
    _ref.read(toolConfirmationProvider.notifier).rejectAll();
    _ref.read(runningCommandsProvider.notifier).cancelAll();
    await checkpointChain;
    await persistKeyUpdates();
    final messageText = _errorMessage(
      lastError ?? const NoUsableApiKeyException(),
    );
    final partial = roundDisplay();
    await _persistMessageBlocks(
      messageId: assistantMessageId,
      status: MessageStatus.error,
      blocks: [
        // Flush any remaining thinking from the current round.
        if (thinking.isNotEmpty)
          _thinkingBlock(
            messageId: assistantMessageId,
            createdAt: assistantTime,
            content: thinking.toString(),
            startedAt: thinkingStartAt,
            endedAt: thinkingEndAt,
          ),
        ...completed,
        if (partial.isNotEmpty)
          _mainTextBlock(
            id: roundBlockId,
            messageId: assistantMessageId,
            createdAt: assistantTime,
            content: partial,
          ),
        MessageBlock.error(
          id: generateId('block'),
          messageId: assistantMessageId,
          status: MessageBlockStatus.error,
          createdAt: assistantTime,
          updatedAt: DateTime.now(),
          content: partial,
          message: messageText,
        ),
      ],
    );
    view = await _reloadView(
      assistantMessageId,
      view.copyWith(status: MessageStatus.error, errorText: messageText),
    );
    _replace(views, view);
    emitTurnEnd();
    if (finalizeTurn) unawaited(_refreshTopicPreview(turnTopicId));
  }

  /// Exponential-ish backoff between multi-key failover attempts, mirroring the
  /// web `retryDelay * (attempt + 1)` (base 1s).
  Duration _keyRetryDelay(int attempt) =>
      Duration(milliseconds: 1000 * (attempt + 1));

  MessageBlock _mainTextBlock({
    required String id,
    required String messageId,
    required DateTime createdAt,
    required String content,
  }) => MessageBlock.mainText(
    id: id,
    messageId: messageId,
    status: MessageBlockStatus.success,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    content: content,
  );

  MessageBlock _thinkingBlock({
    required String messageId,
    required DateTime createdAt,
    required String content,
    DateTime? startedAt,
    DateTime? endedAt,
  }) => MessageBlock.thinking(
    id: generateId('block'),
    messageId: messageId,
    status: MessageBlockStatus.success,
    // Pure thinking duration: first reasoning token → reasoning stop (answer/tool
    // phase start), not message creation → message finish.
    createdAt: startedAt ?? createdAt,
    updatedAt: endedAt ?? DateTime.now(),
    thinkingMillsec: startedAt != null && endedAt != null
        ? endedAt.difference(startedAt).inMilliseconds
        : null,
    content: content,
  );
}
