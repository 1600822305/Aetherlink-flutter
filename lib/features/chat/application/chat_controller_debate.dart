// AI 辩论相关的会话操作，从 chat_controller.dart 主体拆出的 part 文件：
// 角色发言（无话题历史的流式回合）、系统通告、用户插话、静默一次性生成。
// 与 _streamInto / _ensureTopic / _emitTurn 等私有成员强耦合，因此以
// part + mixin 的形式与 ChatController 同库拆分（mixin 里声明所依赖的
// 私有成员抽象签名，由 ChatController 本体提供实现）。

part of 'chat_controller.dart';

/// 从消息 metadata 里取辩论阶段标记（`metadata['debate']['phase']`）。
String? _debatePhaseOf(Map<String, dynamic>? metadata) {
  final debate = metadata?['debate'];
  if (debate is! Map) return null;
  return debate['phase']?.toString();
}

mixin _ChatDebate on _$ChatController {
  // --- 由 ChatController 本体提供的成员 ---
  set _truncatedMessageId(String? value);
  String get _assistantId;
  ChatRepository get _repo;
  Future<String> _ensureTopic();
  void _emitTurn(
    String turnTopicId,
    List<ChatMessageView> views, {
    required bool streaming,
  });
  Future<McpSetup> _mcpSetup();
  ({int contextCount, int? maxTokens}) _contextSettings();
  Future<void> _refreshTopicPreview([String? forTopicId]);
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
  });

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
}
