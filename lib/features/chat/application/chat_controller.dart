import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/mcp_servers_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/system_prompt_variables_access.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/translate_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_prompt.dart';
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
  /// blank message, a missing current model, or an in-flight stream are no-ops
  /// (the composer also disables the button in those cases).
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final snapshot = state.value ?? ChatState.initial();
    if (snapshot.isStreaming) return;

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    final topicId = await _ensureTopic();
    final now = DateTime.now();

    // 1. User message + main_text block, persisted.
    final userMessageId = generateId('msg');
    final userBlockId = generateId('block');
    final userMessage = Message(
      id: userMessageId,
      role: MessageRole.user,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.success,
      blocks: <String>[userBlockId],
    );
    await _repo.saveMessage(userMessage);
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: userBlockId,
        messageId: userMessageId,
        status: MessageBlockStatus.success,
        createdAt: now,
        content: trimmed,
      ),
    );

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
      blocks: <MessageBlock>[
        MessageBlock.mainText(
          id: userBlockId,
          messageId: userMessageId,
          status: MessageBlockStatus.success,
          createdAt: now,
          content: trimmed,
        ),
      ],
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
            LlmMessage(role: view.role, content: view.text),
      ],
      tools: mcp.useFunctionTools ? mcp.tools : null,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
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
            LlmMessage(role: view.role, content: view.text),
      ],
      tools: mcp.useFunctionTools ? mcp.tools : null,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
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
            LlmMessage(role: view.role, content: view.text),
      ],
      tools: mcp.useFunctionTools ? mcp.tools : null,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
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
    required String assistantMessageId,
    required String assistantBlockId,
    required DateTime assistantTime,
    required List<ChatMessageView> views,
    required ChatMessageView assistantView,
    required _McpSetup mcp,
  }) async {
    final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);

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

    try {
      for (var round = 0; ; round++) {
        buffer.clear();
        final structuredCalls = <LlmToolCall>[];
        await for (final chunk in gateway.streamChat(
          request.copyWith(messages: messages),
        )) {
          switch (chunk) {
            case LlmTextDelta(:final text):
              buffer.write(text);
              update();
            case LlmReasoningDelta(:final text):
              thinking.write(text);
              update();
            case LlmToolCallChunk(:final call):
              structuredCalls.add(call);
            case LlmDone():
              break;
          }
        }

        final roundText = buffer.toString();
        // 提示词注入 mode parses the model's XML; function mode gets the calls as
        // structured stream events.
        final requested = mcp.usePromptInjection
            ? [
                for (final use in parseToolUseBlocks(roundText, mcp.tools))
                  LlmToolCall(id: '', name: use.name, arguments: use.arguments),
              ]
            : structuredCalls;
        final runnable = <LlmToolCall>[
          for (final call in requested)
            if (mcp.serverByToolName.containsKey(call.name)) call,
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

        // Run each requested built-in locally and render a 工具 block per call.
        final results = <({LlmToolCall call, McpToolResult result})>[];
        for (final call in runnable) {
          final serverName = mcp.serverByToolName[call.name]!;
          final args = decodeToolArguments(call.arguments);
          final result =
              runBuiltinTool(serverName, call.name, args) ??
              McpToolResult('工具 ${call.name} 无法在本地执行', isError: true);
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

      await _persistMessageBlocks(
        messageId: assistantMessageId,
        status: MessageStatus.success,
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
      view = await _reloadView(assistantMessageId, view);
      _replace(views, view);
      _emit(views, isStreaming: false);
    } on Object catch (error) {
      final messageText = _errorMessage(error);
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
  }

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

    var base = assistantPrompt;
    if (topicPrompt.isNotEmpty) {
      base = base.isNotEmpty ? '$base\n\n$topicPrompt' : topicPrompt;
    }

    final injected = injectSystemPromptVariables(
      base,
      ref.read(systemPromptVariablesProvider),
    );
    return injected.isEmpty ? null : injected;
  }

  /// Assembles the [_McpSetup] for the current turn from the persisted MCP 工具
  /// 总开关 + 调用模式 ([McpToolsController]) and the active configured servers
  /// ([McpServers]). Only 启用 servers whose name is a locally-runnable built-in
  /// ([kLocallyRunnableBuiltins]) contribute tools, and a server's
  /// `disabledTools` are skipped. Returns a disabled setup when the master
  /// toggle is off, so non-MCP turns stream exactly as before.
  Future<_McpSetup> _mcpSetup() async {
    final toolsState = ref.read(mcpToolsControllerProvider);
    if (!toolsState.enabled) return const _McpSetup.disabled();

    final servers = await ref.read(mcpServersProvider.future);
    final tools = <McpToolDefinition>[];
    final serverByToolName = <String, String>{};
    for (final server in servers) {
      if (!server.isActive) continue;
      if (!kLocallyRunnableBuiltins.contains(server.name)) continue;
      final disabled = server.disabledTools?.toSet() ?? const <String>{};
      for (final tool in builtinToolsFor(server.name)) {
        if (disabled.contains(tool.name)) continue;
        if (serverByToolName.containsKey(tool.name)) continue;
        tools.add(tool);
        serverByToolName[tool.name] = server.name;
      }
    }
    return _McpSetup(
      mode: toolsState.mode,
      tools: tools,
      serverByToolName: serverByToolName,
    );
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

/// The MCP tool context assembled for one chat turn: the resolved [mode], the
/// [tools] to expose (only 启用 + locally-runnable built-ins) and the
/// [serverByToolName] routing map used to dispatch a call back to its built-in
/// server. [tools] is empty when MCP 工具 is off or no eligible server is active,
/// in which case the turn streams plain text exactly as before.
class _McpSetup {
  const _McpSetup({
    required this.mode,
    required this.tools,
    required this.serverByToolName,
  });

  const _McpSetup.disabled()
    : mode = McpMode.function,
      tools = const <McpToolDefinition>[],
      serverByToolName = const <String, String>{};

  final McpMode mode;
  final List<McpToolDefinition> tools;
  final Map<String, String> serverByToolName;

  bool get hasTools => tools.isNotEmpty;

  /// Expose tools via the model's native function-calling API (`tools` field).
  bool get useFunctionTools => hasTools && mode == McpMode.function;

  /// Describe tools in the system prompt and parse XML `<tool_use>` locally.
  bool get usePromptInjection => hasTools && mode == McpMode.prompt;
}
