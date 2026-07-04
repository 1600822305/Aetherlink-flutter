import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/skills_access.dart';
import 'package:aetherlink_flutter/app/di/system_prompt_variables_access.dart';
import 'package:aetherlink_flutter/features/chat/application/combo_executor.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_providers.dart';
import 'package:aetherlink_flutter/shared/domain/model_combo.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/parameter_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_send_hooks.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_versioning.dart';
import 'package:aetherlink_flutter/features/chat/application/mounted_knowledge_bases_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/multi_model_mentions_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/ocr_service.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/streaming_registry.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_confirmation.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_executor.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_setup.dart';
import 'package:aetherlink_flutter/features/chat/application/suggestion_service.dart';
import 'package:aetherlink_flutter/features/chat/application/translate_controller.dart';
import 'package:aetherlink_flutter/features/chat/data/datasources/remote/llm/api_key_manager.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_ordering.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_file_reference.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_version.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/metrics.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/usage.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_extraction.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_content_image.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/config/skill_prompt_builder.dart';
import 'package:aetherlink_flutter/shared/domain/api_key_config.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_prompt.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/running_commands_service.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/tool_confirmation_service.dart';
import 'package:aetherlink_flutter/shared/utils/regex_replacement.dart';
import 'package:aetherlink_flutter/shared/utils/system_prompt_variables.dart';

part 'chat_controller.g.dart';

