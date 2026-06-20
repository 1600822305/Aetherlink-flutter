import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/app/di/system_prompt_variables_access.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/translate_controller.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/api_key_manager.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_file_reference.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/config/skill_prompt_builder.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_bridge_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_prompt.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/remote/remote_mcp_connection_manager.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';
import 'package:aetherlink_flutter/shared/utils/system_prompt_variables.dart';

part 'chat_controller.g.dart';

/// Orchestrates the chat send/stream loop (application layer).
///
/// It owns the rendered conversation ([ChatState]) and depends only on ports:
/// the [ChatRepository] for persistence, the cross-feature current model
/// (`appCurrentModelProvider`), and the `LlmGatewayFactory` for the gateway —
/// every concrete implementation is injected via Riverpod (the DI seam in
/// `chat_providers.dart` / `app/di/model_access.dart`), so the boundary tests
/// hold and tests run the whole loop with a fake gateway.
///
/// Send flow: persist the user message (+ `main_text` block) → persist a
/// streaming assistant message → build an [LlmChatRequest] from the current
/// model + history → subscribe to the gateway stream, accumulating text into
/// the assistant's `main_text` and reasoning into its `thinking` while updating
/// state per chunk → on [LlmDone] finalize and persist the blocks; on a stream
/// error mark the message errored and persist an `error` block.
@riverpod
class ChatController extends _$ChatController {
  static const String _defaultAssistantId = 'default-assistant';

  String? _topicId;
  String _assistantId = _defaultAssistantId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<ChatState> build() async {
    // In-place mutations of the current conversation (清空消息) bump this so the
    // view reloads without changing the selected topic id.
    ref.watch(chatRefreshProvider);
    final topic = await ref.watch(currentTopicProvider.future);
    if (topic == null) {
      _topicId = null;
      return ChatState.initial();
    }
    _topicId = topic.id;
    _assistantId = topic.assistantId;

    final messages = await _repo.getMessagesByTopicId(topic.id)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final views = <ChatMessageView>[];
    for (final message in messages) {
      views.add(await _viewOf(message));
    }
    return ChatState(messages: views);
  }

  /// Sends [text] as a user message and streams the assistant reply. A
  /// blank message with no [attachments], a missing current model, or an
  /// in-flight stream are no-ops (the composer also disables the button in those
  /// cases).
  ///
  /// Each entry of [attachments] (currently only long pasted text converted to a
  /// `.txt`) is persisted as a `FILE` block on the user message and its decoded
  /// text is appended to the request content so the model receives it.
  Future<void> send(
    String text, {
    List<ComposerAttachment> attachments = const <ComposerAttachment>[],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;

    final snapshot = state.value ?? ChatState.initial();
    if (snapshot.isStreaming) return;

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    final topicId = await _ensureTopic();
    final now = DateTime.now();

    // 1. User message: an optional main_text block plus one FILE block per
    //    attachment, persisted in that order.
    final userMessageId = generateId('msg');
    final hasText = trimmed.isNotEmpty;
    final userBlocks = <MessageBlock>[
      if (hasText)
        MessageBlock.mainText(
          id: generateId('block'),
          messageId: userMessageId,
          status: MessageBlockStatus.success,
          createdAt: now,
          content: trimmed,
        ),
      for (final attachment in attachments)
        _attachmentBlock(
          messageId: userMessageId,
          createdAt: now,
          attachment: attachment,
        ),
    ];
    final userMessage = Message(
      id: userMessageId,
      role: MessageRole.user,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.success,
      blocks: <String>[for (final block in userBlocks) block.id],
    );
    await _repo.saveMessage(userMessage);
    for (final block in userBlocks) {
      await _repo.saveMessageBlock(block);
    }

    // 2. Assistant message in streaming state, persisted.
    final assistantTime = now.add(const Duration(microseconds: 1));
    final assistantMessageId = generateId('msg');
    final assistantBlockId = generateId('block');
    final effective = effectiveModelFor(current);
    final assistantMessage = Message(
      id: assistantMessageId,
      role: MessageRole.assistant,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: assistantTime,
      status: MessageStatus.streaming,
      model: effective,
      askId: userMessageId,
      blocks: <String>[assistantBlockId],
    );
    await _repo.saveMessage(assistantMessage);
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: assistantBlockId,
        messageId: assistantMessageId,
        status: MessageBlockStatus.streaming,
        createdAt: assistantTime,
        content: '',
      ),
    );

    final userView = ChatMessageView(
      id: userMessageId,
      role: MessageRole.user,
      status: MessageStatus.success,
      text: trimmed,
      blocks: userBlocks,
      createdAt: now,
    );
    final assistantView = ChatMessageView(
      id: assistantMessageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      createdAt: assistantTime,
      modelName: effective.name,
      providerName: current.provider.name,
    );
    final views = [...snapshot.messages, userView, assistantView];
    _emit(views, isStreaming: true);

