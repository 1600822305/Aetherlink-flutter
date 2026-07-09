// 流式主循环相关的会话操作，从 chat_controller.dart 主体拆出的 part 文件：
// _streamInto 的 gateway 订阅 + MCP 工具调用循环（多 key 负载均衡/故障转移、
// 思考块、检查点持久化、自动续写、终态落库），以及仅被它使用的流式常量与
// 块构造辅助方法。
// 与 _emitTurn / _persistMessageBlocks / _reloadView 等私有成员强耦合，因此以
// part + mixin 的形式与 ChatController 同库拆分（mixin 里声明所依赖的
// 私有成员抽象签名，由 ChatController 本体提供实现）。

part of 'chat_controller.dart';

mixin _ChatStreaming on _$ChatController, _ChatPostTurn {
  // --- 由 ChatController 本体提供的成员 ---

  set _truncatedMessageId(String? value);
  ChatToolExecutor get _toolExecutor;
  StreamingRegistry get _registry;

  void _emitTurn(
    String turnTopicId,
    List<ChatMessageView> views, {
    required bool streaming,
  });
  void _replace(List<ChatMessageView> views, ChatMessageView view);
  Future<ChatMessageView> _reloadView(
    String messageId,
    ChatMessageView fallback,
  );
  Future<void> _persistMessageBlocks({
    required String messageId,
    required MessageStatus status,
    required List<MessageBlock> blocks,
    Usage? usage,
    Metrics? metrics,
  });
  String _errorMessage(Object error);

  // --- 搬出的常量与方法 ---

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
  Future<void> _streamInto({
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
    // Terminal emit at the end of *this* stream. For a single-model turn it ends
    // the topic's streaming state (streaming:false → registry.finish); for a
    // multi-model sibling it keeps the turn alive (streaming:true) so the other
    // siblings stay visible until the coordinator finishes.
    void emitTurnEnd() =>
        _emitTurn(turnTopicId, views, streaming: !finalizeTurn);
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
      await ref
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

    String aggregateText(String current) => <String>[
      for (final block in completed)
        if (block is MainTextBlock && block.content.isNotEmpty) block.content,
      if (current.isNotEmpty) current,
    ].join('\n\n');

    String aggregateThinking() => <String>[
      for (final block in completed)
        if (block is ThinkingBlock && block.content.isNotEmpty) block.content,
      if (thinking.isNotEmpty) thinking.toString(),
    ].join('\n\n');

    void update() {
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
      ref.read(toolConfirmationProvider.notifier).rejectAll();
      ref.read(runningCommandsProvider.notifier).cancelAll();
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
          lastError ??= const _NoUsableApiKeyException();
          break;
        }
      }

      final gateway = ref
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
                update();
                checkpoint();
              case LlmReasoningDelta(:final text):
                committed = true;
                firstTokenMs ??= stopwatch.elapsedMilliseconds;
                thinkingStartAt ??= DateTime.now();
                thinking.write(text);
                update();
                checkpoint();
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
            if (truncated) _truncatedMessageId = assistantMessageId;
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

            final needsConfirm = toolNeedsConfirmation(route, call.name, args);

            // `run_command` / `terminal_execute` can be aborted mid-flight:
            // register a cancel signal
            // (keyed by this block) before running so the block's 中断 button
            // can kill the remote session, then deregister once it settles.
            final isCancelableCommand = isCancelableCommandCall(
              route,
              call.name,
            );
            Future<McpToolResult> runRoute() async {
              if (!isCancelableCommand) {
                return _toolExecutor.runTool(route, call.name, args);
              }
              final running = ref.read(runningCommandsProvider.notifier);
              final cancelSignal = running.start(blockId);
              try {
                return await _toolExecutor.runTool(
                  route,
                  call.name,
                  args,
                  cancelSignal: cancelSignal,
                );
              } finally {
                running.finish(blockId);
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
                  _toolModeMetadataKey: mcp.mode.storageValue,
                  _toolRoundMetadataKey: roundBlockId,
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
              final confirm = ref.read(toolConfirmationProvider.notifier);
              // A 免确认 window opened earlier for this same tool lets it run
              // without prompting again (per-tool, per-conversation).
              final approved = confirm.isGraceActive(turnTopicId, call.name)
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
                  _toolModeMetadataKey: mcp.mode.storageValue,
                  _toolRoundMetadataKey: roundBlockId,
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
    ref.read(toolConfirmationProvider.notifier).rejectAll();
    ref.read(runningCommandsProvider.notifier).cancelAll();
    await checkpointChain;
    await persistKeyUpdates();
    final messageText = _errorMessage(
      lastError ?? const _NoUsableApiKeyException(),
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