/// One assistant sibling of a multi-model turn: the chosen model and the
/// streaming message/block/view created for it. Used by [sendMultiModel] to
/// stream all siblings in parallel.
typedef _MultiModelSibling = ({
  CurrentModel current,
  Model effective,
  String assistantMessageId,
  String assistantBlockId,
  DateTime assistantTime,
  ChatMessageView assistantView,
});

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

  /// The id of the last assistant message that was truncated due to
  /// `finishReason == 'length'` after exhausting auto-continues. Cleared on
  /// the next send / regenerate. The UI reads this to show a "继续生成" button.
  String? _truncatedMessageId;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  /// Message version history operations (manual save / switch / delete /
  /// regenerate-time archival), extracted to [MessageVersioning].
  MessageVersioning get _versioning => MessageVersioning(_repo);

  /// Runs each tool call along its [ToolRoute] (in-process built-in / remote
  /// MCP / bridge / web search / memory search).
  late final ChatToolExecutor _toolExecutor = ChatToolExecutor(
    ref,
    assistantId: () => _assistantId,
  );

  StreamingRegistry get _registry =>
      ref.read(streamingRegistryProvider.notifier);

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
    final contextViews = _trimViews(views, ctx.contextCount);
    final regexRules = await _sendingRegexRules();
    final messages = await _buildLlmMessages(
      contextViews,
      chatModel: effective,
      regexRules: regexRules,
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
  String? _joinInjectionSections(String? a, String? b) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;
    return '$a\n\n$b';
  }

  /// The leading [MemoryInjectionBlock] for a turn (empty when nothing was
  /// injected), seeded into the assistant message ahead of its content so the
  /// chat shows the 对话内「本轮注入 N 条记忆」可展开块.
  List<MessageBlock> _memoryInjectionBlocks({
    required String messageId,
    required DateTime createdAt,
    required ChatMemoryInjection injection,
  }) {
    if (injection.isEmpty || injection.count == 0) return const <MessageBlock>[];
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

  /// Sends [text] to several models at once (port of the web `useMultiModelSend`
  /// + Cherry's multi-model turn): one user message, then one streaming
  /// assistant **sibling per model** — all sharing the user message's `askId`
  /// and one `siblingsGroupId (>0)` — streamed in parallel. `saveMessage`
  /// attaches the first sibling to the active path; the display projection
  /// (`orderBranchMessages`) inlines the whole group so the 对比 group widget can
  /// lay them out. A blank message, no models, or an in-flight stream are no-ops.
  Future<void> sendMultiModel(
    String text,
    List<CurrentModel> models, {
    List<ComposerAttachment> attachments = const <ComposerAttachment>[],
  }) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachments.isEmpty) || models.isEmpty) return;
    final snapshot = state.value ?? ChatState.initial();
    if (snapshot.isStreaming) return;

    _truncatedMessageId = null;
    final topicId = await _ensureTopic();
    final now = DateTime.now();

    // 1. User message (records the chosen models in `mentions`), persisted and
    //    attached to the tree by saveMessage.
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
      mentions: <Model>[for (final m in models) m.model],
      blocks: <String>[for (final block in userBlocks) block.id],
    );
    await _repo.saveMessage(userMessage);
    for (final block in userBlocks) {
      await _repo.saveMessageBlock(block);
    }

    // 2. One sibling-group id for this turn — unique within the topic so the
    //    projection groups exactly these replies.
    final siblingsGroupId = await _nextSiblingsGroupId(topicId);

    final userView = ChatMessageView(
      id: userMessageId,
      role: MessageRole.user,
      status: MessageStatus.success,
      text: trimmed,
      blocks: userBlocks,
      createdAt: now,
    );

    // 3. One streaming assistant sibling per model. The first sibling becomes the
    //    active leaf (saveMessage advances activeNodeId to it because its parent
    //    == the active leaf); the rest share its parent + group id, so they sit
    //    off the active path but are inlined for display. The default layout is
    //    horizontal when there are 2+ models, fold for one.
    final defaultStyle = models.length > 1
        ? MultiModelMessageStyle.horizontal
        : MultiModelMessageStyle.fold;
    final siblings = <_MultiModelSibling>[];
    final assistantViews = <ChatMessageView>[];
    for (var i = 0; i < models.length; i++) {
      final current = models[i];
      final effective = effectiveModelFor(current);
      // Staggered by index so the display order (chronological within the group)
      // is deterministic and matches the selection order.
      final assistantTime = now.add(Duration(microseconds: 1 + i));
      final assistantMessageId = generateId('msg');
      final assistantBlockId = generateId('block');
      final assistantMessage = Message(
        id: assistantMessageId,
        role: MessageRole.assistant,
        assistantId: _assistantId,
        topicId: topicId,
        createdAt: assistantTime,
        status: MessageStatus.streaming,
        model: effective,
        askId: userMessageId,
        siblingsGroupId: siblingsGroupId,
        multiModelMessageStyle: defaultStyle,
        foldSelected: i == 0,
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
      final assistantView = ChatMessageView(
        id: assistantMessageId,
        role: MessageRole.assistant,
        status: MessageStatus.streaming,
        createdAt: assistantTime,
        modelName: effective.name,
        providerName: current.provider.name,
        modelId: effective.id,
        providerId: current.provider.id,
        askId: userMessageId,
        siblingsGroupId: siblingsGroupId,
        multiModelMessageStyle: defaultStyle,
        foldSelected: i == 0,
      );
      assistantViews.add(assistantView);
      siblings.add((
        current: current,
        effective: effective,
        assistantMessageId: assistantMessageId,
        assistantBlockId: assistantBlockId,
        assistantTime: assistantTime,
        assistantView: assistantView,
      ));
    }

    final views = <ChatMessageView>[
      ...snapshot.messages,
      userView,
      ...assistantViews,
    ];
    _emitTurn(topicId, views, streaming: true);

    // 4. Shared request context: the history up to and including the user turn.
    //    The sibling placeholders are excluded so every model answers the same
    //    conversation independently.
    final mcp = await _mcpSetup();
    final ctx = _contextSettings();
    final params = _parameterFields();
    final regexRules = await _sendingRegexRules();
    final baseViews = <ChatMessageView>[...snapshot.messages, userView];
    final contextViews = _trimViews(baseViews, ctx.contextCount);
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

    // 5. Stream every sibling in parallel; each keeps the turn alive
    //    (finalizeTurn: false) so the others stay visible until all settle.
    await Future.wait(<Future<void>>[
      for (final sibling in siblings)
        () async {
          final effective = sibling.effective;
          final provider = sibling.current.provider;
          final messages = await _buildLlmMessages(
            contextViews,
            chatModel: effective,
            regexRules: regexRules,
          );
          final request = LlmChatRequest(
            model: effective,
            system: _systemFor(
              mcp,
              await _buildSystemPromptWith(
                _joinInjectionSections(
                  memInjection.section,
                  kbInjection.section,
                ),
                modelName: effective.name,
                modelId: effective.id,
                providerName: provider.name,
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
            useResponsesAPI: provider.useResponsesAPI ?? false,
            extraHeaders: effective.providerExtraHeaders,
            extraBody: effective.providerExtraBody,
          );
          await _streamInto(
            request: request,
            effective: effective,
            provider: provider,
            turnTopicId: topicId,
            assistantMessageId: sibling.assistantMessageId,
            assistantBlockId: sibling.assistantBlockId,
            assistantTime: sibling.assistantTime,
            views: views,
            assistantView: sibling.assistantView,
            mcp: mcp,
            leadingBlocks: [
              ..._memoryInjectionBlocks(
                messageId: sibling.assistantMessageId,
                createdAt: sibling.assistantTime,
                injection: memInjection,
              ),
              ..._knowledgeReferenceBlocks(
                messageId: sibling.assistantMessageId,
                createdAt: sibling.assistantTime,
                injection: kbInjection,
              ),
            ],
            finalizeTurn: false,
          );
        }(),
    ]);

    // 6. Whole turn done: end streaming and run the once-per-turn side effects.
    _emitTurn(topicId, views, streaming: false);
    unawaited(_refreshTopicPreview(topicId));
    unawaited(_generateTitle(topicId));
    unawaited(_maybeGenerateSuggestions(topicId, List.of(views)));
    unawaited(_maybeExtractMemory(topicId));
  }

  /// AI 辩论的一次角色发言：以 [current] 指定的模型发起一条**不携带话题历史**
  /// 的助手流式消息（辩论上下文由引擎在 [prompt] 里自建）。[header] 作为消息
  /// 顶部的成功块渲染（角色/轮次徽章），[metadata] 原样存进消息（`debate` 标记）。
  /// [toolsEnabled] 为 true 时按当前 MCP/搜索开关注入工具（事实核查角色）。
  /// 返回消息 id 与流式完成后的正文（不含 header）；话题已有流式请求时返回 null。
  Future<({String messageId, String text})?> sendDebateTurn({
    required CurrentModel current,
    required String system,
    required String prompt,
    String header = '',
    Map<String, dynamic>? metadata,
    bool toolsEnabled = false,
  }) async {
    final snapshot = state.value ?? ChatState.initial();
    if (snapshot.isStreaming) return null;

    _truncatedMessageId = null;
    final topicId = await _ensureTopic();
    final now = DateTime.now();
    final effective = effectiveModelFor(current);

    final assistantMessageId = generateId('msg');
    final assistantBlockId = generateId('block');
    final headerBlock = header.isEmpty
        ? null
        : MessageBlock.mainText(
            id: generateId('block'),
            messageId: assistantMessageId,
            status: MessageBlockStatus.success,
            createdAt: now,
            content: header,
          );
    final assistantMessage = Message(
      id: assistantMessageId,
      role: MessageRole.assistant,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.streaming,
      model: effective,
      metadata: metadata,
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
      modelId: effective.id,
      providerId: current.provider.id,
      debatePhase: _debatePhaseOf(metadata),
    );
    final views = <ChatMessageView>[...snapshot.messages, assistantView];
    _emitTurn(topicId, views, streaming: true);

    final mcp = toolsEnabled ? await _mcpSetup() : const McpSetup.disabled();
    final ctx = _contextSettings();
    final request = LlmChatRequest(
      model: effective,
      system: system,
      messages: <LlmMessage>[
        LlmMessage(role: MessageRole.user, content: prompt),
      ],
      maxTokens: ctx.maxTokens,
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
      assistantTime: now,
      views: views,
      assistantView: assistantView,
      mcp: mcp,
      leadingBlocks: [if (headerBlock != null) headerBlock],
    );

    final blocks = await _repo.getMessageBlocksByMessageId(assistantMessageId);
    final text = <String>[
      for (final b in blocks)
        if (b is MainTextBlock &&
            b.id != headerBlock?.id &&
            b.content.trim().isNotEmpty)
          b.content,
    ].join('\n\n');
    return (messageId: assistantMessageId, text: text);
  }

  /// 从消息 metadata 里取辩论阶段标记（`metadata['debate']['phase']`）。
  static String? _debatePhaseOf(Map<String, dynamic>? metadata) {
    final debate = metadata?['debate'];
    if (debate is! Map) return null;
    return debate['phase']?.toString();
  }

  /// AI 辩论的系统通告（开场/结束/错误提示）：直接落一条无模型的成功
  /// 助手消息并刷新会话视图。
  Future<void> sendDebateNotice(
    String content, {
    Map<String, dynamic>? metadata,
  }) async {
    final topicId = await _ensureTopic();
    final now = DateTime.now();
    final messageId = generateId('msg');
    final blockId = generateId('block');
    await _repo.saveMessage(
      Message(
        id: messageId,
        role: MessageRole.assistant,
        assistantId: _assistantId,
        topicId: topicId,
        createdAt: now,
        status: MessageStatus.success,
        metadata: metadata,
        blocks: <String>[blockId],
      ),
    );
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: blockId,
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: now,
        content: content,
      ),
    );
    ref.read(chatRefreshProvider.notifier).bump();
    unawaited(_refreshTopicPreview(topicId));
  }

  /// AI 辩论的用户插话：只落一条普通用户消息（带 debate 标记），
  /// 不触发任何模型回复——发言内容由辩论引擎注入后续上下文。
  Future<void> sendDebateInterjection(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final topicId = await _ensureTopic();
    final now = DateTime.now();
    final messageId = generateId('msg');
    final blockId = generateId('block');
    await _repo.saveMessage(
      Message(
        id: messageId,
        role: MessageRole.user,
        assistantId: _assistantId,
        topicId: topicId,
        createdAt: now,
        status: MessageStatus.success,
        metadata: const {
          'debate': {'phase': 'interjection'},
        },
        blocks: <String>[blockId],
      ),
    );
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: blockId,
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: now,
        content: trimmed,
      ),
    );
    ref.read(chatRefreshProvider.notifier).bump();
    unawaited(_refreshTopicPreview(topicId));
  }

  /// AI 辩论的静默一次性生成（不落聊天消息），用于裁决 JSON 等
  /// 结构化产出；失败时返回 null。
  Future<String?> generateDebateText({
    required CurrentModel current,
    required String system,
    required String prompt,
  }) async {
    try {
      final effective = effectiveModelFor(current);
      final request = LlmChatRequest(
        model: effective,
        system: system,
        messages: <LlmMessage>[
          LlmMessage(role: MessageRole.user, content: prompt),
        ],
        useResponsesAPI: current.provider.useResponsesAPI ?? false,
        extraHeaders: effective.providerExtraHeaders,
        extraBody: effective.providerExtraBody,
      );
      final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
      final buffer = StringBuffer();
      await for (final chunk in gateway.streamChat(request)) {
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
          case LlmReasoningDelta():
          case LlmToolCallChunk():
          case LlmDone():
            break;
        }
      }
      final text = buffer.toString().trim();
      return text.isEmpty ? null : text;
    } on Exception {
      return null;
    }
  }

  /// The next free sibling-group id for [topicId]: one past the largest existing
  /// `siblingsGroupId`, so a fresh multi-model group never collides with prior
  /// groups in the same topic.
  Future<int> _nextSiblingsGroupId(String topicId) async {
    final messages = await _repo.getMessagesByTopicId(topicId);
    var max = 0;
    for (final m in messages) {
      if (m.siblingsGroupId > max) max = m.siblingsGroupId;
    }
    return max + 1;
  }

  /// Selects sibling [messageId] as the one the conversation continues from:
  /// moves the topic's active leaf onto it and marks it `foldSelected` (clearing
  /// the flag on its group peers). The next user message will hang off it. A
  /// no-op while streaming or when the message isn't a grouped sibling.
  Future<void> selectSibling(String messageId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    final topicId = _topicId;
    if (topicId == null) return;
    final message = await _repo.getMessage(messageId);
    if (message == null || message.siblingsGroupId <= 0) return;
    if (message.foldSelected == true) return;

    await _syncFoldSelectedForGroup(topicId, messageId);
    await _repo.setActiveNode(topicId, messageId);
    ref.read(chatRefreshProvider.notifier).bump();
  }

  /// Makes [nodeId] the `foldSelected` member of its multi-model group (clearing
  /// the flag on its peers), so the 对比 group's 折叠 selection stays in sync with
  /// whatever made [nodeId] the active branch — whether that was the in-group
  /// model chip ([selectSibling]) or the 分支管理 canvas ([switchToBranch]). A
  /// no-op when [nodeId] isn't a grouped sibling or is already selected.
  Future<void> _syncFoldSelectedForGroup(String topicId, String nodeId) async {
    final message = await _repo.getMessage(nodeId);
    if (message == null || message.siblingsGroupId <= 0) return;
    if (message.foldSelected == true) return;
    final all = await _repo.getMessagesByTopicId(topicId);
    for (final m in all) {
      if (m.parentId == message.parentId &&
          m.siblingsGroupId == message.siblingsGroupId) {
        final selected = m.id == nodeId;
        if ((m.foldSelected ?? false) != selected) {
          await _repo.saveMessage(m.copyWith(foldSelected: selected));
        }
      }
    }
  }

  /// Persists the multi-model 对比 layout [style] onto every member of a group
  /// (port of the web `handleStyleChange`, which writes `multiModelMessageStyle`
  /// to all grouped assistant messages). The 对比 group widget keeps its own
  /// immediate UI state, so this only persists the choice for the next load — no
  /// list refresh is bumped, avoiding a rebuild flicker mid-toggle.
  Future<void> setMultiModelStyle(
    List<String> memberIds,
    MultiModelMessageStyle style,
  ) async {
    for (final id in memberIds) {
      final message = await _repo.getMessage(id);
      if (message == null || message.multiModelMessageStyle == style) continue;
      await _repo.saveMessage(message.copyWith(multiModelMessageStyle: style));
    }
  }

  /// Re-runs every errored sibling of a multi-model group (port of the web
  /// `handleRetryFailed`, which calls `onRegenerate` for each failed message).
  /// No-op while streaming.
  Future<void> retryFailedSiblings(List<String> memberIds) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    for (final id in memberIds) {
      final failed = snapshot.messages.any(
        (v) => v.id == id && v.status == MessageStatus.error,
      );
      if (failed) await regenerate(id);
    }
  }

  /// Deletes a whole multi-model 对比 group — the asked user message and all its
  /// sibling replies — by cascade-removing the subtree rooted at [askId] (port
  /// of the web `handleDeleteGroup`). No-op while streaming.
  Future<void> deleteMultiModelGroup(String askId) async {
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;
    await deleteMessage(askId, cascade: true);
  }

  /// Sends a user message and streams the combo (sequential) response.
  /// Phase 1: streams the thinking model's reasoning into a thinking block.
  /// Phase 2: streams the generating model's answer into the main text block.
  Future<void> _sendCombo(
    String text,
    ComboResolution resolution, {
    List<ComposerAttachment> attachments = const <ComposerAttachment>[],
  }) async {
    final snapshot = state.value ?? ChatState.initial();
    final topicId = await _ensureTopic();
    final now = DateTime.now();
    final thinking = resolution.thinkingModel;
    final generating = resolution.generatingModel;
    if (thinking == null || generating == null) return;

    // 1. Persist user message.
    final userMessageId = generateId('msg');
    final hasText = text.isNotEmpty;
    final userBlocks = <MessageBlock>[
      if (hasText)
        MessageBlock.mainText(
          id: generateId('block'),
          messageId: userMessageId,
          status: MessageBlockStatus.success,
          createdAt: now,
          content: text,
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

    // 2. Assistant message with a thinking block + main text block.
    final assistantTime = now.add(const Duration(microseconds: 1));
    final assistantMessageId = generateId('msg');
    final thinkingBlockId = generateId('block');
    final mainBlockId = generateId('block');

    // Synthetic model carrying the combo display label so _viewOf reads the
    // correct name when reconstructing from DB.
    final comboLabel = '${thinking.model.name} → ${generating.model.name}';
    final comboModel = Model(
      id: resolution.combo.id,
      name: comboLabel,
      provider: kModelComboProviderId,
    );

    final assistantMessage = Message(
      id: assistantMessageId,
      role: MessageRole.assistant,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: assistantTime,
      status: MessageStatus.streaming,
      model: comboModel,
      askId: userMessageId,
      blocks: <String>[thinkingBlockId, mainBlockId],
    );
    await _repo.saveMessage(assistantMessage);
    await _repo.saveMessageBlock(
      MessageBlock.thinking(
        id: thinkingBlockId,
        messageId: assistantMessageId,
        status: MessageBlockStatus.streaming,
        createdAt: assistantTime,
        content: '',
      ),
    );
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: mainBlockId,
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
      text: text,
      blocks: userBlocks,
      createdAt: now,
    );
    var assistantView = ChatMessageView(
      id: assistantMessageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      createdAt: assistantTime,
      modelName: comboLabel,
      providerName: '模型组合',
    );
    var views = [...snapshot.messages, userView, assistantView];
    _emitTurn(topicId, views, streaming: true);

    // 3. Build messages for the thinking model request.
    final ctx = _contextSettings();
    final contextViews = _trimViews(views, ctx.contextCount);
    final regexRules = await _sendingRegexRules();
    final llmMessages = [
      for (final view in contextViews)
        if (view.role != MessageRole.assistant || view.text.isNotEmpty)
          LlmMessage(
            role: view.role,
            content: _requestContent(view, regexRules: regexRules),
          ),
    ];

    final gatewayFactory = ref.read(llmGatewayFactoryProvider);
    final thinkingGateway = gatewayFactory.forModel(thinking.model);
    final generatingGateway = gatewayFactory.forModel(generating.model);

    final system = _systemFor(
      await _mcpSetup(),
      await _buildSystemPrompt(
        modelName: comboLabel,
        modelId: comboModel.id,
        providerName: '模型组合',
      ),
    );

    try {
      final reasoningBuf = StringBuffer();
      final mainBuf = StringBuffer();

      final comboStream = executeSequentialCombo(
        resolution: resolution,
        thinkingGateway: thinkingGateway,
        generatingGateway: generatingGateway,
        messages: llmMessages,
        system: system,
        maxTokens: ctx.maxTokens,
      );

      // Helper to rebuild live blocks for the view so the bubble renderer
      // always has non-empty blocks (empty blocks + non-streaming = invisible).
      List<MessageBlock> liveBlocks() => [
        MessageBlock.thinking(
          id: thinkingBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.streaming,
          createdAt: assistantTime,
          content: reasoningBuf.toString(),
        ),
        MessageBlock.mainText(
          id: mainBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.streaming,
          createdAt: assistantTime,
          content: mainBuf.toString(),
        ),
      ];

      await for (final event in comboStream) {
        switch (event) {
          case ComboReasoningDelta(:final text):
            reasoningBuf.write(text);
            assistantView = assistantView.copyWith(
              thinking: reasoningBuf.toString(),
              blocks: liveBlocks(),
            );
            views = [...views.take(views.length - 1), assistantView];
            _emitTurn(topicId, views, streaming: true);
          case ComboTextDelta(:final text):
            mainBuf.write(text);
            assistantView = assistantView.copyWith(
              text: mainBuf.toString(),
              blocks: liveBlocks(),
            );
            views = [...views.take(views.length - 1), assistantView];
            _emitTurn(topicId, views, streaming: true);
          case ComboPhaseStart() || ComboPhaseDone() || ComboDone():
            break;
        }
      }

      // 4. Finalize — keep blocks so the bubble stays visible after streaming.
      final finalBlocks = [
        MessageBlock.thinking(
          id: thinkingBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.success,
          createdAt: assistantTime,
          content: reasoningBuf.toString(),
        ),
        MessageBlock.mainText(
          id: mainBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.success,
          createdAt: assistantTime,
          content: mainBuf.toString(),
        ),
      ];
      assistantView = assistantView.copyWith(
        status: MessageStatus.success,
        blocks: finalBlocks,
      );
      views = [...views.take(views.length - 1), assistantView];
      _emitTurn(topicId, views, streaming: false);

      await _repo.saveMessageBlock(
        MessageBlock.thinking(
          id: thinkingBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.success,
          createdAt: assistantTime,
          content: reasoningBuf.toString(),
        ),
      );
      await _repo.saveMessageBlock(
        MessageBlock.mainText(
          id: mainBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.success,
          createdAt: assistantTime,
          content: mainBuf.toString(),
        ),
      );
      await _repo.saveMessage(
        assistantMessage.copyWith(status: MessageStatus.success),
      );
    } on Object catch (e) {
      final errorText = e is Failure ? e.message : e.toString();
      assistantView = assistantView.copyWith(
        status: MessageStatus.error,
        text: errorText,
      );
      views = [...views.take(views.length - 1), assistantView];
      _emitTurn(topicId, views, streaming: false);

      await _repo.saveMessageBlock(
        MessageBlock.mainText(
          id: mainBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.error,
          createdAt: assistantTime,
          content: errorText,
        ),
      );
      await _repo.saveMessage(
        assistantMessage.copyWith(status: MessageStatus.error),
      );
    }
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
  /// Resolves the [CurrentModel] for an assistant reply's own [model]: the
  /// listed provider that owns `model.provider` paired with its live copy of
  /// the model (so fresh apiKey/baseUrl apply), falling back to the stored model
  /// when it is no longer listed. Returns null when [model] is null or its
  /// provider is gone, so callers can fall back to the current model.
  Future<CurrentModel?> _currentModelForOwnModel(Model? model) async {
    if (model == null) return null;
    final providers = await ref.read(appModelProvidersProvider.future);
    for (final provider in providers) {
      if (provider.id != model.provider) continue;
      final live = provider.models.firstWhere(
        (m) => m.id == model.id,
        orElse: () => model,
      );
      return CurrentModel(provider: provider, model: live);
    }
    return null;
  }

  Future<void> regenerate(String messageId) async {
    _truncatedMessageId = null;
    final snapshot = state.value;
    if (snapshot == null || snapshot.isStreaming) return;

    final index = snapshot.messages.indexWhere((view) => view.id == messageId);
    if (index == -1) return;

    final target = await _repo.getMessage(messageId);
    if (target == null || target.role != MessageRole.assistant) return;

    // Plain regenerate keeps the reply on its OWN model (port of Cherry's
    // regenerateWithCapabilities — "a plain retry on an assistant uses the
    // target's own model, otherwise retrying kimi would produce a gemini reply
    // when the assistant default is gemini"). Falls back to the current model
    // when the reply has no stored model or its provider is gone. This is what
    // makes 多模型对比 的「重试失败」re-run each sibling on its own model.
    final current =
        await _currentModelForOwnModel(target.model) ??
        await ref.read(appCurrentModelProvider.future);
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
    final assistantView = ChatMessageView(
      id: messageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      createdAt: target.createdAt,
      modelName: effective.name,
      providerName: current.provider.name,
    );
    views[index] = assistantView;
    _emitTurn(target.topicId, views, streaming: true);

    final mcp = await _mcpSetup();
    final ctx = _contextSettings();
    final params = _parameterFields();
    final contextViews = _trimViews(views.sublist(0, index), ctx.contextCount);
    final regexRules = await _sendingRegexRules();
    final messages = await _buildLlmMessages(
      contextViews,
      chatModel: effective,
      regexRules: regexRules,
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
    final contextViews = _trimViews(snapshot.messages, ctx.contextCount);
    final regexRules = await _sendingRegexRules();
    final messages = await _buildLlmMessages(
      contextViews,
      chatModel: effective,
      regexRules: regexRules,
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

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    _truncatedMessageId = null;

    // Load the existing assistant message.
    final message = await _repo.getMessage(messageId);
    if (message == null || message.role != MessageRole.assistant) return;

    final effective = effectiveModelFor(current);
    final now = DateTime.now();

    // Gather existing blocks to extract the partial content so far.
    final existingBlocks = await _repo.getMessageBlocksByMessageId(messageId);
    final partialText = <String>[
      for (final block in existingBlocks)
        if (block is MainTextBlock && block.content.isNotEmpty) block.content,
    ].join('\n\n');

    // Build conversation history up to (but not including) this message, then
    // append the partial as an assistant turn for the model to continue from.
    final views = snapshot.messages;
    final msgIndex = views.indexWhere((v) => v.id == messageId);
    if (msgIndex < 0) return;

    final mcp = await _mcpSetup();
    final ctx = _contextSettings();
    final params = _parameterFields();
    final history = _trimViews(views.sublist(0, msgIndex), ctx.contextCount);
    final regexRules = await _sendingRegexRules();
    final messages = <LlmMessage>[
      ...await _buildLlmMessages(
        history,
        chatModel: effective,
        regexRules: regexRules,
        dropEmptyAssistant: false,
      ),
      // The partial response as an assistant turn so the model continues.
      if (partialText.isNotEmpty)
        LlmMessage(role: MessageRole.assistant, content: partialText),
    ];

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
  /// are returned; disabled ones stay `null`.
  ({
    double? temperature,
    double? topP,
    int? topK,
    double? frequencyPenalty,
    double? presencePenalty,
    int? seed,
    List<String>? stopSequences,
    String? responseFormat,
    bool? parallelToolCalls,
    bool? logprobs,
    String? user,
    String? reasoningEffort,
    int? thinkingBudget,
    bool? includeThoughts,
    bool? cacheControl,
    String? structuredOutputMode,
    bool? webSearchEnabled,
    bool? codeExecutionEnabled,
    bool? useSearchGrounding,
    String? safetyLevel,
    bool streamOutput,
    Map<String, dynamic>? customParameters,
  })
  _parameterFields() {
    final ps = ref.read(parameterSettingsControllerProvider);

    T? enabled<T>(String key) {
      if (!ps.isParameterEnabled(key)) return null;
      final v = ps.getParameterValue(key);
      if (v is T) return v;
      return null;
    }

    int? enabledInt(String key) {
      if (!ps.isParameterEnabled(key)) return null;
      final v = ps.getParameterValue(key);
      if (v is int) return v;
      if (v is num) return v.toInt();
      return null;
    }

    double? enabledDouble(String key) {
      if (!ps.isParameterEnabled(key)) return null;
      final v = ps.getParameterValue(key);
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return null;
    }

    // Stop sequences: stored as comma-separated string → List<String>
    List<String>? stops;
    final rawStops = enabled<String>('stopSequences');
    if (rawStops != null && rawStops.isNotEmpty) {
      stops = rawStops
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (stops.isEmpty) stops = null;
    }

    // Custom parameters
    Map<String, dynamic>? custom;
    if (ps.customParameters.isNotEmpty) {
      custom = <String, dynamic>{};
      for (final cp in ps.customParameters) {
        final name = cp['name'] as String?;
        if (name != null && name.isNotEmpty) {
          custom[name] = cp['value'];
        }
      }
      if (custom.isEmpty) custom = null;
    }

    return (
      temperature: enabledDouble('temperature'),
      topP: enabledDouble('topP'),
      topK: enabledInt('topK'),
      frequencyPenalty: enabledDouble('frequencyPenalty'),
      presencePenalty: enabledDouble('presencePenalty'),
      seed: enabledInt('seed'),
      stopSequences: stops,
      responseFormat: enabled<String>('responseFormat'),
      parallelToolCalls: enabled<bool>('parallelToolCalls'),
      logprobs: enabled<bool>('logprobs'),
      user: enabled<String>('user'),
      reasoningEffort: enabled<String>('reasoningEffort'),
      thinkingBudget: enabledInt('thinkingBudget'),
      includeThoughts: enabled<bool>('includeThoughts'),
      cacheControl: enabled<bool>('cacheControl'),
      structuredOutputMode: enabled<String>('structuredOutputMode'),
      webSearchEnabled: enabled<bool>('webSearchEnabled'),
      codeExecutionEnabled: enabled<bool>('codeExecutionEnabled'),
      useSearchGrounding: enabled<bool>('useSearchGrounding'),
      safetyLevel: enabled<String>('safetyLevel'),
      streamOutput: ps.isParameterEnabled('streamOutput')
          ? (ps.getParameterValue('streamOutput') as bool?) ?? true
          : true,
      customParameters: custom,
    );
  }

  /// Trims [views] to the last [count] entries so only recent history is sent
  /// to the model. When [count] covers all views the list is returned as-is.
  static List<ChatMessageView> _trimViews(
    List<ChatMessageView> views,
    int count,
  ) {
    if (views.length <= count) return views;
    return views.sublist(views.length - count);
  }

  /// The most rounds the tool-call loop will run before forcing a final answer.
  /// Raised to 25 to match the web's agentic mode; complex multi-tool tasks
  /// (e.g. "create a provider and add 3 models") easily exceed 5 rounds.
  static const int _kMaxToolRounds = 25;

  /// How many times we auto-continue when the model hits the token limit
  /// (`finishReason == 'length'`). After exhaustion the message is persisted
  /// with `metadata['truncated'] = true` so the UI can show a
  /// "继续生成" button.
  static const int _kMaxAutoContinues = 3;

  /// The most keys a single send tries before giving up, when the provider has a
  /// multi-key pool. Mirrors the web `EnhancedApiProvider` `maxRetries = 3`.
  static const int _kMaxKeyAttempts = 3;

  /// 流式回复 UI 刷新的最小间隔（节流窗口）。
  static const Duration _kStreamEmitInterval = Duration(milliseconds: 100);

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

    // 流式 UI 刷新节流（对齐 Cherry Studio 的 ~100ms 合帧）：SSE delta 一秒可达
    // 数十次，而每次刷新都要全量聚合文本并触发整段 Markdown 重建，成本随回复
    // 长度线性上涨；合并到至多每 100ms 一次后，单个 delta 不再放大为全文重排。
    // [update] 立即发射并取消尾随定时器（块边界/工具状态等需要即时呈现的时刻
    // 使用）；delta 走 [scheduleUpdate]，间隔不足时挂一个尾随定时器，保证最后
    // 一段文字不会丢帧。
    Timer? pendingEmit;
    var lastEmitAt = DateTime.fromMillisecondsSinceEpoch(0);

    void cancelPendingEmit() {
      pendingEmit?.cancel();
      pendingEmit = null;
    }

    void update() {
      cancelPendingEmit();
      lastEmitAt = DateTime.now();
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
      if (pendingEmit != null) return;
      final wait = _kStreamEmitInterval - DateTime.now().difference(lastEmitAt);
      if (wait <= Duration.zero) {
        update();
        return;
      }
      pendingEmit = Timer(wait, () {
        pendingEmit = null;
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
      cancelPendingEmit();
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

      // Reset the per-attempt accumulators so a failover retry starts clean,
      // re-seeding the leading memory-injection block so it survives retries.
      cancelPendingEmit();
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
                scheduleUpdate();
                checkpoint();
              case LlmReasoningDelta(:final text):
                committed = true;
                firstTokenMs ??= stopwatch.elapsedMilliseconds;
                thinkingStartAt ??= DateTime.now();
                thinking.write(text);
                scheduleUpdate();
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
                metadata: needsConfirm
                    ? const {'needsConfirmation': true}
                    : null,
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

        cancelPendingEmit();
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

    // Terminal failure: reject any pending confirmations, persist any key stat
    // changes, then mark the message errored.
    cancelPendingEmit();
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
    final message = await _repo.getMessage(messageId);
    await _repo.replaceMessageBlocks(
      messageId: messageId,
      blocks: blocks,
      message: message?.copyWith(
        status: status,
        updatedAt: now,
        blocks: [for (final block in blocks) block.id],
        usage: usage ?? message.usage,
        metrics: metrics ?? message.metrics,
      ),
    );
  }

  /// 崩溃恢复：把 [topicId] 里上次运行遗留在 streaming 状态的消息落定（对齐
  /// Cherry Studio 启动时的 `reconcileStalePendingMessages`）。检查点持久化让
  /// 闪退前的正文/思考/工具块都已在库里：有内容就按 success 保留（对话不丢），
  /// 一点内容都没有才标记 error；块级的 streaming/processing 状态一并落定，
  /// 其中未完成的工具块标记为 error（结果已随进程一起丢失），避免重启后出现
  /// 永远转圈的气泡。仅在该话题没有活跃流时调用。
  Future<void> _settleInterruptedMessages(String topicId) async {
    try {
      final messages = await _repo.getMessagesByTopicId(topicId);
      for (final message in messages) {
        if (message.status != MessageStatus.streaming) continue;
        final blocks = await _repo.getMessageBlocksByMessageId(message.id);
        final settled = <MessageBlock>[
          for (final block in blocks)
            switch (block) {
              ToolBlock(status: MessageBlockStatus.processing) =>
                block.copyWith(
                  status: MessageBlockStatus.error,
                  updatedAt: DateTime.now(),
                  content: '应用在工具执行期间退出，本次调用的结果已丢失',
                ),
              _
                  when block.status == MessageBlockStatus.streaming ||
                      block.status == MessageBlockStatus.processing ||
                      block.status == MessageBlockStatus.pending =>
                block.copyWith(
                  status: MessageBlockStatus.success,
                  updatedAt: DateTime.now(),
                ),
              _ => block,
            },
        ];
        final hasContent = settled.any(
          (b) =>
              (b is MainTextBlock && b.content.trim().isNotEmpty) ||
              (b is ThinkingBlock && b.content.trim().isNotEmpty) ||
              b is ToolBlock,
        );
        await _persistMessageBlocks(
          messageId: message.id,
          status: hasContent ? MessageStatus.success : MessageStatus.error,
          blocks: [
            for (final b in settled)
              if (b is! MainTextBlock || b.content.trim().isNotEmpty) b,
            if (!hasContent)
              MessageBlock.error(
                id: generateId('block'),
                messageId: message.id,
                status: MessageBlockStatus.error,
                createdAt: DateTime.now(),
                content: '',
                message: '回复在应用退出时被中断',
              ),
          ],
        );
      }
    } on Object catch (_) {
      // Recovery is best-effort; never block loading the conversation.
    }
  }

  /// Recomputes and persists the topic's `lastMessagePreview`, `lastMessageTime`
  /// and `messageCount` from the DB — the port of the web's
  /// `TopicPreviewService.refreshTopicPreview`. Failure is logged but never
  /// rethrown (preview is a display enhancement, must not disrupt the message
  /// flow).
  Future<void> _refreshTopicPreview([String? forTopicId]) async {
    final topicId = forTopicId ?? _topicId;
    if (topicId == null) return;
    try {
      final topic = await _repo.getTopic(topicId);
      if (topic == null) return;
      final messages = await _repo.getMessagesByTopicId(topicId);
      final count = messages.length;
      String preview = '';
      String? lastTime;
      if (messages.isNotEmpty) {
        messages.sort(compareMessagesChronologically);
        final last = messages.last;
        lastTime = (last.updatedAt ?? last.createdAt).toIso8601String();
        final blocks = await _repo.getMessageBlocksByMessageId(last.id);
        for (final block in blocks) {
          if (block is MainTextBlock && block.content.trim().isNotEmpty) {
            preview = _formatPreview(block.content);
            break;
          }
        }
      }
      if (topic.lastMessagePreview == preview &&
          topic.messageCount == count &&
          topic.lastMessageTime == lastTime) {
        return;
      }
      await _repo.saveTopic(
        topic.copyWith(
          lastMessagePreview: preview,
          messageCount: count,
          lastMessageTime: lastTime,
          updatedAt: DateTime.now(),
        ),
      );
      ref.invalidate(topicsProvider);
    } on Object catch (_) {
      // Preview refresh is non-critical; swallow errors.
    }
  }

  /// Collapse whitespace and truncate to 50 chars (mirrors the web's
  /// `formatPreviewText`).
  static String _formatPreview(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 50) return normalized;
    return '${normalized.substring(0, 50)}…';
  }

  /// Generates a conversation title using the configured title model + prompt.
  ///
  /// Mirrors rikkahub's `ChatService.generateTitle`: takes the last 4 messages,
  /// builds a summary, sends the title prompt to the title model (falling back
  /// to the current chat model), and saves the result as the topic name.
  /// Non-critical: failures are silently swallowed.
  Future<void> _generateTitle([String? forTopicId]) async {
    final topicId = forTopicId ?? _topicId;
    if (topicId == null) return;
    try {
      final topic = await _repo.getTopic(topicId);
      if (topic == null) return;

      // Skip if the name was manually edited or is already non-default.
      if (topic.isNameManuallyEdited) return;
      final name = topic.name;
      if (name != '新对话' &&
          name != '新的对话' &&
          name != '新话题' &&
          name.trim().isNotEmpty) {
        return;
      }

      // Gather the last 4 messages' text for context.
      final messages = await _repo.getMessagesByTopicId(topicId)
        ..sort(compareMessagesChronologically);
      if (messages.isEmpty) return;

      final recent = messages.length > 4
          ? messages.sublist(messages.length - 4)
          : messages;
      final summaryParts = <String>[];
      for (final msg in recent) {
        final blocks = await _repo.getMessageBlocksByMessageId(msg.id);
        final text = blocks
            .whereType<MainTextBlock>()
            .map((b) => b.content)
            .join('\n');
        if (text.trim().isEmpty) continue;
        final truncated = text.length > 500
            ? '${text.substring(0, 500)}…'
            : text;
        final role = msg.role == MessageRole.user ? '用户' : 'AI';
        summaryParts.add('$role: $truncated');
      }
      if (summaryParts.isEmpty) return;
      final contentSummary = summaryParts.join('\n\n');

      // Resolve the title model; fall back to the current chat model.
      final auxState = ref.read(auxiliaryModelControllerProvider);
      final providers = await ref.read(appModelProvidersProvider.future);
      var resolved = resolveAuxiliaryModel(auxState.titleModelKey, providers);
      resolved ??= findCurrentModel(providers);
      if (resolved == null) return;

      final effective = effectiveModelFor(resolved);
      final titlePrompt = auxState.titlePrompt;

      // Build the prompt by replacing {{messages}} / {content} / {locale}.
      final locale = 'Chinese';
      var prompt = titlePrompt
          .replaceAll('{{messages}}', contentSummary)
          .replaceAll('{content}', contentSummary)
          .replaceAll('{locale}', locale);
      // If the template didn't contain any placeholder, append the content.
      if (prompt == titlePrompt) {
        prompt = '$titlePrompt\n\n$contentSummary';
      }

      final request = LlmChatRequest(
        model: effective,
        messages: [LlmMessage(role: MessageRole.user, content: prompt)],
        extraHeaders: effective.providerExtraHeaders,
        extraBody: effective.providerExtraBody,
      );

      final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
      final buffer = StringBuffer();
      await for (final chunk in gateway.streamChat(request)) {
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
          case LlmReasoningDelta():
          case LlmToolCallChunk():
          case LlmDone():
            break;
        }
      }

      var newTitle = buffer.toString().trim();
      if (newTitle.isEmpty) return;

      // Strip surrounding quotes if the model wrapped the title.
      if (newTitle.startsWith('"') && newTitle.endsWith('"')) {
        newTitle = newTitle.substring(1, newTitle.length - 1).trim();
      }
      if (newTitle.startsWith('「') && newTitle.endsWith('」')) {
        newTitle = newTitle.substring(1, newTitle.length - 1).trim();
      }
      if (newTitle.isEmpty || newTitle == name) return;

      // Re-fetch topic (may have changed during generation).
      final latest = await _repo.getTopic(topicId);
      if (latest == null || latest.isNameManuallyEdited) return;

      await _repo.saveTopic(
        latest.copyWith(name: newTitle, updatedAt: DateTime.now()),
      );
      ref.invalidate(topicsProvider);
    } on Object catch (_) {
      // Title generation is non-critical; swallow errors.
    }
  }

  /// Generates follow-up suggestions (建议模型) for the just-finished reply on
  /// [turnTopicId], then pushes them into state if that topic is still the one
  /// being viewed. A no-op unless the 建议 feature is enabled and a suggestion
  /// model is configured (footnote: "未设置时不生成后续问题建议"). Best-effort:
  /// any failure is swallowed, like title generation.
  Future<void> _maybeGenerateSuggestions(
    String turnTopicId,
    List<ChatMessageView> views,
  ) async {
    try {
      final auxState = ref.read(auxiliaryModelControllerProvider);
      if (!auxState.enableSuggestion) return;
      final providers = await ref.read(appModelProvidersProvider.future);
      final resolved = resolveAuxiliaryModel(
        auxState.suggestionModelKey,
        providers,
      );
      if (resolved == null) return;

      final content = SuggestionService.buildContent(views);
      if (content.isEmpty) return;

      final effective = effectiveModelFor(resolved);
      const locale = 'Chinese';
      var prompt = auxState.suggestionPrompt
          .replaceAll('{{messages}}', content)
          .replaceAll('{content}', content)
          .replaceAll('{locale}', locale);
      // If the template carried no placeholder, append the content.
      if (prompt == auxState.suggestionPrompt) {
        prompt = '${auxState.suggestionPrompt}\n\n$content';
      }

      final request = LlmChatRequest(
        model: effective,
        messages: [LlmMessage(role: MessageRole.user, content: prompt)],
        extraHeaders: effective.providerExtraHeaders,
        extraBody: effective.providerExtraBody,
      );

      final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
      final buffer = StringBuffer();
      await for (final chunk in gateway.streamChat(request)) {
        if (chunk is LlmTextDelta) buffer.write(chunk.text);
      }

      final suggestions = SuggestionService.parseSuggestions(buffer.toString());
      if (suggestions.isEmpty) return;
      _emitSuggestions(turnTopicId, suggestions);
    } on Object catch (_) {
      // Suggestion generation is non-critical; swallow errors.
    }
  }

  /// Auto-extracts long-term memories (autoAnalyze) from the just-finished turn
  /// on [turnTopicId] and writes them to the 普通聊天 memory store. A no-op
  /// unless 记忆 is enabled and at least one 自动写入 toggle is on. The extraction
  /// itself runs on the 快速/标题 auxiliary model (falling back to the current
  /// chat model). Best-effort: any failure is swallowed, like title generation.
  Future<void> _maybeExtractMemory(String turnTopicId) async {
    try {
      final flags = readMemoryAutoWriteFlags(ref);
      if (!flags.enabled) return;
      if (!flags.autoWritePrivate && !flags.autoWriteGlobal) return;

      final assistantId = _assistantId;

      // Gather the last 6 messages' text as the extraction context.
      final messages = await _repo.getMessagesByTopicId(turnTopicId)
        ..sort(compareMessagesChronologically);
      if (messages.isEmpty) return;
      final recent = messages.length > 6
          ? messages.sublist(messages.length - 6)
          : messages;
      final lines = <String>[];
      for (final msg in recent) {
        final blocks = await _repo.getMessageBlocksByMessageId(msg.id);
        final text = blocks
            .whereType<MainTextBlock>()
            .map((b) => b.content)
            .join('\n')
            .trim();
        if (text.isEmpty) continue;
        final truncated = text.length > 800 ? '${text.substring(0, 800)}…' : text;
        final role = msg.role == MessageRole.user ? '用户' : 'AI';
        lines.add('$role: $truncated');
      }
      if (lines.isEmpty) return;
      final conversation = lines.join('\n\n');

      // Resolve the extraction model: 快速模型 → 标题模型 → current chat model.
      final auxState = ref.read(auxiliaryModelControllerProvider);
      final providers = await ref.read(appModelProvidersProvider.future);
      var resolved = resolveAuxiliaryModel(auxState.fastModelKey, providers);
      resolved ??= resolveAuxiliaryModel(auxState.titleModelKey, providers);
      resolved ??= findCurrentModel(providers);
      if (resolved == null) return;
      final effective = effectiveModelFor(resolved);

      final prompt = buildMemoryExtractionPrompt(
        conversation: conversation,
        allowGlobal: flags.autoWriteGlobal,
        allowPrivate: flags.autoWritePrivate,
      );

      final request = LlmChatRequest(
        model: effective,
        messages: [LlmMessage(role: MessageRole.user, content: prompt)],
        extraHeaders: effective.providerExtraHeaders,
        extraBody: effective.providerExtraBody,
      );

      final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);
      final buffer = StringBuffer();
      await for (final chunk in gateway.streamChat(request)) {
        if (chunk is LlmTextDelta) buffer.write(chunk.text);
      }

      final candidates = parseMemoryExtractionResponse(buffer.toString())
          .where(
            (c) => c.level == MemoryLevel.global
                ? flags.autoWriteGlobal
                : flags.autoWritePrivate,
          )
          .toList();
      if (candidates.isEmpty) return;

      await storeExtractedChatMemories(
        ref,
        assistantId: assistantId,
        candidates: candidates,
      );
    } on Object catch (_) {
      // Memory extraction is non-critical; swallow errors.
    }
  }

  /// Pushes [suggestions] into the live state, but only when [turnTopicId] is
  /// still the topic on screen and a new reply hasn't started streaming (which
  /// would have cleared them). Leaves [messages] untouched.
  void _emitSuggestions(String turnTopicId, List<String> suggestions) {
    if (turnTopicId != _topicId) return;
    final current = state.value;
    if (current == null || current.isStreaming) return;
    state = AsyncData(current.copyWith(suggestions: suggestions));
  }

  /// Deletes [messageId] together with its blocks and drops it from the view.
  ///
  /// Port of the toolbar 删除 action (`MessageActions.handleToolbarDeleteClick`
  /// → `onDelete`). The two-click confirmation lives in the UI; this performs
  /// the actual removal once confirmed. A no-op while a reply is streaming or
  /// when the conversation has not loaded.
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
    final content = mainTextOf(_orderBlocks(message.blocks, fetched)).trim();
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
  /// [_decodeFileText] feeds them to the model).
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
  Future<List<LlmMessage>> _buildLlmMessages(
    Iterable<ChatMessageView> views, {
    required Model chatModel,
    List<AssistantRegex>? regexRules,
    bool dropEmptyAssistant = true,
  }) async {
    final ocr = await _resolveOcrFallback(chatModel);
    final messages = <LlmMessage>[];
    for (final view in views) {
      if (dropEmptyAssistant &&
          view.role == MessageRole.assistant &&
          view.text.isEmpty) {
        continue;
      }
      var content = _requestContent(view, regexRules: regexRules);
      var images = _requestImages(view);
      if (ocr != null && images != null && images.isNotEmpty) {
        final ocrText = await ref
            .read(ocrServiceProvider)
            .recognizeImages(
              images: images,
              ocrModel: ocr.model,
              prompt: ocr.prompt,
            );
        if (ocrText != null && ocrText.isNotEmpty) {
          content = content.isEmpty ? ocrText : '$ocrText\n\n$content';
          images = null;
        }
      }
      messages.add(
        LlmMessage(role: view.role, content: content, images: images),
      );
    }
    return messages;
  }

  /// Resolves the OCR fallback for [chatModel]: returns the configured OCR
  /// (vision) model + prompt only when [chatModel] itself lacks vision support
  /// and a usable 辅助模型 → OCR model is configured. Vision support is read
  /// from the model's detected capabilities (registry/inference) or an explicit
  /// `ModelType.vision` selection (see `isVisionModel`).
  /// Returns `null` otherwise, so vision-capable models keep receiving images
  /// directly and image turns are left untouched when no OCR model is set
  /// (footnote: "未设置时使用聊天模型识别图片").
  Future<({Model model, String prompt})?> _resolveOcrFallback(
    Model chatModel,
  ) async {
    if (isVisionModel(chatModel)) return null;
    final auxState = ref.read(auxiliaryModelControllerProvider);
    final providers = await ref.read(appModelProvidersProvider.future);
    final resolved = resolveAuxiliaryModel(auxState.ocrModelKey, providers);
    if (resolved == null) return null;
    return (model: effectiveModelFor(resolved), prompt: auxState.ocrPrompt);
  }

  /// The image parts on [view] (raw base64) for a multimodal request, decoded
  /// from its `IMAGE` blocks; `null` when it has none so plain-text turns are
  /// serialised unchanged.
  List<LlmContentImage>? _requestImages(ChatMessageView view) {
    final images = <LlmContentImage>[
      for (final block in view.blocks)
        if (block is ImageBlock)
          if (_imagePart(block) case final part?) part,
    ];
    return images.isEmpty ? null : images;
  }

  /// Resolves an [ImageBlock] to a request image part, preferring its raw
  /// [ImageBlock.base64Data] and falling back to the file reference's `data:`
  /// URI; `null` when neither carries data.
  LlmContentImage? _imagePart(ImageBlock block) {
    final raw = block.base64Data;
    if (raw != null && raw.isNotEmpty) {
      return LlmContentImage(mimeType: block.mimeType, base64Data: raw);
    }
    final reference = block.file?.base64Data;
    if (reference != null && reference.isNotEmpty) {
      final comma = reference.indexOf(',');
      final encoded = comma >= 0 ? reference.substring(comma + 1) : reference;
      if (encoded.isNotEmpty) {
        return LlmContentImage(mimeType: block.mimeType, base64Data: encoded);
      }
    }
    return null;
  }

  /// The request content for [view]: its main text with each FILE block's
  /// decoded text appended, so the model receives pasted-as-file content (and
  /// likewise for history, since [_viewOf] carries FILE blocks through).
  ///
  /// When [regexRules] are supplied, the assistant's non-`visualOnly` 正则规则
  /// are applied (scoped by `view.role`) before sending — the port of the web
  /// `applyRegexRulesForSending` step in `apiPreparation.ts`.
  String _requestContent(
    ChatMessageView view, {
    List<AssistantRegex>? regexRules,
  }) {
    final parts = <String>[
      if (view.text.isNotEmpty) view.text,
      for (final block in view.blocks)
        if (block is FileBlock)
          if (_decodeFileText(block) case final text? when text.isNotEmpty)
            text,
    ];
    final content = parts.join('\n\n');
    final scope = _regexScopeFor(view.role);
    if (scope == null || regexRules == null || regexRules.isEmpty) {
      return content;
    }
    return applyRegexRulesForSending(content, regexRules, scope);
  }

  /// Maps a [MessageRole] to its 正则 scope, or null for roles (e.g. system)
  /// that 正则规则 never target.
  static AssistantRegexScope? _regexScopeFor(MessageRole role) =>
      switch (role) {
        MessageRole.user => AssistantRegexScope.user,
        MessageRole.assistant => AssistantRegexScope.assistant,
        _ => null,
      };

  /// The current assistant's 正则规则, used to process outgoing message content.
  Future<List<AssistantRegex>?> _sendingRegexRules() async =>
      (await _repo.getAssistant(_assistantId))?.regexRules;

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
  /// `assistantPrompt [+ '\n\n' + topicPrompt]`), substitutes inline
  /// placeholder variables ([replaceSystemPromptPlaceholders] — `{model_name}`,
  /// `{assistant_name}`, `{cur_date}` …), then appends the enabled 系统提示词变量
  /// (time / location / OS / locale). Returns `null` when the assembled prompt
  /// is empty, so requests with no system prompt stay system-less (the
  /// append-only variables are never injected into an empty prompt, matching the
  /// web `injectSystemPromptVariables`).
  Future<String?> _buildSystemPrompt({
    required String modelName,
    required String modelId,
    required String providerName,
  }) async {
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

    final memorySection = await buildChatMemoryInjection(
      ref,
      assistantId: _assistantId,
    );
    return _composeSystemPrompt(
      replaceSystemPromptPlaceholders(
        base,
        modelName: modelName,
        modelId: modelId,
        assistantName: assistant?.name ?? '',
        providerName: providerName,
      ),
      memorySection,
    );
  }

  /// Injects prompt variables into [base] and appends the resolved
  /// [memorySection] (the `<user_memories>` block, or null/empty for none),
  /// returning null when the result is empty. Split out so [send] can reuse the
  /// already-resolved memory section instead of querying the store twice.
  String? _composeSystemPrompt(String base, String? memorySection) {
    final injected = injectSystemPromptVariables(
      base,
      ref.read(systemPromptVariablesProvider),
    );
    final withMemory = (memorySection == null || memorySection.isEmpty)
        ? injected
        : (injected.isEmpty ? memorySection : '$injected\n\n$memorySection');
    return withMemory.isEmpty ? null : withMemory;
  }

  /// Like [_buildSystemPrompt] but reuses a pre-resolved [memorySection] (from
  /// [collectChatMemoryInjection]) so the memory store is read once per turn.
  Future<String?> _buildSystemPromptWith(
    String? memorySection, {
    required String modelName,
    required String modelId,
    required String providerName,
  }) async {
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

    return _composeSystemPrompt(
      replaceSystemPromptPlaceholders(
        base,
        modelName: modelName,
        modelId: modelId,
        assistantName: assistant?.name ?? '',
        providerName: providerName,
      ),
      memorySection,
    );
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

  /// Assembles the [McpSetup] for the current turn (see [buildMcpSetup]);
  /// the bound-skills lookup stays here because it needs the repository and
  /// the controller's active assistant.
  Future<McpSetup> _mcpSetup() => buildMcpSetup(
    ref,
    loadBoundSkills: () async {
      final assistant = await _repo.getAssistant(_assistantId);
      return _enabledSkillsFor(assistant?.skillIds);
    },
  );

  /// The system prompt for a turn: in 提示词注入 mode the tool catalogue is woven
  /// into [base] (web `buildSystemPrompt`); otherwise [base] is used as-is and
  /// tools ride the native `tools` field. When 网络搜索 is active, a hint is
  /// appended encouraging the model to use the search tool.
  String? _systemFor(McpSetup mcp, String? base) {
    var prompt = mcp.usePromptInjection
        ? buildMcpSystemPrompt(base, mcp.tools)
        : base;
    if (ref.read(inputModeControllerProvider) == InputMode.webSearch) {
      const hint =
          '\n\n[网络搜索已启用] '
          '你可以使用 builtin_web_search 工具搜索互联网获取实时信息。'
          '当用户的问题可能需要最新信息时，请主动使用搜索工具。'
          '搜索结果中如果有有用的链接，请在回答中引用。';
      prompt = (prompt ?? '') + hint;
    }
    if (shouldExposeMemorySearchTool(ref)) {
      const hint =
          '\n\n[长期记忆已启用] '
          '你可以使用 search_memory 工具检索关于用户的长期记忆（偏好、事实、历史）。'
          '当回答可能依赖用户的个人偏好或既往信息时，请先调用该工具确认。';
      prompt = (prompt ?? '') + hint;
    }
    if (mcp.routes.values.any((r) => r is KnowledgeToolRoute)) {
      const hint =
          '\n\n[知识库已启用] '
          '你可以使用 kb_search 工具在用户的知识库中检索资料，用 kb_read 取回条目全文。'
          '当用户的问题可能依赖其知识库内容时，请主动检索，并在回答中引用来源。';
      prompt = (prompt ?? '') + hint;
    }
    final workspaceContext = mcp.workspaceContext;
    if (workspaceContext != null && workspaceContext.isNotEmpty) {
      prompt = '${prompt ?? ''}\n\n$workspaceContext';
    }
    return prompt;
  }

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
    final mainText = blocks
        .whereType<MainTextBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final summaryText = blocks
        .whereType<ContextSummaryBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final text = mainText.isNotEmpty ? mainText : summaryText;
    final thinking = blocks
        .whereType<ThinkingBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final errors = blocks.whereType<ErrorBlock>();
    final error = errors.isEmpty ? null : errors.first;
    final model = message.model;
    String? providerName;
    if (model != null) {
      if (model.provider == kModelComboProviderId) {
        providerName = '模型组合';
      } else {
        final providers = await ref.read(appModelProvidersProvider.future);
        for (final provider in providers) {
          if (provider.id == model.provider) {
            providerName = provider.name;
            break;
          }
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
      modelId: model?.id ?? message.modelId,
      providerId: model?.provider,
      askId: message.askId,
      debatePhase: _debatePhaseOf(message.metadata),
      siblingsGroupId: message.siblingsGroupId,
      multiModelMessageStyle: message.multiModelMessageStyle,
      foldSelected: message.foldSelected ?? false,
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
    // The background keep-alive service is driven per-topic by the
    // StreamingRegistry (begin on the first streaming topic, end on the last),
    // not here, so a finished current topic doesn't stop a background one.
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
    for (final message in messages) {
      if (message.id == id) return message;
    }
    return null;
  }
}