    // 3. Build the request from the current model + history (the user turn we
    // just added included; the empty assistant placeholder excluded).
    final mcp = await _mcpSetup();
    final request = LlmChatRequest(
      model: effective,
      system: _systemFor(mcp, await _buildSystemPrompt()),
      messages: [
        for (final view in views)
          if (view.role != MessageRole.assistant || view.text.isNotEmpty)
            LlmMessage(role: view.role, content: _requestContent(view)),
      ],
      tools: mcp.useFunctionTools ? mcp.tools : null,
      useResponsesAPI: current.provider.useResponsesAPI ?? false,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
      provider: current.provider,
      assistantMessageId: assistantMessageId,
      assistantBlockId: assistantBlockId,
      assistantTime: assistantTime,
      views: views,
      assistantView: assistantView,
      mcp: mcp,
    );
  }

  /// Regenerates the assistant reply [messageId] in place.
  ///
  /// Port of the toolbar 重新生成 action (`regenerateResponse` with
  /// `source: 'assistant'`): the message keeps its id but its old blocks are
  /// dropped, it is reset to a streaming state re-pointed at the current model,
  /// and a fresh reply is streamed from the conversation that preceded it.
  /// Before overwriting, the currently displayed content is archived as a
  /// version via [_prepareForRegenerate] (mirroring `prepareForRegenerate`), so
  /// the previous reply can be restored from 版本历史. A no-op while a reply is
  /// streaming, when the conversation has not loaded, when no model is selected,
  /// or when [messageId] is not a loaded assistant message.
  Future<void> regenerate(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;

    final index = snapshot.messages.indexWhere((view) => view.id == messageId);
    if (index == -1) return;

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    final target = await _repo.getMessage(messageId);
    if (target == null || target.role != MessageRole.assistant) return;

    final now = DateTime.now();
    final effective = effectiveModelFor(current);

    // Archive the currently displayed content as a version, then reset the
    // assistant message: drop its old blocks and attach a single fresh
    // streaming main_text block, re-pointed at the current model, with the
    // freshly streamed reply becoming the new latest (currentVersionId null).
    final prepared = await _prepareForRegenerate(target, now);
    final oldBlocks = await _repo.getMessageBlocksByMessageId(messageId);
    for (final block in oldBlocks) {
      await _repo.deleteMessageBlock(block.id);
    }
    final assistantBlockId = generateId('block');
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: assistantBlockId,
        messageId: messageId,
        status: MessageBlockStatus.streaming,
        createdAt: now,
        content: '',
      ),
    );
    await _repo.saveMessage(
      prepared.copyWith(
        status: MessageStatus.streaming,
        updatedAt: now,
        model: effective,
        blocks: <String>[assistantBlockId],
        currentVersionId: null,
      ),
    );

    // Reset the view to a streaming placeholder; the request history is the
    // conversation up to (excluding) this assistant message.
    final views = List<ChatMessageView>.of(snapshot.messages);
    final assistantView = ChatMessageView(
      id: messageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      createdAt: target.createdAt,
      modelName: effective.name,
      providerName: current.provider.name,
    );
    views[index] = assistantView;
    _emit(views, isStreaming: true);

    final mcp = await _mcpSetup();
    final request = LlmChatRequest(
      model: effective,
      system: _systemFor(mcp, await _buildSystemPrompt()),
      messages: [
        for (final view in views.sublist(0, index))
          if (view.role != MessageRole.assistant || view.text.isNotEmpty)
            LlmMessage(role: view.role, content: _requestContent(view)),
      ],
      tools: mcp.useFunctionTools ? mcp.tools : null,
      useResponsesAPI: current.provider.useResponsesAPI ?? false,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
      provider: current.provider,
      assistantMessageId: messageId,
      assistantBlockId: assistantBlockId,
      assistantTime: now,
      views: views,
      assistantView: assistantView,
      mcp: mcp,
    );
  }

  /// Resends user message [messageId]: re-runs the assistant reply tied to it.
  ///
  /// Port of the toolbar 重新发送 action (`regenerateResponse` with
  /// `source: 'user'`): finds the assistant message whose `askId` points at this
  /// user message and regenerates it in place (archiving its previous content as
  /// a version, exactly like 重新生成); if no reply exists yet, a fresh assistant
  /// message linked via `askId` is created and streamed from the conversation so
  /// far. A no-op while a reply is streaming, when the conversation has not
  /// loaded, when no model is selected, or when [messageId] is not a loaded user
  /// message.
  Future<void> resend(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    final userMessage = await _repo.getMessage(messageId);
    if (userMessage == null || userMessage.role != MessageRole.user) return;

    // Reuse 重新生成 when this user message already has a reply.
    final replyId = await _findAssistantReplyId(userMessage, snapshot.messages);
    if (replyId != null) {
      await regenerate(replyId);
      return;
    }

    // No reply yet: create a fresh assistant message linked via askId and stream
    // it from the conversation so far (the user turn is already in the view).
    final now = DateTime.now();
    final effective = effectiveModelFor(current);
    final assistantMessageId = generateId('msg');
    final assistantBlockId = generateId('block');
    final assistantMessage = Message(
      id: assistantMessageId,
      role: MessageRole.assistant,
      assistantId: _assistantId,
      topicId: userMessage.topicId,
      createdAt: now,
      status: MessageStatus.streaming,
      model: effective,
      askId: messageId,
      blocks: <String>[assistantBlockId],
    );
    await _repo.saveMessage(assistantMessage);
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: assistantBlockId,
        messageId: assistantMessageId,
        status: MessageBlockStatus.streaming,
        createdAt: now,
        content: '',
      ),
    );

    final assistantView = ChatMessageView(
      id: assistantMessageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      createdAt: now,
      modelName: effective.name,
      providerName: current.provider.name,
    );
    final views = [...snapshot.messages, assistantView];
    _emit(views, isStreaming: true);

    final mcp = await _mcpSetup();
    final request = LlmChatRequest(
      model: effective,
      system: _systemFor(mcp, await _buildSystemPrompt()),
      messages: [
        for (final view in snapshot.messages)
          if (view.role != MessageRole.assistant || view.text.isNotEmpty)
            LlmMessage(role: view.role, content: _requestContent(view)),
      ],
      tools: mcp.useFunctionTools ? mcp.tools : null,
      useResponsesAPI: current.provider.useResponsesAPI ?? false,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
      provider: current.provider,
      assistantMessageId: assistantMessageId,
      assistantBlockId: assistantBlockId,
      assistantTime: now,
      views: views,
      assistantView: assistantView,
      mcp: mcp,
    );
  }

  /// Finds the assistant reply for user message [userMessage], or null if it has
  /// none. Mirrors the original `source:'user'` lookup
  /// (`msg.role === 'assistant' && msg.askId === messageId`); falls back to the
  /// assistant view that directly follows the user message in display order for
  /// messages persisted before `askId` was recorded.
  Future<String?> _findAssistantReplyId(
    Message userMessage,
    List<ChatMessageView> views,
  ) async {
    final topicMessages = await _repo.getMessagesByTopicId(userMessage.topicId);
    for (final message in topicMessages) {
      if (message.role == MessageRole.assistant &&
          message.askId == userMessage.id) {
        return message.id;
      }
    }
    final index = views.indexWhere((view) => view.id == userMessage.id);
    if (index != -1 && index + 1 < views.length) {
      final next = views[index + 1];
      if (next.role == MessageRole.assistant) return next.id;
    }
    return null;
  }

  /// The most rounds the tool-call loop will run before forcing a final answer,
  /// mirroring the web `maxToolCallRounds` guard against runaway tool loops.
  static const int _kMaxToolRounds = 5;

  /// The most keys a single send tries before giving up, when the provider has a
  /// multi-key pool. Mirrors the web `EnhancedApiProvider` `maxRetries = 3`.
  static const int _kMaxKeyAttempts = 3;

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
    required LlmChatRequest request,
    required Model effective,
    required ModelProvider provider,
    required String assistantMessageId,
    required String assistantBlockId,
    required DateTime assistantTime,
    required List<ChatMessageView> views,
    required ChatMessageView assistantView,
    required _McpSetup mcp,
  }) async {
    // Multi-key load balancing + failover. When the provider carries a multi-key
    // pool, each attempt strategy-selects a usable key ([ApiKeyManager]); a
    // connection-time failure (before anything streamed) fails over to the next
    // usable key, and per-key usage/cooldown is recorded then persisted through
    // the model store so the multi-key UI's stats reflect real traffic. With no
    // pool this collapses to a single attempt on [effective]'s key — the
    // original single-key behaviour. Mirrors the web `EnhancedApiProvider`.
    final keyManager = ApiKeyManager.instance;
    final keyPool = provider.apiKeys ?? const <ApiKeyConfig>[];
    final useKeyPool = keyPool.isNotEmpty;
    final keyStrategy = provider.keyManagement?.strategy ?? 'round_robin';
    final hasSingleKeyFallback = (effective.apiKey ?? '').trim().isNotEmpty;
    final maxAttempts = useKeyPool ? _kMaxKeyAttempts : 1;
    final workingKeys = List<ApiKeyConfig>.of(keyPool);
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

    void recordKeyOutcome(int index, {required bool success, String? error}) {
      if (index < 0 || index >= workingKeys.length) return;
      final updated = keyManager.updateKeyStatus(
        workingKeys[index],
        success: success,
        error: error,
      );
      workingKeys[index] = updated;
      keyUpdates[updated.id] = updated;
    }

    // Reasoning is aggregated across rounds into one 思考 card; [completed] holds
    // the blocks earlier rounds finalized (the model's prose plus the 工具 blocks
    // it triggered) in render order; [messages] is the running conversation that
    // grows by an assistant turn + tool-result turns each time a tool runs.
    final thinking = StringBuffer();
    final completed = <MessageBlock>[];
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

    void update() {
      final current = roundDisplay();
      final liveBlocks = <MessageBlock>[
        if (thinking.isNotEmpty)
          MessageBlock.thinking(
            id: '$assistantMessageId::thinking',
            messageId: assistantMessageId,
            status: MessageBlockStatus.streaming,
            createdAt: assistantTime,
            content: thinking.toString(),
          ),
        ...completed,
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
        thinking: thinking.toString(),
        blocks: liveBlocks,
      );
      _replace(views, view);
      _emit(views, isStreaming: true);
    }

    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // Pick the key for this attempt. With a pool: strategy-select a usable
      // key; if none is usable, fall back once to the single [effective] key
      // (mirroring the web `enableFallback`), else surface 没有可用的 Key.
      var effectiveForAttempt = effective;
      var selectedIndex = -1;
      if (useKeyPool) {
        final selected = keyManager.selectApiKey(workingKeys, keyStrategy);
        if (selected != null) {
          selectedIndex = workingKeys.indexWhere((k) => k.id == selected.id);
          effectiveForAttempt = effective.copyWith(apiKey: selected.key);
        } else if (hasSingleKeyFallback) {
          effectiveForAttempt = effective;
        } else {
          lastError ??= const _NoUsableApiKeyException();
          break;
        }
      }

      final gateway = ref
          .read(llmGatewayFactoryProvider)
          .forModel(effectiveForAttempt);

      // Reset the per-attempt accumulators so a failover retry starts clean.
      thinking.clear();
      completed.clear();
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
        for (var round = 0; ; round++) {
          buffer.clear();
          final structuredCalls = <LlmToolCall>[];
          await for (final chunk in gateway.streamChat(
            request.copyWith(messages: messages, model: effectiveForAttempt),
          )) {
            switch (chunk) {
              case LlmTextDelta(:final text):
                committed = true;
                firstTokenMs ??= stopwatch.elapsedMilliseconds;
                buffer.write(text);
                update();
              case LlmReasoningDelta(:final text):
                committed = true;
                firstTokenMs ??= stopwatch.elapsedMilliseconds;
                thinking.write(text);
                update();
              case LlmToolCallChunk(:final call):
                committed = true;
                structuredCalls.add(call);
              case LlmDone(:final usage):
                if (usage != null) capturedUsage = usage;
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
          // prose is the final answer.
          if (runnable.isEmpty || round >= _kMaxToolRounds - 1) {
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
            break;
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

          // Run each requested tool — built-ins in-process, remote tools over a
          // live connection — and render a 工具 block per call.
          final results = <({LlmToolCall call, McpToolResult result})>[];
          for (final call in runnable) {
            final route = mcp.routes[call.name]!;
            final args = decodeToolArguments(call.arguments);
            final result = await _runTool(route, call.name, args);
            results.add((call: call, result: result));
            completed.add(
              MessageBlock.tool(
                id: generateId('block'),
                messageId: assistantMessageId,
                status: result.isError
                    ? MessageBlockStatus.error
                    : MessageBlockStatus.success,
                createdAt: assistantTime,
                updatedAt: DateTime.now(),
                toolId: call.id.isEmpty ? call.name : call.id,
                toolName: call.name,
                arguments: args,
                content: result.text,
              ),
            );
          }

          // Feed the assistant turn + tool results back so the model can continue.
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
        await _persistMessageBlocks(
          messageId: assistantMessageId,
          status: MessageStatus.success,
          usage: capturedUsage,
          metrics: Metrics(
            latency: stopwatch.elapsedMilliseconds,
            firstTokenLatency: firstTokenMs,
          ),
          blocks: [
            if (thinking.isNotEmpty)
              _thinkingBlock(
                messageId: assistantMessageId,
                createdAt: assistantTime,
                content: thinking.toString(),
              ),
            ...completed,
          ],
        );
        if (selectedIndex != -1) {
          recordKeyOutcome(selectedIndex, success: true);
        }
        await persistKeyUpdates();
        view = await _reloadView(assistantMessageId, view);
        _replace(views, view);
        _emit(views, isStreaming: false);
        return;
      } on Object catch (error) {
        lastError = error;
        if (selectedIndex != -1) {
          recordKeyOutcome(
            selectedIndex,
            success: false,
            error: _errorMessage(error),
          );
        }
        // Fail over to the next key only if nothing streamed yet and another
        // attempt remains; otherwise fall through to the terminal error below.
        if (useKeyPool && !committed && attempt < maxAttempts - 1) {
          await Future<void>.delayed(_keyRetryDelay(attempt));
          continue;
        }
        break;
      }
    }

    // Terminal failure: persist any key stat changes, then mark the message
    // errored — keeping whatever the last attempt streamed — exactly like the
    // original single-key error path.
    await persistKeyUpdates();
    final messageText = _errorMessage(
      lastError ?? const _NoUsableApiKeyException(),
    );
    final partial = roundDisplay();
    await _persistMessageBlocks(
      messageId: assistantMessageId,
      status: MessageStatus.error,
      blocks: [
        if (thinking.isNotEmpty)
          _thinkingBlock(
            messageId: assistantMessageId,
            createdAt: assistantTime,
            content: thinking.toString(),
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
    _emit(views, isStreaming: false);
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
  }) => MessageBlock.thinking(
    id: generateId('block'),
    messageId: messageId,
    status: MessageBlockStatus.success,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    content: content,
  );

  /// Replaces every block of [messageId] with [blocks] (in order) and stamps the
  /// message [status]. Deleting first keeps the streaming placeholder and any
  /// stale blocks from leaking into the rendered order ([_orderBlocks] appends
  /// unreferenced blocks), so the persisted set is exactly what was streamed.
  Future<void> _persistMessageBlocks({
    required String messageId,
    required MessageStatus status,
    required List<MessageBlock> blocks,
    Usage? usage,
    Metrics? metrics,
  }) async {
    final now = DateTime.now();
    final existing = await _repo.getMessageBlocksByMessageId(messageId);
    for (final block in existing) {
      await _repo.deleteMessageBlock(block.id);
    }
    for (final block in blocks) {
      await _repo.saveMessageBlock(block);
    }
    final message = await _repo.getMessage(messageId);
    if (message != null) {
      await _repo.saveMessage(
        message.copyWith(
          status: status,
          updatedAt: now,
          blocks: [for (final block in blocks) block.id],
          usage: usage ?? message.usage,
          metrics: metrics ?? message.metrics,
        ),
      );
    }
  }

  /// Deletes [messageId] together with its blocks and drops it from the view.
  ///
  /// Port of the toolbar 删除 action (`MessageActions.handleToolbarDeleteClick`
  /// → `onDelete`). The two-click confirmation lives in the UI; this performs
  /// the actual removal once confirmed. A no-op while a reply is streaming or
  /// when the conversation has not loaded.
  Future<void> deleteMessage(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    await _repo.deleteMessage(messageId);
    final views = snapshot.messages
        .where((view) => view.id != messageId)
        .toList();
    _emit(views, isStreaming: false);
  }

  /// Writes [contentByBlockId] back to the message's `main_text` blocks and
  /// persists them, then reloads the affected view.
  ///
  /// Port of the toolbar 编辑 action (`MessageEditor.handleSave`): each edited
  /// `main_text` block is updated in place (content + `updatedAt`), the message
  /// `updatedAt` is bumped, and the rendered view is refreshed from storage.
  /// Blank entries and blocks that are not `main_text` are skipped. A no-op
  /// while a reply is streaming.
  Future<void> editMessageText(
    String messageId,
    Map<String, String> contentByBlockId,
  ) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    if (contentByBlockId.isEmpty) return;

    final now = DateTime.now();
    var changed = false;
    for (final entry in contentByBlockId.entries) {
      final trimmed = entry.value.trim();
      if (trimmed.isEmpty) continue;
      final existing = await _repo.getMessageBlock(entry.key);
      if (existing is MainTextBlock && existing.content != trimmed) {
        await _repo.saveMessageBlock(
          existing.copyWith(content: trimmed, updatedAt: now),
        );
        changed = true;
      }
    }
    if (!changed) return;

    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    await _repo.saveMessage(message.copyWith(updatedAt: now));

    final reloaded = await _viewOf(message);
    final views = List<ChatMessageView>.of(snapshot.messages);
    final index = views.indexWhere((view) => view.id == messageId);
    if (index != -1) {
      views[index] = reloaded;
      _emit(views, isStreaming: false);
    }
  }

  // --- Translation ----------------------------------------------------------

  /// Translates [messageId]'s text into [language], attaching a streaming
  /// `TranslationBlock` to the message and streaming the result into it.
  ///
  /// Port of `MessageTranslateButton.handleTranslate`: builds the translate
  /// prompt, streams the translation from the translate model (the configured
  /// one, falling back to the current chat model), updates the block live, then
  /// finalizes to SUCCESS/ERROR and records the result in the translate history.
  /// A no-op while a reply is streaming, when the message has no text, or when
  /// no model is configured.
  Future<void> translateMessage(
    String messageId,
    TranslateLanguage language,
  ) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    final fetched = await _repo.getMessageBlocksByMessageId(messageId);
    final content = _mainTextOf(_orderBlocks(message.blocks, fetched)).trim();
    if (content.isEmpty) return;

    final current = await ref.read(translateModelProvider.future);
    if (current == null) return;
    final effective = effectiveModelFor(current);

    final now = DateTime.now();
    final translationBlockId = generateId('block');
    await _repo.saveMessageBlock(
      MessageBlock.translation(
        id: translationBlockId,
        messageId: messageId,
        status: MessageBlockStatus.streaming,
        createdAt: now,
        content: '翻译中...',
        sourceContent: content,
        sourceLanguage: '原文',
        targetLanguage: language.label,
      ),
    );
    await _repo.saveMessage(
      message.copyWith(
        blocks: [...message.blocks, translationBlockId],
        updatedAt: now,
      ),
    );
    await _reloadIntoState(messageId);

    final request = LlmChatRequest(
      model: effective,
      messages: [
        LlmMessage(
          role: MessageRole.user,
          content: buildTranslatePrompt(language, content),
        ),
      ],
      useResponsesAPI: current.provider.useResponsesAPI ?? false,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
    final buffer = StringBuffer();
    try {
      await for (final chunk in gateway.streamChat(request)) {
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
            _emitTranslationDelta(
              messageId,
              translationBlockId,
              buffer.toString(),
              MessageBlockStatus.streaming,
            );
          case LlmReasoningDelta():
            break;
          case LlmToolCallChunk():
            break;
          case LlmDone():
            break;
        }
      }
      final result = buffer.toString().trim();
      await _persistTranslationBlock(
        translationBlockId,
        result,
        MessageBlockStatus.success,
      );
      await _reloadIntoState(messageId);
      await ref
          .read(translateHistoryStoreProvider.notifier)
          .add(
            sourceText: content,
            targetText: result,
            sourceLanguage: kTranslateAutoLang,
            targetLanguage: language.langCode,
          );
    } on Object catch (error) {
      await _persistTranslationBlock(
        translationBlockId,
        '翻译失败：${_errorMessage(error)}',
        MessageBlockStatus.error,
      );
      await _reloadIntoState(messageId);
    }
  }

  /// Updates the in-memory translation block of [messageId] during streaming,
  /// without a DB write (the result is persisted once on finalize).
  void _emitTranslationDelta(
    String messageId,
    String blockId,
    String content,
    MessageBlockStatus status,
  ) {
    final snapshot = state.value;
    if (snapshot == null) return;
    final views = List<ChatMessageView>.of(snapshot.messages);
    final index = views.indexWhere((v) => v.id == messageId);
    if (index == -1) return;
    final view = views[index];
    final updatedBlocks = [
      for (final block in view.blocks)
        if (block.id == blockId && block is TranslationBlock)
          block.copyWith(content: content, status: status)
        else
          block,
    ];
    views[index] = view.copyWith(blocks: updatedBlocks);
    _emit(views, isStreaming: snapshot.isStreaming);
  }

  Future<void> _persistTranslationBlock(
    String blockId,
    String content,
    MessageBlockStatus status,
  ) async {
    final existing = await _repo.getMessageBlock(blockId);
    if (existing is TranslationBlock) {
      await _repo.saveMessageBlock(
        existing.copyWith(
          content: content,
          status: status,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  // --- Version history ------------------------------------------------------

  /// Maximum number of saved versions kept per message; older versions (and
  /// their cloned blocks) are pruned once exceeded. Mirrors
  /// `VersionService.MAX_VERSIONS_PER_MESSAGE`.
  static const int _maxVersionsPerMessage = 20;

  static const String _latestSnapshotKey = 'latestSnapshot';

  /// Manually saves the message's current content as a version (the 保存当前
  /// button). Port of `versionService.createManualVersion`. A no-op while a
  /// reply is streaming or when the content is empty.
  Future<void> createManualVersion(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    final updated = await _saveCurrentAsVersion(message, source: 'manual');
    if (updated == null) return;
    await _reloadIntoState(messageId);
  }

  /// Switches the displayed content of [messageId] to version [versionId].
  ///
  /// Port of `versionService.switchToVersion`: when leaving the latest (live)
  /// content for the first time the live blocks are stashed (so they can be
  /// restored later), then the message's blocks are replaced with clones of the
  /// version's blocks and [Message.currentVersionId] is set. A no-op while a
  /// reply is streaming.
  Future<void> switchToVersion(String messageId, String versionId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    var message = await _repo.getMessage(messageId);
    if (message == null) return;
    final version = _findVersion(message, versionId);
    if (version == null) return;

    final now = DateTime.now();
    // Stash the live content the first time we leave the latest view.
    if (message.currentVersionId == null) {
      message = await _stashLatestSnapshot(message, now);
    }

    final previousBlockIds = message.blocks;
    final versionBlocks = await _repo.getMessageBlocksByIds(version.blocks);
    final List<String> newBlockIds;
    if (versionBlocks.isNotEmpty) {
      final clones = _cloneBlocks(versionBlocks, messageId, now);
      await _repo.saveMessageBlocks(clones);
      newBlockIds = [for (final block in clones) block.id];
    } else {
      // No block copies survived: rebuild a single main_text block from the
      // version's content snapshot, like the web fallback.
      final blockId = generateId('block');
      await _repo.saveMessageBlock(
        MessageBlock.mainText(
          id: blockId,
          messageId: messageId,
          status: MessageBlockStatus.success,
          createdAt: now,
          updatedAt: now,
          content: _versionSnapshotText(version),
        ),
      );
      newBlockIds = <String>[blockId];
    }
    await _deleteBlocks(previousBlockIds);
    await _repo.saveMessage(
      message.copyWith(
        blocks: newBlockIds,
        currentVersionId: versionId,
        model: version.model ?? message.model,
        modelId: version.modelId ?? message.modelId,
        updatedAt: now,
      ),
    );
    await _reloadIntoState(messageId);
  }

  /// Switches [messageId] back to the latest (live) content, restoring the
  /// blocks stashed when history was first opened. Port of
  /// `versionService.switchToLatest`. A no-op while streaming or when already
  /// showing the latest content.
  Future<void> switchToLatest(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _repo.getMessage(messageId);
    if (message == null || message.currentVersionId == null) return;

    final now = DateTime.now();
    final snap = _latestSnapshot(message);
    final previousBlockIds = message.blocks;
    var restoredModel = message.model;
    var newBlockIds = previousBlockIds;

    if (snap != null && snap.blockIds.isNotEmpty) {
      final stashed = await _repo.getMessageBlocksByIds(snap.blockIds);
      if (stashed.isNotEmpty) {
        // Re-own the stashed blocks (they keep their ids) and drop the history
        // clones currently on display.
        final reowned = [
          for (final block in stashed)
            block.copyWith(messageId: messageId, updatedAt: now),
        ];
        await _repo.saveMessageBlocks(reowned);
        newBlockIds = [for (final block in reowned) block.id];
        restoredModel = snap.model ?? restoredModel;
        await _deleteBlocks(previousBlockIds);
      }
    }

    await _repo.saveMessage(
      message.copyWith(
        blocks: newBlockIds,
        currentVersionId: null,
        model: restoredModel,
        metadata: _metadataWithoutSnapshot(message),
        updatedAt: now,
      ),
    );
    await _reloadIntoState(messageId);
  }

  /// Deletes version [versionId] from [messageId] (the trash action). Port of
  /// `versionService.deleteVersion`: if the version is currently displayed the
  /// message first switches back to the latest content. A no-op while a reply
  /// is streaming.
  Future<void> deleteVersion(String messageId, String versionId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    var message = await _repo.getMessage(messageId);
    if (message == null) return;

    if (message.currentVersionId == versionId) {
      await switchToLatest(messageId);
      final refreshed = await _repo.getMessage(messageId);
      if (refreshed == null) return;
      message = refreshed;
    }

    final version = _findVersion(message, versionId);
    if (version == null) return;
    await _deleteBlocks(version.blocks);
    final remaining = [
      for (final v in message.versions ?? const <MessageVersion>[])
        if (v.id != versionId) v,
    ];
    await _repo.saveMessage(
      message.copyWith(versions: remaining, updatedAt: DateTime.now()),
    );
    await _reloadIntoState(messageId);
  }

  /// Archives the message's currently displayed content ahead of a regenerate.
  ///
  /// On the latest view it saves the live content as a `regenerate` version; on
  /// a historical view it promotes the stashed latest snapshot to a permanent
  /// version (so it survives) and clears the snapshot. The blocks on display
  /// are dropped by [regenerate] right after. Port of
  /// `versionService.prepareForRegenerate`.
  Future<Message> _prepareForRegenerate(Message message, DateTime now) async {
    if (message.currentVersionId == null) {
      return await _saveCurrentAsVersion(
            message,
            source: 'regenerate',
            timestamp: now,
          ) ??
          message;
    }
    return _promoteLatestSnapshot(message, now);
  }

  /// Clones the message's current blocks into a new [MessageVersion] and
  /// appends it (pruning the oldest beyond [_maxVersionsPerMessage]). Returns
  /// the updated message, or `null` when the content is empty (nothing to
  /// save). Port of `versionService.saveCurrentAsVersion`.
  Future<Message?> _saveCurrentAsVersion(
    Message message, {
    required String source,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    final blocks = await _repo.getMessageBlocksByIds(message.blocks);
    final content = _mainTextOf(blocks);
    if (content.trim().isEmpty) return null;

    final versionId = generateId('version');
    final clones = _cloneBlocks(blocks, 'version_$versionId', now);
    await _repo.saveMessageBlocks(clones);
    final version = MessageVersion(
      id: versionId,
      messageId: message.id,
      blocks: [for (final block in clones) block.id],
      createdAt: now,
      modelId: message.modelId,
      model: message.model,
      isActive: false,
      metadata: <String, dynamic>{
        'source': source,
        'timestamp': now.millisecondsSinceEpoch,
        'contentSnapshot': content,
      },
    );
    final versions = await _appendVersion(message.versions, version);
    final updated = message.copyWith(versions: versions);
    await _repo.saveMessage(updated);
    return updated;
  }

  /// Promotes the stashed latest snapshot into a permanent version and clears
  /// the snapshot + [Message.currentVersionId]. Used when regenerating while a
  /// historical version is on display, mirroring the history branch of
  /// `versionService.prepareForRegenerate`.
  Future<Message> _promoteLatestSnapshot(Message message, DateTime now) async {
    final snap = _latestSnapshot(message);
    var versions = message.versions ?? const <MessageVersion>[];
    if (snap != null && snap.blockIds.isNotEmpty) {
      final stashed = await _repo.getMessageBlocksByIds(snap.blockIds);
      final content = _mainTextOf(stashed);
      if (stashed.isNotEmpty && content.trim().isNotEmpty) {
        final versionId = generateId('version');
        final retagged = [
          for (final block in stashed)
            block.copyWith(messageId: 'version_$versionId', updatedAt: now),
        ];
        await _repo.saveMessageBlocks(retagged);
        versions = await _appendVersion(
          versions,
          MessageVersion(
            id: versionId,
            messageId: message.id,
            blocks: [for (final block in retagged) block.id],
            createdAt: now,
            model: snap.model ?? message.model,
            isActive: false,
            metadata: <String, dynamic>{
              'source': 'regenerate',
              'timestamp': now.millisecondsSinceEpoch,
              'contentSnapshot': content,
            },
          ),
        );
      } else {
        await _deleteBlocks(snap.blockIds);
      }
    }
    final updated = message.copyWith(
      versions: versions,
      currentVersionId: null,
      metadata: _metadataWithoutSnapshot(message),
    );
    await _repo.saveMessage(updated);
    return updated;
  }

  /// Clones the message's live blocks into a `latest_<id>` stash and records
  /// their ids + model in [Message.metadata] so the latest content can be
  /// restored after browsing history. Port of the snapshot half of
  /// `versionService.switchToVersion`.
  Future<Message> _stashLatestSnapshot(Message message, DateTime now) async {
    final live = await _repo.getMessageBlocksByIds(message.blocks);
    final stash = _cloneBlocks(live, 'latest_${message.id}', now);
    if (stash.isNotEmpty) await _repo.saveMessageBlocks(stash);
    final model = message.model;
    final metadata = <String, dynamic>{
      ...?message.metadata,
      _latestSnapshotKey: <String, dynamic>{
        'blocks': [for (final block in stash) block.id],
        if (model != null) 'model': model.toJson(),
      },
    };
    final updated = message.copyWith(metadata: metadata);
    await _repo.saveMessage(updated);
    return updated;
  }

  Future<List<MessageVersion>> _appendVersion(
    List<MessageVersion>? existing,
    MessageVersion version,
  ) async {
    final versions = [...?existing, version];
    if (versions.length > _maxVersionsPerMessage) {
      versions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      while (versions.length > _maxVersionsPerMessage) {
        final pruned = versions.removeAt(0);
        await _deleteBlocks(pruned.blocks);
      }
    }
    return versions;
  }

  List<MessageBlock> _cloneBlocks(
    List<MessageBlock> blocks,
    String clonedMessageId,
    DateTime now,
  ) {
    return [
      for (final block in blocks)
        block.copyWith(
          id: generateId('block'),
          messageId: clonedMessageId,
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  Future<void> _deleteBlocks(List<String> ids) async {
    for (final id in ids) {
      await _repo.deleteMessageBlock(id);
    }
  }

  MessageVersion? _findVersion(Message message, String versionId) {
    for (final version in message.versions ?? const <MessageVersion>[]) {
      if (version.id == versionId) return version;
    }
    return null;
  }

  String _mainTextOf(List<MessageBlock> blocks) => blocks
      .whereType<MainTextBlock>()
      .map((block) => block.content)
      .join('\n\n');

  /// Builds a `FILE` block for a pending composer [attachment], carrying its
  /// text inline as a base64 data URI (no disk file is written for this slice).
  MessageBlock _attachmentBlock({
    required String messageId,
    required DateTime createdAt,
    required ComposerAttachment attachment,
  }) {
    final base64Data =
        'data:${attachment.mimeType};base64,'
        '${base64Encode(utf8.encode(attachment.text))}';
    return MessageBlock.file(
      id: generateId('block'),
      messageId: messageId,
      status: MessageBlockStatus.success,
      createdAt: createdAt,
      name: attachment.name,
      url: '',
      mimeType: attachment.mimeType,
      size: attachment.size,
      file: MessageFileReference(
        id: attachment.id,
        name: attachment.name,
        originName: attachment.name,
        size: attachment.size,
        mimeType: attachment.mimeType,
        base64Data: base64Data,
      ),
    );
  }

  /// The request content for [view]: its main text with each FILE block's
  /// decoded text appended, so the model receives pasted-as-file content (and
  /// likewise for history, since [_viewOf] carries FILE blocks through).
  String _requestContent(ChatMessageView view) {
    final parts = <String>[
      if (view.text.isNotEmpty) view.text,
      for (final block in view.blocks)
        if (block is FileBlock)
          if (_decodeFileText(block) case final text? when text.isNotEmpty)
            text,
    ];
    return parts.join('\n\n');
  }

  /// Decodes a FILE block's inline text, or `null` when it carries no decodable
  /// `text/plain` base64 data URI.
  String? _decodeFileText(FileBlock block) {
    if (block.mimeType != 'text/plain') return null;
    final data = block.file?.base64Data;
    if (data == null || data.isEmpty) return null;
    final comma = data.indexOf(',');
    final encoded = comma >= 0 ? data.substring(comma + 1) : data;
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }

  String _versionSnapshotText(MessageVersion version) {
    final snapshot = version.metadata?['contentSnapshot'];
    return snapshot is String ? snapshot : '';
  }

  _LatestSnapshot? _latestSnapshot(Message message) {
    final raw = message.metadata?[_latestSnapshotKey];
    if (raw is! Map) return null;
    final blocks = raw['blocks'];
    final blockIds = blocks is List
        ? <String>[
            for (final id in blocks)
              if (id is String) id,
          ]
        : <String>[];
    final modelJson = raw['model'];
    final model = modelJson is Map
        ? Model.fromJson(Map<String, dynamic>.from(modelJson))
        : null;
    return _LatestSnapshot(blockIds: blockIds, model: model);
  }

  Map<String, dynamic>? _metadataWithoutSnapshot(Message message) {
    final metadata = message.metadata;
    if (metadata == null) return null;
    final next = <String, dynamic>{...metadata}..remove(_latestSnapshotKey);
    return next.isEmpty ? null : next;
  }

  /// Reloads [messageId]'s persisted view into the conversation state without a
  /// full topic reload, after a version mutation.
  Future<void> _reloadIntoState(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null) return;
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    final view = await _viewOf(message);
    final views = List<ChatMessageView>.of(snapshot.messages);
    final index = views.indexWhere((v) => v.id == messageId);
    if (index == -1) return;
    views[index] = view;
    _emit(views, isStreaming: false);
  }

  /// Reloads the persisted view for [messageId] (real blocks in order) after
  /// finalize; falls back to [fallback] if the message can't be read.
  Future<ChatMessageView> _reloadView(
    String messageId,
    ChatMessageView fallback,
  ) async {
    final message = await _repo.getMessage(messageId);
    if (message == null) return fallback;
    return _viewOf(message);
  }

  /// Assembles the system prompt for a conversation turn: the assistant's
  /// 系统提示词 combined with the 话题提示词 (the port of apiPreparation's
  /// `assistantPrompt [+ '\n\n' + topicPrompt]`), then appends the enabled
  /// 系统提示词变量 (time / location / OS). Returns `null` when the assembled
  /// prompt is empty, so requests with no system prompt stay system-less
  /// (variables are append-only and never injected into an empty prompt,
  /// matching the web `injectSystemPromptVariables`).
  Future<String?> _buildSystemPrompt() async {
    final assistant = await _repo.getAssistant(_assistantId);
    final assistantPrompt = assistant?.systemPrompt ?? '';
    final topicId = _topicId;
    final topic = topicId == null ? null : await _repo.getTopic(topicId);
    final topicPrompt = (topic?.prompt?.trim().isNotEmpty ?? false)
        ? topic!.prompt!
        : '';

    final enabledSkills = await _enabledSkillsFor(assistant?.skillIds);
    final base = enabledSkills.isNotEmpty
        ? assembleSkillSystemPrompt(
            assistantPrompt: assistantPrompt,
            enabledSkills: enabledSkills,
            topicPrompt: topicPrompt,
          )
        : (topicPrompt.isNotEmpty
              ? (assistantPrompt.isNotEmpty
                    ? '$assistantPrompt\n\n$topicPrompt'
                    : topicPrompt)
              : assistantPrompt);

    final injected = injectSystemPromptVariables(
      base,
      ref.read(systemPromptVariablesProvider),
    );
    return injected.isEmpty ? null : injected;
  }

  /// The skills bound to the assistant ([skillIds]) that are currently enabled,
  /// in binding order — the port of `SkillManager.getSkillsForAssistant`.
  Future<List<Skill>> _enabledSkillsFor(List<String>? skillIds) async {
    if (skillIds == null || skillIds.isEmpty) return const <Skill>[];
    final skills = await ref.read(skillsProvider.future);
    final byId = {for (final s in skills) s.id: s};
    return [
      for (final id in skillIds)
        if (byId[id]?.enabled ?? false) byId[id]!,
    ];
  }

  /// Assembles the [_McpSetup] for the current turn — the port of the web
  /// `fetchMcpTools(toolsEnabled, hasSkills)`. Three switches drive it
  /// ([McpToolsController]): the 工具 总开关, 桥梁模式, and the 技能 独立开关.
  ///
  /// `read_skill` is injected (and only it) whenever 技能开关 is on AND the
  /// assistant has bound, enabled skills — independent of the 工具 总开关 and 桥梁
  /// 模式, exactly like the web. With the 工具 总开关 on: 桥梁模式 replaces every
  /// server's tools with the single `mcp_bridge` tool; otherwise built-in
  /// (locally-runnable) + remote (discovered live) server tools are injected as
  /// before, each minus its `disabledTools`. A remote server that is unreachable
  /// degrades gracefully — it simply contributes no tools this turn.
  Future<_McpSetup> _mcpSetup() async {
    final toolsState = ref.read(mcpToolsControllerProvider);

    final assistant = await _repo.getAssistant(_assistantId);
    final boundSkills = await _enabledSkillsFor(assistant?.skillIds);
    final injectReadSkill = toolsState.skillsEnabled && boundSkills.isNotEmpty;

    final tools = <McpToolDefinition>[];
    final routes = <String, _ToolRoute>{};

    void addReadSkill() {
      if (!injectReadSkill) return;
      tools.add(kReadSkillToolDefinition);
      routes[kReadSkillToolName] = const _SkillReadToolRoute();
    }

    // 工具 总开关 off: only read_skill may ride along (web parity).
    if (!toolsState.enabled) {
      addReadSkill();
      if (tools.isEmpty) return const _McpSetup.disabled();
      return _McpSetup(mode: toolsState.mode, tools: tools, routes: routes);
    }

    // 桥梁模式: 1 个 mcp_bridge 工具替代注入全部服务器工具。
    if (toolsState.bridgeMode) {
      tools.add(kMcpBridgeToolDefinition);
      routes[kMcpBridgeToolName] = const _BridgeToolRoute();
      addReadSkill();
      return _McpSetup(mode: toolsState.mode, tools: tools, routes: routes);
    }

    final servers = await ref.read(mcpServersProvider.future);
    for (final server in servers) {
      if (!server.isActive) continue;

      // Built-in (locally-runnable) servers: static catalogue, run in-process.
      if (kLocallyRunnableBuiltins.contains(server.name)) {
        final disabled = server.disabledTools?.toSet() ?? const <String>{};
        for (final tool in builtinToolsFor(server.name)) {
          if (disabled.contains(tool.name)) continue;
          if (routes.containsKey(tool.name)) continue;
          tools.add(tool);
          routes[tool.name] = _BuiltinToolRoute(server.name, tool.name);
        }
        continue;
      }

      // Remote (sse / streamableHttp) servers: discover tools live; the manager
      // already filters out `disabledTools` and prefixes names for collision
      // safety. First-wins on duplicate exposed names.
      if (RemoteMcpConnectionManager.isRemote(server)) {
        try {
          final discovered = await ref
              .read(remoteMcpConnectionManagerProvider)
              .listTools(server);
          for (final tool in discovered) {
            final exposed = tool.definition.name;
            if (routes.containsKey(exposed)) continue;
            tools.add(tool.definition);
            routes[exposed] = _RemoteToolRoute(server, tool.toolName);
          }
        } on Object {
          // Unreachable / failing server: skip it for this turn.
        }
      }
    }

    addReadSkill();
    return _McpSetup(mode: toolsState.mode, tools: tools, routes: routes);
  }

  /// Executes one tool call along its [route]: a built-in runs in-process via
  /// [runBuiltinTool]; a remote tool is dispatched to its server through
  /// [RemoteMcpConnectionManager]. A remote failure becomes an error result (fed
  /// back to the model) rather than aborting the whole turn. [exposedName] is the
  /// model-facing name, used only for messages.
  Future<McpToolResult> _runTool(
    _ToolRoute route,
    String exposedName,
    Map<String, Object?> args,
  ) async {
    switch (route) {
      case _BuiltinToolRoute(:final serverName):
        return runBuiltinTool(serverName, route.toolName, args) ??
            McpToolResult('工具 $exposedName 无法在本地执行', isError: true);
      case _RemoteToolRoute(:final server):
        try {
          return await ref
              .read(remoteMcpConnectionManagerProvider)
              .callTool(server, route.toolName, args);
        } on Object catch (error) {
          return McpToolResult(
            '工具 $exposedName 调用失败: ${_errorMessage(error)}',
            isError: true,
          );
        }
      case _SkillReadToolRoute():
        final skills = await ref.read(skillsProvider.future);
        return executeReadSkill(skills, args);
      case _BridgeToolRoute():
        return _runBridgeTool(args);
    }
  }

  /// Executes one `mcp_bridge` call — the port of `executeBridgeToolCall`.
  /// Dispatches by `action`: list every configured server, list one server's
  /// tools, or call a tool on a server (built-in run in-process, remote over a
  /// live connection). Errors become error results fed back to the model.
  Future<McpToolResult> _runBridgeTool(Map<String, Object?> args) async {
    final action = args['action'] as String?;
    final server = args['server'] as String?;
    final tool = args['tool'] as String?;
    final toolArgs =
        (args['arguments'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    try {
      switch (action) {
        case 'list_servers':
          return _bridgeListServers();
        case 'list_tools':
          return _bridgeListTools(server);
        case 'call':
          return _bridgeCallTool(server, tool, toolArgs);
        default:
          return McpToolResult(
            '未知操作: $action。支持的操作: list_servers, list_tools, call',
            isError: true,
          );
      }
    } on Object catch (error) {
      return McpToolResult(
        'Bridge 执行失败: ${_errorMessage(error)}',
        isError: true,
      );
    }
  }

  Future<McpToolResult> _bridgeListServers() async {
    final servers = await ref.read(mcpServersProvider.future);
    if (servers.isEmpty) {
      return const McpToolResult('当前没有配置任何 MCP 服务器。请在设置中添加 MCP 服务器。');
    }
    final summary = servers
        .map(
          (s) =>
              '- ${s.name} [${s.isActive ? '✅ 已启用' : '⬚ 未启用'}] ${s.description ?? ''}',
        )
        .join('\n');
    final detail = const JsonEncoder.withIndent('  ').convert([
      for (final s in servers)
        {
          'name': s.name,
          'id': s.id,
          'type': s.type.name,
          'isActive': s.isActive,
          'description': s.description ?? '',
        },
    ]);
    return McpToolResult(
      '可用的 MCP 服务器（${servers.length} 个）：\n$summary\n\n'
      '提示：使用 list_tools 查看具体服务器的工具列表，使用 call 调用工具。\n'
      '注意：仅已启用（✅）的服务器可以调用，未启用的服务器需先在设置中手动启用。\n\n'
      '详细数据：\n$detail',
    );
  }

  Future<McpToolResult> _bridgeListTools(String? serverName) async {
    if (serverName == null || serverName.isEmpty) {
      return const McpToolResult(
        'list_tools 需要提供 server 参数（服务器名称）',
        isError: true,
      );
    }
    final servers = await ref.read(mcpServersProvider.future);
    final server = _findServerByName(servers, serverName);
    if (server == null) {
      final available = servers.map((s) => s.name).join(', ');
      return McpToolResult(
        '未找到服务器: "$serverName"。可用的服务器: ${available.isEmpty ? '无' : available}',
        isError: true,
      );
    }
    try {
      final tools = await _bridgeServerTools(server);
      if (tools.isEmpty) {
        return McpToolResult('服务器 "${server.name}" 没有提供任何工具。');
      }
      final summary = tools
          .map(
            (t) =>
                '- ${t.name}: ${t.description.isEmpty ? '无描述' : t.description}',
          )
          .join('\n');
      final detail = const JsonEncoder.withIndent('  ').convert([
        for (final t in tools)
          {
            'name': t.name,
            'description': t.description,
            'parameters': t.inputSchema,
          },
      ]);
      return McpToolResult(
        '服务器 "${server.name}" 提供 ${tools.length} 个工具：\n$summary\n\n详细参数：\n$detail',
      );
    } on Object catch (error) {
      return McpToolResult(
        '获取服务器 "${server.name}" 的工具列表失败: ${_errorMessage(error)}',
        isError: true,
      );
    }
  }

  Future<McpToolResult> _bridgeCallTool(
    String? serverName,
    String? toolName,
    Map<String, Object?> toolArgs,
  ) async {
    if (serverName == null || serverName.isEmpty) {
      return const McpToolResult('call 需要提供 server 参数（服务器名称）', isError: true);
    }
    if (toolName == null || toolName.isEmpty) {
      return const McpToolResult('call 需要提供 tool 参数（工具名称）', isError: true);
    }
    final servers = await ref.read(mcpServersProvider.future);
    final server = _findServerByName(servers, serverName);
    if (server == null) {
      final available = servers.map((s) => s.name).join(', ');
      return McpToolResult(
        '未找到服务器: "$serverName"。可用的服务器: ${available.isEmpty ? '无' : available}',
        isError: true,
      );
    }
    if (kLocallyRunnableBuiltins.contains(server.name)) {
      return runBuiltinTool(server.name, toolName, toolArgs) ??
          McpToolResult('工具 $toolName 无法在本地执行', isError: true);
    }
    return ref
        .read(remoteMcpConnectionManagerProvider)
        .callTool(server, toolName, toolArgs);
  }

  /// The tools a server exposes for the bridge: built-ins use the static
  /// catalogue (minus `disabledTools`); remote servers are discovered live.
  Future<List<McpToolDefinition>> _bridgeServerTools(McpServer server) async {
    if (kBuiltinMcpTools.containsKey(server.name)) {
      final disabled = server.disabledTools?.toSet() ?? const <String>{};
      return builtinToolsFor(
        server.name,
      ).where((t) => !disabled.contains(t.name)).toList();
    }
    if (RemoteMcpConnectionManager.isRemote(server)) {
      final discovered = await ref
          .read(remoteMcpConnectionManagerProvider)
          .listTools(server);
      return [for (final t in discovered) t.definition];
    }
    return const <McpToolDefinition>[];
  }

  /// Finds a server by name — exact → case-insensitive → substring, the port of
  /// the bridge's `findServerByName`.
  McpServer? _findServerByName(List<McpServer> servers, String name) {
    final lower = name.toLowerCase();
    return servers.where((s) => s.name == name).firstOrNull ??
        servers.where((s) => s.name.toLowerCase() == lower).firstOrNull ??
        servers.where((s) => s.name.toLowerCase().contains(lower)).firstOrNull;
  }

  /// The system prompt for a turn: in 提示词注入 mode the tool catalogue is woven
  /// into [base] (web `buildSystemPrompt`); otherwise [base] is used as-is and
  /// tools ride the native `tools` field.
  String? _systemFor(_McpSetup mcp, String? base) =>
      mcp.usePromptInjection ? buildMcpSystemPrompt(base, mcp.tools) : base;

  Future<String> _ensureTopic() async {
    final existing = _topicId;
    if (existing != null) return existing;
    final now = DateTime.now();
    final topicId = generateId('topic');
    await _repo.saveTopic(
      Topic(
        id: topicId,
        assistantId: _assistantId,
        name: '新对话',
        createdAt: now,
        updatedAt: now,
      ),
    );
    _topicId = topicId;
    return topicId;
  }

  Future<ChatMessageView> _viewOf(Message message) async {
    final fetched = await _repo.getMessageBlocksByMessageId(message.id);
    final blocks = _orderBlocks(message.blocks, fetched);
    final text = blocks
        .whereType<MainTextBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final thinking = blocks
        .whereType<ThinkingBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final errors = blocks.whereType<ErrorBlock>();
    final error = errors.isEmpty ? null : errors.first;
    final model = message.model;
    String? providerName;
    if (model != null) {
      final providers = await ref.read(appModelProvidersProvider.future);
      for (final provider in providers) {
        if (provider.id == model.provider) {
          providerName = provider.name;
          break;
        }
      }
    }
    return ChatMessageView(
      id: message.id,
      role: message.role,
      status: message.status,
      blocks: blocks,
      text: text,
      thinking: thinking,
      errorText: error?.message ?? error?.content,
      createdAt: message.createdAt,
      modelName: model?.name,
      providerName: providerName,
      versions: message.versions ?? const <MessageVersion>[],
      currentVersionId: message.currentVersionId,
      usage: message.usage,
      metrics: message.metrics,
    );
  }

  /// Returns [blocks] sorted by the `message.blocks` id order (the canonical
  /// render order); any block not referenced there is appended at the end.
  List<MessageBlock> _orderBlocks(
    List<String> order,
    List<MessageBlock> blocks,
  ) {
    if (order.isEmpty) return blocks;
    final byId = {for (final block in blocks) block.id: block};
    final ordered = <MessageBlock>[];
    for (final id in order) {
      final block = byId.remove(id);
      if (block != null) ordered.add(block);
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  void _emit(List<ChatMessageView> views, {required bool isStreaming}) {
    state = AsyncData(
      ChatState(
        messages: List<ChatMessageView>.of(views),
        isStreaming: isStreaming,
      ),
    );
  }

  void _replace(List<ChatMessageView> views, ChatMessageView view) {
    final index = views.indexWhere((v) => v.id == view.id);
    if (index != -1) views[index] = view;
  }

  String _errorMessage(Object error) {
    if (error is Failure) return error.message;
    return error.toString();
  }
}

/// The latest (live) content stashed in [Message.metadata] while a historical
/// version is on display: the ids of the cloned blocks plus the model that
/// produced them, restored by [ChatController.switchToLatest].
class _LatestSnapshot {
  const _LatestSnapshot({required this.blockIds, required this.model});

  final List<String> blockIds;
  final Model? model;
}

/// Raised when a provider has a multi-key pool but every key is disabled,
/// errored or still cooling down and there is no single-key fallback — surfaced
/// as the assistant message's error so the user knows to re-enable / add a key.
class _NoUsableApiKeyException implements Exception {
  const _NoUsableApiKeyException();

  @override
  String toString() => '没有可用的 API Key：所有 Key 已禁用、失败或处于冷却中。';
}

/// The MCP tool context assembled for one chat turn: the resolved [mode], the
/// [tools] to expose (启用 built-ins + 启用 remote servers' discovered tools) and
/// the [routes] map that dispatches each exposed tool name back to its source —
/// a locally-runnable built-in ([_BuiltinToolRoute]) or a remote server
/// ([_RemoteToolRoute]). [tools] is empty when MCP 工具 is off or no eligible
/// server is active, in which case the turn streams plain text exactly as before.
class _McpSetup {
  const _McpSetup({
    required this.mode,
    required this.tools,
    required this.routes,
  });

  const _McpSetup.disabled()
    : mode = McpMode.function,
      tools = const <McpToolDefinition>[],
      routes = const <String, _ToolRoute>{};

  final McpMode mode;
  final List<McpToolDefinition> tools;
  final Map<String, _ToolRoute> routes;

  bool get hasTools => tools.isNotEmpty;

  /// Expose tools via the model's native function-calling API (`tools` field).
  bool get useFunctionTools => hasTools && mode == McpMode.function;

  /// Describe tools in the system prompt and parse XML `<tool_use>` locally.
  bool get usePromptInjection => hasTools && mode == McpMode.prompt;
}

/// How an exposed tool name dispatches back to its source. [toolName] is the
/// original (un-prefixed) wire name; the map key it is stored under is the
/// model-facing exposed name (identical for built-ins, function-call-safe for
/// remote — see `buildFunctionCallToolName`).
sealed class _ToolRoute {
  const _ToolRoute(this.toolName);

  final String toolName;
}

/// A tool run in-process by [runBuiltinTool] (calculator / time).
class _BuiltinToolRoute extends _ToolRoute {
  const _BuiltinToolRoute(this.serverName, super.toolName);

  final String serverName;
}

/// The synthetic `read_skill` tool, run in-process against the skills store.
class _SkillReadToolRoute extends _ToolRoute {
  const _SkillReadToolRoute() : super(kReadSkillToolName);
}

/// The synthetic `mcp_bridge` tool, dispatched in-process to the configured
/// servers (built-in or remote) on demand.
class _BridgeToolRoute extends _ToolRoute {
  const _BridgeToolRoute() : super(kMcpBridgeToolName);
}

/// A tool executed over a live connection to [server] via
/// [RemoteMcpConnectionManager].
class _RemoteToolRoute extends _ToolRoute {
  const _RemoteToolRoute(this.server, super.toolName);

  final McpServer server;
}
