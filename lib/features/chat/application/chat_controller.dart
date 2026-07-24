import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/combo_executor.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_providers.dart';
import 'package:aetherlink_flutter/shared/domain/model_combo.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/media/media_generation_api.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_send_hooks.dart';
import 'package:aetherlink_flutter/features/chat/application/send/interrupted_settlement.dart'
    as send_svc;
import 'package:aetherlink_flutter/features/chat/application/send/llm_history_builder.dart';
import 'package:aetherlink_flutter/features/chat/application/send/llm_request_params.dart';
import 'package:aetherlink_flutter/features/chat/application/send/message_view_projector.dart';
import 'package:aetherlink_flutter/features/chat/application/send/system_prompt_builder.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_versioning.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/mounted_knowledge_bases_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/multi_model_mentions_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/streaming_registry.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_confirmation.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_auth_policy.dart'
    show toolAuthPolicyProvider;
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart'
    show terminalCommandIsHighRisk;
import 'package:aetherlink_flutter/features/chat/application/tools/tool_executor.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_setup.dart';
import 'package:aetherlink_flutter/features/chat/application/suggestion_service.dart';
import 'package:aetherlink_flutter/features/chat/application/translate_controller.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_manager.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_ordering.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_file_reference.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_extraction.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_prompt.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/running_commands_service.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';

part 'chat_controller.g.dart';
part 'chat_controller_debate.dart';
part 'chat_controller_media_generation.dart';
part 'chat_controller_multi_model.dart';
part 'chat_controller_post_turn.dart';
part 'chat_controller_streaming.dart';
part 'chat_controller_translate.dart';

