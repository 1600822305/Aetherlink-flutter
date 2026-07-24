// 多模型 sibling 组相关的会话操作，从 ChatController 的 part/mixin 服务化：
// 多模型对比发送、sibling 选择/折叠同步、布局切换、失败重试、整组删除、
// 模型组合（combo）顺序执行、以及根据消息自身模型解析 CurrentModel。
// 依赖经 [ChatModeContext] 显式注入，不再靠 mixin 的 this 共享私有成员。

import 'dart:async';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_selection_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/combo_executor.dart';
import 'package:aetherlink_flutter/features/chat/application/modes/chat_mode_context.dart';
import 'package:aetherlink_flutter/features/chat/application/mounted_knowledge_bases_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/send/llm_request_params.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/multi_model_message_style.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_providers.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';

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

/// 多模型对比 / 模型组合模式的发送链路（[ChatController] 的协作对象）。
class MultiModelSendService {
  const MultiModelSendService(this._ctx);

  final ChatModeContext _ctx;

  /// Sends a user message and streams a parallel multi-model reply: one
  /// assistant sibling per [models], all sharing the same parent (the user
  /// message) and a `siblingsGroupId` so the 对比 group widget can identify
  /// them. The first sibling becomes the active leaf; the display projection
  /// (`orderBranchMessages`) inlines the whole group so the 对比 group widget can
  /// lay them out. A blank message, no models, or an in-flight stream are no-ops.
  Future<void> sendMultiModel(
    String text,
    List<CurrentModel> models, {
    List<ComposerAttachment> attachments = const <ComposerAttachment>[],
  }) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && attachments.isEmpty) || models.isEmpty) return;
    final snapshot = _ctx.snapshot ?? ChatState.initial();
    if (snapshot.isStreaming) return;

    _ctx.clearTruncated();
    final topicId = await _ctx.ensureTopic();
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
        _ctx.attachmentBlock(
          messageId: userMessageId,
          createdAt: now,
          attachment: attachment,
        ),
    ];
    final userMessage = Message(
      id: userMessageId,
      role: MessageRole.user,
      assistantId: _ctx.assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.success,
      mentions: <Model>[for (final m in models) m.model],
      blocks: <String>[for (final block in userBlocks) block.id],
    );
    await _ctx.repo.saveMessage(userMessage);
    for (final block in userBlocks) {
      await _ctx.repo.saveMessageBlock(block);
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
        assistantId: _ctx.assistantId,
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
      await _ctx.repo.saveMessage(assistantMessage);
      await _ctx.repo.saveMessageBlock(
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
    _ctx.emitTurn(topicId, views, streaming: true);

    // 4/5. Everything after the streaming:true emit runs inside try/finally:
    //    an escaped exception anywhere here would skip step 6 and leave the
    //    topic in streaming state forever (every send/regenerate becomes a
    //    no-op until app restart).
    try {
      // 4. Shared request context: the history up to and including the user
      //    turn. The sibling placeholders are excluded so every model answers
      //    the same conversation independently.
      final mcp = await _ctx.mcpSetup();
      final ctx = _ctx.contextSettings();
      final params = _ctx.parameterFields();
      final regexRules = await _ctx.sendingRegexRules();
      final baseViews = <ChatMessageView>[...snapshot.messages, userView];
      final contextViews = _ctx.trimViews(
        _ctx.filterSiblingsForContext(baseViews),
        ctx.contextCount,
      );
      final memInjection = await collectChatMemoryInjection(
        _ctx.ref,
        assistantId: _ctx.assistantId,
        query: trimmed,
      );
      final kbInjection = await collectChatKnowledgeInjection(
        _ctx.ref,
        baseIds: _ctx.ref.read(mountedKnowledgeBasesProvider),
        query: trimmed,
      );

      // 5. Stream every sibling in parallel; each keeps the turn alive
      //    (finalizeTurn: false) so the others stay visible until all settle.
      //    Each sibling is individually guarded, so the wait never rejects.
      await Future.wait(<Future<void>>[
        for (final sibling in siblings)
          _streamSiblingGuarded(
            sibling: sibling,
            topicId: topicId,
            views: views,
            mcp: mcp,
            ctx: ctx,
            params: params,
            regexRules: regexRules,
            contextViews: contextViews,
            memInjection: memInjection,
            kbInjection: kbInjection,
          ),
      ]);
    } on Object catch (error) {
      // Shared prep failed before any sibling streamed (记忆/知识库检索、MCP
      // setup…): mark every still-streaming sibling errored so none is left as
      // a hollow streaming bubble.
      for (final sibling in siblings) {
        await _failSibling(
          sibling: sibling,
          topicId: topicId,
          views: views,
          error: error,
        );
      }
    } finally {
      // 6. Whole turn done: end streaming and run the once-per-turn side
      //    effects.
      _ctx.emitTurn(topicId, views, streaming: false);
    }
    unawaited(_ctx.refreshTopicPreview(topicId));
    unawaited(_ctx.generateTitle(topicId));
    unawaited(_ctx.maybeGenerateSuggestions(topicId, List.of(views)));
    unawaited(_ctx.maybeExtractMemory(topicId));
  }

  /// Builds and streams one multi-model sibling, converting any failure into
  /// an errored sibling message (error block + [MessageStatus.error]) so the
  /// coordinator's [Future.wait] never rejects.
  Future<void> _streamSiblingGuarded({
    required _MultiModelSibling sibling,
    required String topicId,
    required List<ChatMessageView> views,
    required McpSetup mcp,
    required ({int contextCount, int? maxTokens}) ctx,
    required List<AssistantRegex>? regexRules,
    required List<ChatMessageView> contextViews,
    required ChatMemoryInjection memInjection,
    required ChatKnowledgeInjection kbInjection,
    required LlmParameterFields params,
  }) async {
    try {
      final effective = sibling.effective;
      final provider = sibling.current.provider;
      final messages = await _ctx.buildLlmMessages(
        contextViews,
        chatModel: effective,
        regexRules: regexRules,
        toolMode: mcp.mode,
      );
      final request = LlmChatRequest(
        model: effective,
        system: _ctx.systemFor(
          mcp,
          await _ctx.buildSystemPromptWith(
            _ctx.joinInjectionSections(
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
      await _ctx.streamInto(
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
          ..._ctx.memoryInjectionBlocks(
            messageId: sibling.assistantMessageId,
            createdAt: sibling.assistantTime,
            injection: memInjection,
          ),
          ..._ctx.knowledgeReferenceBlocks(
            messageId: sibling.assistantMessageId,
            createdAt: sibling.assistantTime,
            injection: kbInjection,
          ),
        ],
        finalizeTurn: false,
      );
    } on Object catch (error) {
      // Anything that slipped past streamInto's own handling (request
      // building, gateway construction, terminal persistence): mark this
      // sibling errored so the group renders the failure and 重试失败 can
      // re-run it.
      await _failSibling(
        sibling: sibling,
        topicId: topicId,
        views: views,
        error: error,
      );
    }
  }

  /// Persists [sibling] as errored (error block + [MessageStatus.error]) and
  /// refreshes its view in the live turn, keeping the turn streaming — the
  /// coordinator's `finally` ends it.
  Future<void> _failSibling({
    required _MultiModelSibling sibling,
    required String topicId,
    required List<ChatMessageView> views,
    required Object error,
  }) async {
    final messageText = _ctx.errorMessage(error);
    try {
      await _ctx.persistMessageBlocks(
        messageId: sibling.assistantMessageId,
        status: MessageStatus.error,
        blocks: <MessageBlock>[
          MessageBlock.error(
            id: generateId('block'),
            messageId: sibling.assistantMessageId,
            status: MessageBlockStatus.error,
            createdAt: sibling.assistantTime,
            updatedAt: DateTime.now(),
            content: '',
            message: messageText,
          ),
        ],
      );
    } on Object catch (_) {
      // Best-effort persistence — the in-memory view below still shows it.
    }
    final errored = await _ctx.reloadView(
      sibling.assistantMessageId,
      sibling.assistantView.copyWith(
        status: MessageStatus.error,
        errorText: messageText,
      ),
    );
    _ctx.replace(views, errored);
    _ctx.emitTurn(topicId, views, streaming: true);
  }

  /// The next free sibling-group id for [topicId]: one past the largest existing
  /// `siblingsGroupId`, so a fresh multi-model group never collides with prior
  /// groups in the same topic.
  Future<int> _nextSiblingsGroupId(String topicId) async {
    final messages = await _ctx.repo.getMessagesByTopicId(topicId);
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
    final snapshot = _ctx.snapshot;
    if (snapshot == null || snapshot.isStreaming) return;
    final topicId = _ctx.topicId;
    if (topicId == null) return;
    final message = await _ctx.repo.getMessage(messageId);
    if (message == null || message.siblingsGroupId <= 0) return;
    if (message.foldSelected == true) return;

    await syncFoldSelectedForGroup(topicId, messageId);
    await _ctx.repo.setActiveNode(topicId, messageId);
    _ctx.ref.read(chatRefreshProvider.notifier).bump();
  }

  /// Makes [nodeId] the `foldSelected` member of its multi-model group (clearing
  /// the flag on its peers), so the 对比 group's 折叠 selection stays in sync with
  /// whatever made [nodeId] the active branch — whether that was the in-group
  /// model chip ([selectSibling]) or the 分支管理 canvas (`switchToBranch`). A
  /// no-op when [nodeId] isn't a grouped sibling or is already selected.
  Future<void> syncFoldSelectedForGroup(String topicId, String nodeId) async {
    final message = await _ctx.repo.getMessage(nodeId);
    if (message == null || message.siblingsGroupId <= 0) return;
    if (message.foldSelected == true) return;
    final all = await _ctx.repo.getMessagesByTopicId(topicId);
    for (final m in all) {
      if (m.parentId == message.parentId &&
          m.siblingsGroupId == message.siblingsGroupId) {
        final selected = m.id == nodeId;
        if ((m.foldSelected ?? false) != selected) {
          await _ctx.repo.saveMessage(m.copyWith(foldSelected: selected));
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
      final message = await _ctx.repo.getMessage(id);
      if (message == null || message.multiModelMessageStyle == style) continue;
      await _ctx.repo.saveMessage(
        message.copyWith(multiModelMessageStyle: style),
      );
    }
  }

  /// Re-runs every errored sibling of a multi-model group (port of the web
  /// `handleRetryFailed`, which calls `onRegenerate` for each failed message).
  /// No-op while streaming.
  Future<void> retryFailedSiblings(List<String> memberIds) async {
    final snapshot = _ctx.snapshot;
    if (snapshot == null || snapshot.isStreaming) return;
    for (final id in memberIds) {
      final failed = snapshot.messages.any(
        (v) => v.id == id && v.status == MessageStatus.error,
      );
      if (failed) await _ctx.regenerate(id);
    }
  }

  /// Deletes a whole multi-model 对比 group — the asked user message and all its
  /// sibling replies — by cascade-removing the subtree rooted at [askId] (port
  /// of the web `handleDeleteGroup`). No-op while streaming.
  Future<void> deleteMultiModelGroup(String askId) async {
    final snapshot = _ctx.snapshot;
    if (snapshot == null || snapshot.isStreaming) return;
    await _ctx.deleteMessage(askId, cascade: true);
  }

  /// Sends a user message and streams the combo (sequential) response.
  /// Phase 1: streams the thinking model's reasoning into a thinking block.
  /// Phase 2: streams the generating model's answer into the main text block.
  Future<void> sendCombo(
    String text,
    ComboResolution resolution, {
    List<ComposerAttachment> attachments = const <ComposerAttachment>[],
  }) async {
    final snapshot = _ctx.snapshot ?? ChatState.initial();
    final topicId = await _ctx.ensureTopic();
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
        _ctx.attachmentBlock(
          messageId: userMessageId,
          createdAt: now,
          attachment: attachment,
        ),
    ];
    final userMessage = Message(
      id: userMessageId,
      role: MessageRole.user,
      assistantId: _ctx.assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.success,
      blocks: <String>[for (final block in userBlocks) block.id],
    );
    await _ctx.repo.saveMessage(userMessage);
    for (final block in userBlocks) {
      await _ctx.repo.saveMessageBlock(block);
    }

    // 2. Assistant message with a thinking block + main text block.
    final assistantTime = now.add(const Duration(microseconds: 1));
    final assistantMessageId = generateId('msg');
    final thinkingBlockId = generateId('block');
    final mainBlockId = generateId('block');

    // Synthetic model carrying the combo display label so `viewOf` reads the
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
      assistantId: _ctx.assistantId,
      topicId: topicId,
      createdAt: assistantTime,
      status: MessageStatus.streaming,
      model: comboModel,
      askId: userMessageId,
      blocks: <String>[thinkingBlockId, mainBlockId],
    );
    await _ctx.repo.saveMessage(assistantMessage);
    await _ctx.repo.saveMessageBlock(
      MessageBlock.thinking(
        id: thinkingBlockId,
        messageId: assistantMessageId,
        status: MessageBlockStatus.streaming,
        createdAt: assistantTime,
        content: '',
      ),
    );
    await _ctx.repo.saveMessageBlock(
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
    _ctx.emitTurn(topicId, views, streaming: true);

    // 3. Build messages for the thinking model request.
    final ctx = _ctx.contextSettings();
    final contextViews = _ctx.trimViews(
      _ctx.filterSiblingsForContext(views),
      ctx.contextCount,
    );
    final regexRules = await _ctx.sendingRegexRules();
    final llmMessages = [
      for (final view in contextViews)
        if (view.role != MessageRole.assistant || view.text.isNotEmpty)
          LlmMessage(
            role: view.role,
            content: _ctx.requestContent(view, regexRules: regexRules),
          ),
    ];

    final gatewayFactory = _ctx.ref.read(llmGatewayFactoryProvider);
    final thinkingGateway = gatewayFactory.forModel(thinking.model);
    final generatingGateway = gatewayFactory.forModel(generating.model);

    final system = _ctx.systemFor(
      await _ctx.mcpSetup(),
      await _ctx.buildSystemPrompt(
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
            _ctx.emitTurn(topicId, views, streaming: true);
          case ComboTextDelta(:final text):
            mainBuf.write(text);
            assistantView = assistantView.copyWith(
              text: mainBuf.toString(),
              blocks: liveBlocks(),
            );
            views = [...views.take(views.length - 1), assistantView];
            _ctx.emitTurn(topicId, views, streaming: true);
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
      _ctx.emitTurn(topicId, views, streaming: false);

      await _ctx.repo.saveMessageBlock(
        MessageBlock.thinking(
          id: thinkingBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.success,
          createdAt: assistantTime,
          content: reasoningBuf.toString(),
        ),
      );
      await _ctx.repo.saveMessageBlock(
        MessageBlock.mainText(
          id: mainBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.success,
          createdAt: assistantTime,
          content: mainBuf.toString(),
        ),
      );
      await _ctx.repo.saveMessage(
        assistantMessage.copyWith(status: MessageStatus.success),
      );
    } on Object catch (e) {
      final errorText = e is Failure ? e.message : e.toString();
      assistantView = assistantView.copyWith(
        status: MessageStatus.error,
        text: errorText,
      );
      views = [...views.take(views.length - 1), assistantView];
      _ctx.emitTurn(topicId, views, streaming: false);

      await _ctx.repo.saveMessageBlock(
        MessageBlock.mainText(
          id: mainBlockId,
          messageId: assistantMessageId,
          status: MessageBlockStatus.error,
          createdAt: assistantTime,
          content: errorText,
        ),
      );
      await _ctx.repo.saveMessage(
        assistantMessage.copyWith(status: MessageStatus.error),
      );
    }
  }

  /// Resolves the [CurrentModel] for an assistant reply's own [model]: the
  /// listed provider that owns `model.provider` paired with its live copy of
  /// the model (so fresh apiKey/baseUrl apply), falling back to the stored model
  /// when it is no longer listed. Returns null when [model] is null or its
  /// provider is gone, so callers can fall back to the current model.
  Future<CurrentModel?> currentModelForOwnModel(Model? model) async {
    if (model == null) return null;
    final providers = await _ctx.ref.read(appModelProvidersProvider.future);
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
}
