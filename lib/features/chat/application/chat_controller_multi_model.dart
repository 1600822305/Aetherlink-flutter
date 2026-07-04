// 多模型 sibling 组相关的会话操作，从 chat_controller.dart 主体拆出的 part 文件：
// 多模型对比发送、sibling 选择/折叠同步、布局切换、失败重试、整组删除、
// 模型组合（combo）顺序执行、以及根据消息自身模型解析 CurrentModel。
// 与 _streamInto / _ensureTopic / _emitTurn 等私有成员强耦合，因此以
// part + mixin 的形式与 ChatController 同库拆分（mixin 里声明所依赖的
// 私有成员抽象签名，由 ChatController 本体提供实现）。

part of 'chat_controller.dart';

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

mixin _ChatMultiModel on _$ChatController {
  // --- 由 ChatController 本体提供的成员 ---

  set _truncatedMessageId(String? value);
  String get _assistantId;
  String? get _topicId;
  ChatRepository get _repo;

  Future<String> _ensureTopic();
  void _emitTurn(
    String turnTopicId,
    List<ChatMessageView> views, {
    required bool streaming,
  });
  Future<McpSetup> _mcpSetup();
  ({int contextCount, int? maxTokens}) _contextSettings();

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
  _parameterFields();

  Future<List<AssistantRegex>?> _sendingRegexRules();
  Future<List<LlmMessage>> _buildLlmMessages(
    Iterable<ChatMessageView> views, {
    required Model chatModel,
    List<AssistantRegex>? regexRules,
  });
  String _requestContent(
    ChatMessageView view, {
    List<AssistantRegex>? regexRules,
  });
  String? _systemFor(McpSetup mcp, String? base);
  Future<String?> _buildSystemPrompt({
    required String modelName,
    required String modelId,
    required String providerName,
  });
  Future<String?> _buildSystemPromptWith(
    String? memorySection, {
    required String modelName,
    required String modelId,
    required String providerName,
  });
  String? _joinInjectionSections(String? a, String? b);
  List<MessageBlock> _knowledgeReferenceBlocks({
    required String messageId,
    required DateTime createdAt,
    required ChatKnowledgeInjection injection,
  });
  List<MessageBlock> _memoryInjectionBlocks({
    required String messageId,
    required DateTime createdAt,
    required ChatMemoryInjection injection,
  });
  MessageBlock _attachmentBlock({
    required String messageId,
    required DateTime createdAt,
    required ComposerAttachment attachment,
  });

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
    List<MessageBlock> leadingBlocks,
    bool finalizeTurn,
  });

  Future<void> _refreshTopicPreview([String? forTopicId]);
  Future<void> _generateTitle([String? forTopicId]);
  Future<void> _maybeGenerateSuggestions(
    String turnTopicId,
    List<ChatMessageView> views,
  );
  Future<void> _maybeExtractMemory(String turnTopicId);

  Future<void> deleteMessage(String messageId, {bool cascade = false});
  Future<void> regenerate(String messageId);

  // --- 搬出的方法 ---

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
    final contextViews = ChatController._trimViews(baseViews, ctx.contextCount);
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
    final contextViews = ChatController._trimViews(views, ctx.contextCount);
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
}