const String _toolModeMetadataKey = kToolModeMetadataKey;
const String _toolRoundMetadataKey = kToolRoundMetadataKey;

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
class ChatController extends _$ChatController
    with
        _ChatDebate,
        _ChatMediaGeneration,
        _ChatMultiModel,
        _ChatPostTurn,
        _ChatTranslate,
        _ChatStreaming {
  static const String _defaultAssistantId = 'default-assistant';

  @override
  String? _topicId;
  @override
  String _assistantId = _defaultAssistantId;

  /// The id of the last assistant message that was truncated due to
  /// `finishReason == 'length'` after exhausting auto-continues. Cleared on
  /// the next send / regenerate. The UI reads this to show a "继续生成" button.
  @override
  String? _truncatedMessageId;

  @override
  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  /// Message version history operations (manual save / switch / delete /
  /// regenerate-time archival), extracted to [MessageVersioning].
  MessageVersioning get _versioning => MessageVersioning(_repo);

  /// Runs each tool call along its [ToolRoute] (in-process built-in / remote
  /// MCP / bridge / web search / memory search).
  @override
  late final ChatToolExecutor _toolExecutor = ChatToolExecutor(
    // Resolved lazily: `ref` returns a new object after every rebuild, and a
    // long tool-call turn routinely spans rebuilds (topic updates re-run
    // build()), so capturing the Ref by value here would leave the executor
    // holding a disposed Ref.
    () => ref,
    assistantId: () => _assistantId,
    sessionId: () => _topicId ?? '',
  );

  @override
  StreamingRegistry get _registry =>
      ref.read(streamingRegistryProvider.notifier);

  /// Serialises views into LLM history (tool rounds, 正则, OCR fallback);
  /// extracted to [LlmHistoryBuilder]. Same lazy-Ref rationale as
  /// [_toolExecutor].
  late final LlmHistoryBuilder _historyBuilder = LlmHistoryBuilder(() => ref);

  /// Assembles the per-turn system prompt (skills / memory / MCP hints);
  /// extracted to [SystemPromptBuilder].
  late final SystemPromptBuilder _systemPromptBuilder = SystemPromptBuilder(
    () => ref,
    repo: () => _repo,
    assistantId: () => _assistantId,
    topicId: () => _topicId,
  );

  /// Projects persisted [Message]s into rendered [ChatMessageView]s;
  /// extracted to [MessageViewProjector].
  late final MessageViewProjector _viewProjector = MessageViewProjector(
    () => ref,
    repo: () => _repo,
    debatePhaseOf: _debatePhaseOf,
  );

  /// Aborts the streaming reply of the *current* topic, if any. The partial
  /// output already generated is kept and persisted (mirrors Cherry Studio's
  /// stop behaviour). No-op when the current topic isn't streaming.
  void stopStreaming() {
    final topicId = _topicId;
    if (topicId == null) return;
    _registry.cancel(topicId);
  }

  /// Emits a streaming update for [turnTopicId]'s reply. The live conversation
  /// is always written to the per-topic [StreamingRegistry] (so the stream keeps
  /// running and stays visible in the topic list even after the user switches
  /// away); the on-screen [ChatState] is only touched when [turnTopicId] is the
  /// topic currently being displayed. This is what makes switching topics
  /// mid-stream instant while the old topic keeps generating in the background.
  @override
  void _emitTurn(
    String turnTopicId,
    List<ChatMessageView> views, {
    required bool streaming,
  }) {
    if (streaming) {
      _registry.update(turnTopicId, views);
    } else {
      _registry.finish(turnTopicId);
    }
    if (turnTopicId == _topicId) {
      _emit(views, isStreaming: streaming);
    }
  }

  @override
  Future<ChatState> build() async {
    // The background keep-alive notification is owned by the StreamingRegistry
    // (started on the first streaming topic, stopped on the last). It must NOT be
    // ended here: build() re-runs on every topic switch, so ending it on dispose
    // would kill the notification while a switched-away topic keeps generating.
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

    // If this topic is generating in the background, show its live in-flight
    // conversation (read once, not watched: subsequent chunks for the now-current
    // topic update the state directly via _emit). This is what lets the user
    // switch back to a still-generating topic and pick up where it is.
    final liveViews = ref.read(streamingRegistryProvider).viewsFor(topic.id);
    if (liveViews != null) {
      return ChatState(
        messages: List<ChatMessageView>.of(liveViews),
        isStreaming: true,
      );
    }

    // 崩溃恢复（对齐 Cherry Studio 启动时的 reconcile）：走到这里说明该话题没有
    // 活跃流，凡是仍停在 streaming 状态的消息都是上次运行（闪退/被杀）遗留的，
    // 把它们连同检查点已落盘的内容一起落定，避免对话丢失或永远转圈。
    await _settleInterruptedMessages(topic.id);

    // Display order now comes from the message tree (active path + inlined
    // multi-model siblings); getBranchMessages falls back to a chronological
    // sort when the tree can't project faithfully, so the set never changes.
    final messages = await _repo.getBranchMessages(topic.id);
    // Group every content message by parent so each displayed node can report
    // its regular (non multi-model) branch siblings — the 叉路 switcher data.
    final all = await _repo.getMessagesByTopicId(topic.id);
    final childrenByParent = <String, List<Message>>{};
    for (final m in all) {
      (childrenByParent[m.parentId ?? ''] ??= <Message>[]).add(m);
    }
    final views = <ChatMessageView>[];
    for (final message in messages) {
      var view = await _viewOf(message);
      final siblings = _branchSiblingIdsOf(message, childrenByParent);
      if (siblings.length > 1) {
        view = view.copyWith(branchSiblingIds: siblings);
      }
      views.add(view);
    }
    return ChatState(messages: views);
  }

  /// The ids of [message]'s regular branch siblings (its parent's children with
  /// `siblingsGroupId == 0`, chronologically ordered) when there is a 叉路 — used
  /// by the `◀ k/n ▶` branch switcher. Returns empty when [message] is part of a
  /// multi-model group or there is only one branch. Multi-model groups are a
  /// separate concern handled by the comparison group widget.
  List<String> _branchSiblingIdsOf(
    Message message,
    Map<String, List<Message>> childrenByParent,
  ) {
    final parent = message.parentId;
    if (parent == null || message.siblingsGroupId != 0) {
      return const <String>[];
    }
    final siblings =
        (childrenByParent[parent] ?? const <Message>[])
            .where((c) => c.siblingsGroupId == 0)
            .toList()
          ..sort(compareMessagesChronologically);
    if (siblings.length <= 1) return const <String>[];
    return [for (final s in siblings) s.id];
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

    // 发送拦截缝（AI 辩论插话等）：拦截器消费后不再触发常规回复，
    // 且不受 isStreaming 限制（辩论进行中大部分时间在流式）。
    final interceptor = ref.read(chatSendInterceptorHolderProvider);
    if (interceptor != null && trimmed.isNotEmpty && attachments.isEmpty) {
      if (await interceptor(trimmed)) return;
    }

    _truncatedMessageId = null;
    final snapshot = state.value ?? ChatState.initial();
    if (snapshot.isStreaming) return;

    // 图像/视频生成模式（输入框互斥模式）优先：这一轮不走 LLM 对话，而是
    // 直接调相应供应商的生成 API（web handleMessageSend 的模式分发）。
    final inputMode = ref.read(inputModeControllerProvider);
    if (trimmed.isNotEmpty &&
        (inputMode == InputMode.image || inputMode == InputMode.video)) {
      await _sendMediaGeneration(
        inputMode!,
        trimmed,
        attachments: attachments,
        snapshot: snapshot,
      );
      return;
    }

    // Staged 多模型发送 mentions take priority: fan this turn out to every chosen
    // model, then clear the staged selection (a one-shot, like the web).
    final mentions = ref.read(multiModelMentionsProvider);
    if (mentions.isNotEmpty) {
      ref.read(multiModelMentionsProvider.notifier).clear();
      await sendMultiModel(trimmed, mentions, attachments: attachments);
      return;
    }

    // Check if a combo is active — if so, delegate to the combo flow.
    final comboState = ref.read(modelComboControllerProvider);
    final activeComboId = comboState.selectedComboId;
    if (activeComboId != null) {
      final resolution = await ref.read(
        resolveComboProvider(activeComboId).future,
      );
      if (resolution != null &&
          resolution.combo.strategy == ModelComboStrategy.sequential) {
        await _sendCombo(trimmed, resolution, attachments: attachments);
        return;
      }
    }

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
    _emitTurn(topicId, views, streaming: true);

    // 3. Build the request from the current model + history (the user turn we
    // just added included; the empty assistant placeholder excluded).
    final mcp = await _mcpSetup();
    final ctx = _contextSettings();
    final params = _parameterFields();
    final contextViews = _trimViews(
      _filterSiblingsForContext(views),
      ctx.contextCount,
    );
    final regexRules = await _sendingRegexRules();
    final messages = await _buildLlmMessages(
      contextViews,
      chatModel: effective,
      regexRules: regexRules,
      toolMode: mcp.mode,
    );
    final memInjection = await collectChatMemoryInjection(
      ref,
      assistantId: _assistantId,
      query: trimmed,
    );
    final kbInjection = await collectChatKnowledgeInjection(
      ref,
      baseIds: ref.read(mountedKnowledgeBasesProvider),
      query: trimmed,
    );
    final request = LlmChatRequest(
      model: effective,
      system: _systemFor(
        mcp,
        await _buildSystemPromptWith(
          _joinInjectionSections(memInjection.section, kbInjection.section),
          modelName: effective.name,
          modelId: effective.id,
          providerName: current.provider.name,
        ),
      ),
      messages: messages,
      maxTokens: ctx.maxTokens,
      temperature: params.temperature,
      topP: params.topP,
      topK: params.topK,
      frequencyPenalty: params.frequencyPenalty,
      presencePenalty: params.presencePenalty,
      seed: params.seed,
      stopSequences: params.stopSequences,
      responseFormat: params.responseFormat,
      parallelToolCalls: params.parallelToolCalls,
      logprobs: params.logprobs,
      user: params.user,
      reasoningEffort: params.reasoningEffort,
      thinkingBudget: params.thinkingBudget,
      includeThoughts: params.includeThoughts,
      cacheControl: params.cacheControl,
      structuredOutputMode: params.structuredOutputMode,
      webSearchEnabled: params.webSearchEnabled,
      codeExecutionEnabled: params.codeExecutionEnabled,
      useSearchGrounding: params.useSearchGrounding,
      safetyLevel: params.safetyLevel,
      stream: params.streamOutput,
      customParameters: params.customParameters,
      tools: mcp.useFunctionTools ? mcp.tools : null,
      useResponsesAPI: current.provider.useResponsesAPI ?? false,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
      provider: current.provider,
      turnTopicId: topicId,
      assistantMessageId: assistantMessageId,
      assistantBlockId: assistantBlockId,
      assistantTime: assistantTime,
      views: views,
      assistantView: assistantView,
      mcp: mcp,
      leadingBlocks: [
        ..._memoryInjectionBlocks(
          messageId: assistantMessageId,
          createdAt: assistantTime,
          injection: memInjection,
        ),
        ..._knowledgeReferenceBlocks(
          messageId: assistantMessageId,
          createdAt: assistantTime,
          injection: kbInjection,
        ),
      ],
    );
  }

  /// The leading [KnowledgeReferenceBlock]s for a turn (empty when no 挂载库
  /// hit), seeded ahead of the assistant content so the chat shows 本轮注入的
  /// 知识库引用块（功能缺口⑫）.
  @override
  List<MessageBlock> _knowledgeReferenceBlocks({
    required String messageId,
    required DateTime createdAt,
    required ChatKnowledgeInjection injection,
  }) {
    if (injection.isEmpty) return const <MessageBlock>[];
    return <MessageBlock>[
      for (final reference in injection.references)
        MessageBlock.knowledgeReference(
          id: generateId('block'),
          messageId: messageId,
          status: MessageBlockStatus.success,
          createdAt: createdAt,
          content: reference.content,
          knowledgeBaseId: reference.knowledgeBaseId ?? '',
          source: reference.knowledgeBaseName,
          similarity: reference.similarity,
        ),
    ];
  }

  /// Joins two optional prompt sections (记忆 + 知识库引用) with a blank line.
  @override
  String? _joinInjectionSections(String? a, String? b) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;
    return '$a\n\n$b';
  }

  /// The leading [MemoryInjectionBlock] for a turn (empty when nothing was
  /// injected), seeded into the assistant message ahead of its content so the
  /// chat shows the 对话内「本轮注入 N 条记忆」可展开块.
  @override
  List<MessageBlock> _memoryInjectionBlocks({
    required String messageId,
    required DateTime createdAt,
    required ChatMemoryInjection injection,
  }) {
    if (injection.isEmpty || injection.count == 0) {
      return const <MessageBlock>[];
    }
    return <MessageBlock>[
      MessageBlock.memoryInjection(
        id: generateId('block'),
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        count: injection.count,
        memories: injection.memories,
      ),
    ];
  }

  @override
  Future<void> regenerate(String messageId, {CurrentModel? withModel}) async {
    _truncatedMessageId = null;
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;

    final index = snapshot.messages.indexWhere((view) => view.id == messageId);
    if (index == -1) return;

    final target = await _repo.getMessage(messageId);
    if (target == null || target.role != MessageRole.assistant) return;

    // A multi-model 对比 sibling regenerates on its OWN model — that is what
    // makes 「重试失败」 re-run each sibling on the model it belongs to, instead
    // of turning every column into the current model. A plain (single-reply)
    // regenerate follows the app-level current model, so switching the model
    // then tapping 重新生成 re-runs on the newly selected one. [withModel]
    // (换模型重新生成) overrides both.
    final current =
        withModel ??
        (target.siblingsGroupId != 0
            ? (await _currentModelForOwnModel(target.model) ??
                  await ref.read(appCurrentModelProvider.future))
            : await ref.read(appCurrentModelProvider.future));
    if (current == null) return;

    final now = DateTime.now();
    final effective = effectiveModelFor(current);

    // Archive the currently displayed content as a version, then reset the
    // assistant message: drop its old blocks and attach a single fresh
    // streaming main_text block, re-pointed at the current model, with the
    // freshly streamed reply becoming the new latest (currentVersionId null).
    final prepared = await _versioning.prepareForRegenerate(target, now);
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
    // Carry the tree/group fields over so a multi-model sibling stays inside
    // its 对比 group (and keeps its selection) while it re-streams.
    final assistantView = ChatMessageView(
      id: messageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      createdAt: target.createdAt,
      modelName: effective.name,
      providerName: current.provider.name,
      modelId: effective.id,
      providerId: current.provider.id,
      askId: target.askId,
      siblingsGroupId: target.siblingsGroupId,
      multiModelMessageStyle: target.multiModelMessageStyle,
      foldSelected: target.foldSelected ?? false,
    );
    views[index] = assistantView;
    _emitTurn(target.topicId, views, streaming: true);

    final mcp = await _mcpSetup();
    final ctx = _contextSettings();
    final params = _parameterFields();
    final contextViews = _trimViews(
      _filterSiblingsForContext(
        views.sublist(0, index),
        excludeGroupId: target.siblingsGroupId != 0
            ? target.siblingsGroupId
            : null,
      ),
      ctx.contextCount,
    );
    final regexRules = await _sendingRegexRules();
    final messages = await _buildLlmMessages(
      contextViews,
      chatModel: effective,
      regexRules: regexRules,
      toolMode: mcp.mode,
    );
    final request = LlmChatRequest(
      model: effective,
      system: _systemFor(
        mcp,
        await _buildSystemPrompt(
          modelName: effective.name,
          modelId: effective.id,
          providerName: current.provider.name,
        ),
      ),
      messages: messages,
      maxTokens: ctx.maxTokens,
      temperature: params.temperature,
      topP: params.topP,
      topK: params.topK,
      frequencyPenalty: params.frequencyPenalty,
      presencePenalty: params.presencePenalty,
      seed: params.seed,
      stopSequences: params.stopSequences,
      responseFormat: params.responseFormat,
      parallelToolCalls: params.parallelToolCalls,
      logprobs: params.logprobs,
      user: params.user,
      reasoningEffort: params.reasoningEffort,
      thinkingBudget: params.thinkingBudget,
      includeThoughts: params.includeThoughts,
      cacheControl: params.cacheControl,
      structuredOutputMode: params.structuredOutputMode,
      webSearchEnabled: params.webSearchEnabled,
      codeExecutionEnabled: params.codeExecutionEnabled,
      useSearchGrounding: params.useSearchGrounding,
      safetyLevel: params.safetyLevel,
      stream: params.streamOutput,
      customParameters: params.customParameters,
      tools: mcp.useFunctionTools ? mcp.tools : null,
      useResponsesAPI: current.provider.useResponsesAPI ?? false,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
      provider: current.provider,
      turnTopicId: target.topicId,
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
    _emitTurn(userMessage.topicId, views, streaming: true);

    final mcp = await _mcpSetup();
    final ctx = _contextSettings();
    final params = _parameterFields();
    final contextViews = _trimViews(
      _filterSiblingsForContext(snapshot.messages),
      ctx.contextCount,
    );
    final regexRules = await _sendingRegexRules();
    final messages = await _buildLlmMessages(
      contextViews,
      chatModel: effective,
      regexRules: regexRules,
      toolMode: mcp.mode,
    );
    final request = LlmChatRequest(
      model: effective,
      system: _systemFor(
        mcp,
        await _buildSystemPrompt(
          modelName: effective.name,
          modelId: effective.id,
          providerName: current.provider.name,
        ),
      ),
      messages: messages,
      maxTokens: ctx.maxTokens,
      temperature: params.temperature,
      topP: params.topP,
      topK: params.topK,
      frequencyPenalty: params.frequencyPenalty,
      presencePenalty: params.presencePenalty,
      seed: params.seed,
      stopSequences: params.stopSequences,
      responseFormat: params.responseFormat,
      parallelToolCalls: params.parallelToolCalls,
      logprobs: params.logprobs,
      user: params.user,
      reasoningEffort: params.reasoningEffort,
      thinkingBudget: params.thinkingBudget,
      includeThoughts: params.includeThoughts,
      cacheControl: params.cacheControl,
      structuredOutputMode: params.structuredOutputMode,
      webSearchEnabled: params.webSearchEnabled,
      codeExecutionEnabled: params.codeExecutionEnabled,
      useSearchGrounding: params.useSearchGrounding,
      safetyLevel: params.safetyLevel,
      stream: params.streamOutput,
      customParameters: params.customParameters,
      tools: mcp.useFunctionTools ? mcp.tools : null,
      useResponsesAPI: current.provider.useResponsesAPI ?? false,
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    await _streamInto(
      request: request,
      effective: effective,
      provider: current.provider,
      turnTopicId: userMessage.topicId,
      assistantMessageId: assistantMessageId,
      assistantBlockId: assistantBlockId,
      assistantTime: now,
      views: views,
      assistantView: assistantView,
      mcp: mcp,
    );
  }

  /// The message id whose response was truncated, or `null`.
  String? get truncatedMessageId => _truncatedMessageId;

  /// Continues generating from a previously truncated assistant message.
  ///
  /// Loads the conversation up to [messageId], appends its partial content as
  /// an assistant message, and streams a new completion that picks up from
  /// where the model was cut off. The new content is appended to the existing
  /// blocks (not replacing them).
  Future<void> continueGenerating(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;

    _truncatedMessageId = null;

    // Load the existing assistant message.
    final message = await _repo.getMessage(messageId);
    if (message == null || message.role != MessageRole.assistant) return;

    // Continue on the model that produced the truncated reply — splicing a
    // different model's continuation into the same message would silently mix
    // outputs (and mismatch the stored `message.model`). Fall back to the
    // app-level current model only when the own model is gone.
    final current =
        await _currentModelForOwnModel(message.model) ??
        await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    final effective = effectiveModelFor(current);
    final now = DateTime.now();

    // Build conversation history through this message so persisted tool calls,
    // results, and any trailing partial text are all replayed to the model.
    final views = snapshot.messages;
    final msgIndex = views.indexWhere((v) => v.id == messageId);
    if (msgIndex < 0) return;

    final mcp = await _mcpSetup();
    final ctx = _contextSettings();
    final params = _parameterFields();
    final history = _trimViews(
      _filterSiblingsForContext(
        views.sublist(0, msgIndex),
        excludeGroupId: message.siblingsGroupId != 0
            ? message.siblingsGroupId
            : null,
      ),
      ctx.contextCount,
    );
    final regexRules = await _sendingRegexRules();
    final messages = await _buildLlmMessages(
      [...history, views[msgIndex]],
      chatModel: effective,
      regexRules: regexRules,
      dropEmptyAssistant: false,
      toolMode: mcp.mode,
    );

    // Create a new block id for the continuation segment.
    final continuationBlockId = generateId('block');

    // Update the message status to streaming.
    await _repo.saveMessage(
      message.copyWith(status: MessageStatus.streaming, updatedAt: now),
    );

    // Create the continuation view — reuse existing view data.
    final assistantView = views[msgIndex].copyWith(
      status: MessageStatus.streaming,
    );
    final updatedViews = [
      ...views.sublist(0, msgIndex),
      assistantView,
      ...views.sublist(msgIndex + 1),
    ];
    _emitTurn(message.topicId, updatedViews, streaming: true);

    await _streamInto(
      request: LlmChatRequest(
        model: effective,
        messages: messages,
        maxTokens: ctx.maxTokens,
        temperature: params.temperature,
        topP: params.topP,
        topK: params.topK,
        frequencyPenalty: params.frequencyPenalty,
        presencePenalty: params.presencePenalty,
        seed: params.seed,
        stopSequences: params.stopSequences,
        responseFormat: params.responseFormat,
        parallelToolCalls: params.parallelToolCalls,
        logprobs: params.logprobs,
        user: params.user,
        reasoningEffort: params.reasoningEffort,
        thinkingBudget: params.thinkingBudget,
        includeThoughts: params.includeThoughts,
        cacheControl: params.cacheControl,
        structuredOutputMode: params.structuredOutputMode,
        webSearchEnabled: params.webSearchEnabled,
        codeExecutionEnabled: params.codeExecutionEnabled,
        useSearchGrounding: params.useSearchGrounding,
        safetyLevel: params.safetyLevel,
        stream: params.streamOutput,
        customParameters: params.customParameters,
        tools: mcp.useFunctionTools ? mcp.tools : null,
        useResponsesAPI: current.provider.useResponsesAPI ?? false,
        extraHeaders: effective.providerExtraHeaders,
        extraBody: effective.providerExtraBody,
      ),
      effective: effective,
      provider: current.provider,
      turnTopicId: message.topicId,
      assistantMessageId: messageId,
      assistantBlockId: continuationBlockId,
      assistantTime: now,
      views: updatedViews,
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

  // ── Context-settings helpers ──────────────────────────────────────────────

  /// Reads the sidebar 上下文设置 and returns the `maxTokens` to set on the
  /// request (`null` when the user disabled the limit) and the `contextCount`
  /// (number of history messages to include).
  @override
  ({int contextCount, int? maxTokens}) _contextSettings() {
    final s = ref.read(sidebarSettingsControllerProvider);
    // Prefer ParameterSettings maxOutputTokens when enabled (unified parameter
    // system), falling back to the legacy SidebarSettings value.
    final ps = ref.read(parameterSettingsControllerProvider);
    int? maxTokens;
    if (ps.isParameterEnabled('maxOutputTokens')) {
      final v = ps.getParameterValue('maxOutputTokens');
      maxTokens = v is int ? v : (v is num ? v.toInt() : null);
    } else if (s.enableMaxOutputTokens) {
      maxTokens = s.maxOutputTokens;
    }
    return (contextCount: s.contextCount, maxTokens: maxTokens);
  }

  /// Reads the parameter settings and returns a record of fields suitable for
  /// spreading into an [LlmChatRequest] constructor. Only enabled parameters
  /// are returned; disabled ones stay `null`. Extracted to
  /// [readLlmParameterFields].
  @override
  LlmParameterFields _parameterFields() => readLlmParameterFields(ref);

  /// Extracted to [trimViewsForContext].
  static List<ChatMessageView> _trimViews(
    List<ChatMessageView> views,
    int count,
  ) => trimViewsForContext(views, count);

  /// Extracted to [filterSiblingsForContext].
  static List<ChatMessageView> _filterSiblingsForContext(
    List<ChatMessageView> views, {
    int? excludeGroupId,
  }) => filterSiblingsForContext(views, excludeGroupId: excludeGroupId);

  /// Replaces every block of [messageId] with [blocks] (in order) and stamps the
  /// message [status]. Deleting first keeps the streaming placeholder and any
  /// stale blocks from leaking into the rendered order ([_orderBlocks] appends
  /// unreferenced blocks), so the persisted set is exactly what was streamed.
  @override
  Future<void> _persistMessageBlocks({
    required String messageId,
    required MessageStatus status,
    required List<MessageBlock> blocks,
    Usage? usage,
    Metrics? metrics,
  }) => send_svc.persistMessageBlocks(
    _repo,
    messageId: messageId,
    status: status,
    blocks: blocks,
    usage: usage,
    metrics: metrics,
  );

  /// 崩溃恢复：把 [topicId] 里上次运行遗留在 streaming 状态的消息落定（对齐
  /// Cherry Studio 启动时的 `reconcileStalePendingMessages`）。检查点持久化让
  /// 闪退前的正文/思考/工具块都已在库里：有内容就按 success 保留（对话不丢），
  /// 一点内容都没有才标记 error；块级的 streaming/processing 状态一并落定，
  /// 其中未完成的工具块标记为 error（结果已随进程一起丢失），避免重启后出现
  /// 永远转圈的气泡。仅在该话题没有活跃流时调用。
  Future<void> _settleInterruptedMessages(String topicId) =>
      send_svc.settleInterruptedMessages(_repo, topicId);

  /// Deletes [messageId] together with its blocks and drops it from the view.
  ///
  /// Port of the toolbar 删除 action (`MessageActions.handleToolbarDeleteClick`
  /// → `onDelete`). The two-click confirmation lives in the UI; this performs
  /// the actual removal once confirmed. A no-op while a reply is streaming or
  /// when the conversation has not loaded.
  @override
  Future<void> deleteMessage(String messageId, {bool cascade = false}) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    // Tree-aware: by default the node's children are reparented onto its parent
    // (conversation stays connected); cascade removes the whole subtree. The
    // structure can change beyond just this row, so reload from the tree.
    await _repo.deleteMessage(messageId, cascade: cascade);
    await _refreshTopicPreview();
    ref.read(chatRefreshProvider.notifier).bump();
  }

  /// Switches the displayed branch to the one whose leaf is [nodeId] (moves the
  /// topic's active leaf), then reloads. The next reply will continue from the
  /// newly-active branch. A no-op while a reply is streaming or with no topic.
  ///
  /// When [nodeId] is a multi-model sibling, this also makes it the group's
  /// `foldSelected` one, so picking a reply in the 分支管理 canvas keeps the 对比
  /// group's 折叠 selection in sync (otherwise 折叠 would still show the old model
  /// while the conversation continues from the tapped one).
  Future<void> switchToBranch(String nodeId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final topicId = _topicId;
    if (topicId == null) return;
    await _syncFoldSelectedForGroup(topicId, nodeId);
    await _repo.setActiveNode(topicId, nodeId);
    ref.read(chatRefreshProvider.notifier).bump();
  }

  /// Switches the active branch to the one headed by [headId] (a branch sibling
  /// from the `◀ k/n ▶` switcher), descending to that branch's deepest leaf so
  /// the whole alternate path shows — not just the fork point. Follows the
  /// `foldSelected` child at each step (multi-model selected reply), else the
  /// last child chronologically. No-op while streaming.
  Future<void> switchActiveBranch(String headId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final topicId = _topicId;
    if (topicId == null) return;
    final all = await _repo.getMessagesByTopicId(topicId);
    final childrenByParent = <String, List<Message>>{};
    for (final m in all) {
      (childrenByParent[m.parentId ?? ''] ??= <Message>[]).add(m);
    }
    var leaf = headId;
    final guard = <String>{};
    while (guard.add(leaf)) {
      final children = childrenByParent[leaf];
      if (children == null || children.isEmpty) break;
      children.sort(compareMessagesChronologically);
      leaf = children
          .firstWhere(
            (c) => c.foldSelected == true,
            orElse: () => children.last,
          )
          .id;
    }
    await _repo.setActiveNode(topicId, leaf);
    ref.read(chatRefreshProvider.notifier).bump();
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
    unawaited(_refreshTopicPreview());
  }

  // --- Version history ------------------------------------------------------

  /// Manually saves the message's current content as a version (the 保存当前
  /// button). A no-op while a reply is streaming or when the content is empty.
  Future<void> createManualVersion(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    if (!await _versioning.createManualVersion(message)) return;
    await _reloadIntoState(messageId);
  }

  /// Switches the displayed content of [messageId] to version [versionId].
  /// A no-op while a reply is streaming.
  Future<void> switchToVersion(String messageId, String versionId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    if (!await _versioning.switchToVersion(message, versionId)) return;
    await _reloadIntoState(messageId);
  }

  /// Switches [messageId] back to the latest (live) content, restoring the
  /// blocks stashed when history was first opened. A no-op while streaming or
  /// when already showing the latest content.
  Future<void> switchToLatest(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _repo.getMessage(messageId);
    if (message == null) return;
    if (!await _versioning.switchToLatest(message)) return;
    await _reloadIntoState(messageId);
  }

  /// Deletes version [versionId] from [messageId] (the trash action): if the
  /// version is currently displayed the message first switches back to the
  /// latest content. A no-op while a reply is streaming.
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

    if (!await _versioning.deleteVersion(message, versionId)) return;
    await _reloadIntoState(messageId);
  }

  /// Builds the message block for a pending composer [attachment], carrying its
  /// payload inline (no disk file is written): an image becomes an `IMAGE`
  /// block (raw base64 for inline rendering), a text/file attachment a `FILE`
  /// block (a base64 data URI; text attachments stay `text/plain` so
  /// `decodeFileText` feeds them to the model).
  @override
  MessageBlock _attachmentBlock({
    required String messageId,
    required DateTime createdAt,
    required ComposerAttachment attachment,
  }) {
    if (attachment.kind == ComposerAttachmentKind.image) {
      final raw = attachment.base64Data ?? '';
      return MessageBlock.image(
        id: generateId('block'),
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        url: '',
        mimeType: attachment.mimeType,
        base64Data: raw,
        size: attachment.size,
        file: MessageFileReference(
          id: attachment.id,
          name: attachment.name,
          originName: attachment.name,
          size: attachment.size,
          mimeType: attachment.mimeType,
          base64Data: 'data:${attachment.mimeType};base64,$raw',
        ),
      );
    }
    final isText = attachment.kind == ComposerAttachmentKind.text;
    final encoded = isText
        ? base64Encode(utf8.encode(attachment.text ?? ''))
        : (attachment.base64Data ?? '');
    final mimeType = isText ? 'text/plain' : attachment.mimeType;
    return MessageBlock.file(
      id: generateId('block'),
      messageId: messageId,
      status: MessageBlockStatus.success,
      createdAt: createdAt,
      name: attachment.name,
      url: '',
      mimeType: mimeType,
      size: attachment.size,
      file: MessageFileReference(
        id: attachment.id,
        name: attachment.name,
        originName: attachment.name,
        size: attachment.size,
        mimeType: mimeType,
        base64Data: 'data:$mimeType;base64,$encoded',
      ),
    );
  }

  /// Builds the [LlmMessage] list for [views], applying the OCR fallback when
  /// [chatModel] cannot see images: for each image-bearing turn the images are
  /// recognized by the configured OCR (vision) model and the resulting text is
  /// prepended to the turn's content (and the images dropped), so a non-vision
  /// chat model still receives the image content as text. When no OCR fallback
  /// applies the messages are built exactly as before (images sent inline).
  ///
  /// [dropEmptyAssistant] mirrors the existing
  /// `role != assistant || text.isNotEmpty` filter; pass `false` for paths that
  /// build raw history (e.g. continue-generating) and append their own turns.
  @override
  Future<List<LlmMessage>> _buildLlmMessages(
    Iterable<ChatMessageView> views, {
    required Model chatModel,
    List<AssistantRegex>? regexRules,
    bool dropEmptyAssistant = true,
    required McpMode toolMode,
  }) => _historyBuilder.buildLlmMessages(
    views,
    chatModel: chatModel,
    regexRules: regexRules,
    dropEmptyAssistant: dropEmptyAssistant,
    toolMode: toolMode,
  );

  /// The request content for [view] (main text + decoded FILE blocks, 发送期
  /// 正则 applied); extracted to [LlmHistoryBuilder.requestContent].
  @override
  String _requestContent(
    ChatMessageView view, {
    List<AssistantRegex>? regexRules,
  }) => _historyBuilder.requestContent(view, regexRules: regexRules);

  /// The current assistant's 正则规则, used to process outgoing message content.
  @override
  Future<List<AssistantRegex>?> _sendingRegexRules() async =>
      (await _repo.getAssistant(_assistantId))?.regexRules;

  /// Reloads [messageId]'s persisted view into the conversation state without a
  /// full topic reload, after a version mutation.
  @override
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
  @override
  Future<ChatMessageView> _reloadView(
    String messageId,
    ChatMessageView fallback,
  ) async {
    final message = await _repo.getMessage(messageId);
    if (message == null) return fallback;
    return _viewOf(message);
  }

  /// Assembles the system prompt for a conversation turn; extracted to
  /// [SystemPromptBuilder.buildSystemPrompt].
  @override
  Future<String?> _buildSystemPrompt({
    required String modelName,
    required String modelId,
    required String providerName,
  }) => _systemPromptBuilder.buildSystemPrompt(
    modelName: modelName,
    modelId: modelId,
    providerName: providerName,
  );

  /// Like [_buildSystemPrompt] but reuses a pre-resolved memory section;
  /// extracted to [SystemPromptBuilder.buildSystemPromptWith].
  @override
  Future<String?> _buildSystemPromptWith(
    String? memorySection, {
    required String modelName,
    required String modelId,
    required String providerName,
  }) => _systemPromptBuilder.buildSystemPromptWith(
    memorySection,
    modelName: modelName,
    modelId: modelId,
    providerName: providerName,
  );

  /// Assembles the [McpSetup] for the current turn (see [buildMcpSetup]);
  /// the bound-skills lookup stays here because it needs the repository and
  /// the controller's active assistant.
  @override
  Future<McpSetup> _mcpSetup() => buildMcpSetup(
    ref,
    loadBoundSkills: () async {
      final assistant = await _repo.getAssistant(_assistantId);
      return _systemPromptBuilder.enabledSkillsFor(assistant?.skillIds);
    },
  );

  /// The system prompt for a turn (tool catalogue injection + capability
  /// hints); extracted to [SystemPromptBuilder.systemFor].
  @override
  String? _systemFor(McpSetup mcp, String? base) =>
      _systemPromptBuilder.systemFor(mcp, base);

  @override
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

  /// Projects a persisted [Message] into its rendered view; extracted to
  /// [MessageViewProjector.viewOf].
  Future<ChatMessageView> _viewOf(Message message) =>
      _viewProjector.viewOf(message);

  /// Returns [blocks] sorted by the `message.blocks` id order (the canonical
  /// render order); any block not referenced there is appended at the end.
  @override
  List<MessageBlock> _orderBlocks(
    List<String> order,
    List<MessageBlock> blocks,
  ) => orderMessageBlocks(order, blocks);

  @override
  void _emit(List<ChatMessageView> views, {required bool isStreaming}) {
    state = AsyncData(
      ChatState(
        messages: List<ChatMessageView>.of(views),
        isStreaming: isStreaming,
      ),
    );
    // The background keep-alive service is driven per-topic by the
    // StreamingRegistry (begin on the first streaming topic, end on the last),
    // not here, so a finished current topic doesn't stop a background one.
  }

  @override
  void _replace(List<ChatMessageView> views, ChatMessageView view) {
    final index = views.indexWhere((v) => v.id == view.id);
    if (index != -1) views[index] = view;
  }

  @override
  String _errorMessage(Object error) {
    if (error is Failure) return error.message;
    return error.toString();
  }
}

/// Raised when a provider has a multi-key pool but every key is disabled,
/// errored or still cooling down and there is no single-key fallback — surfaced
/// as the assistant message's error so the user knows to re-enable / add a key.
class _NoUsableApiKeyException implements Exception {
  const _NoUsableApiKeyException();

  @override
  String toString() => '没有可用的 API Key：所有 Key 已禁用、失败或处于冷却中。';
}

/// Single-message lookup over the chat controller's async state.
///
/// Lets a bubble subscribe to *its own* [ChatMessageView] with
/// `chatControllerProvider.select((a) => a.messageById(id))`. Because
/// [ChatMessageView] is a freezed value type, Riverpod's `select` dedup
/// short-circuits when an unrelated message changes, so an in-place content
/// update (streaming) rebuilds only the affected bubble — not the whole list.
extension ChatMessageLookup on AsyncValue<ChatState> {
  ChatMessageView? messageById(String id) {
    final messages = value?.messages;
    if (messages == null) return null;
    final index = _messageIndexCache[messages] ??= <String, ChatMessageView>{
      for (final message in messages) message.id: message,
    };
    return index[id];
  }
}

/// Per-list id→view index, keyed weakly on the (immutable once emitted)
/// messages list itself, so every visible bubble's `messageById` lookup is
/// O(1) instead of a linear scan on each emit.
final Expando<Map<String, ChatMessageView>> _messageIndexCache =
    Expando<Map<String, ChatMessageView>>();
