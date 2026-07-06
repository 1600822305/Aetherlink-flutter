// 图像/视频生成模式的发送链路，从 chat_controller.dart 主体拆出的 part 文件：
// 输入框的「图像生成 / 视频生成」互斥模式（InputMode.image / .video）激活时，
// send() 不再走 LLM 对话，而是走 MediaGenerationApi 的供应商路由（web 版
// handleMessageSend → handleImageGeneration / handleVideoPrompt 的移植）。
// 与 _ensureTopic / _emitTurn / _persistMessageBlocks 等私有成员强耦合，因此
// 以 part + mixin 的形式与 ChatController 同库拆分。

part of 'chat_controller.dart';

mixin _ChatMediaGeneration on _$ChatController {
  // --- 由 ChatController 本体提供的成员 ---

  String get _assistantId;
  ChatRepository get _repo;

  Future<String> _ensureTopic();
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
  });
  String _errorMessage(Object error);
  MessageBlock _attachmentBlock({
    required String messageId,
    required DateTime createdAt,
    required ComposerAttachment attachment,
  });

  // --- 搬出的方法 ---

  /// Runs an image / video generation turn for [mode] (a one-shot: the mode is
  /// cleared before the request, like the web's `clearMode()` after dispatch).
  ///
  /// 用户消息照常持久化；助手消息以一个 processing 的 IMAGE/VIDEO 块占位，生成
  /// 成功后就地填入 URL，失败则替换为 error 块 —— 与 web 版行为一致（web 的
  /// 视频链路在生成前也会校验模型是否支持视频生成）。
  Future<void> _sendMediaGeneration(
    InputMode mode,
    String trimmed, {
    required List<ComposerAttachment> attachments,
    required ChatState snapshot,
  }) async {
    ref.read(inputModeControllerProvider.notifier).clear();

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;
    final effective = effectiveModelFor(current);

    final topicId = await _ensureTopic();
    final now = DateTime.now();

    // 1. User message (text + attachment blocks), persisted like a normal send.
    final userMessageId = generateId('msg');
    final userBlocks = <MessageBlock>[
      if (trimmed.isNotEmpty)
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

    // 2. Assistant placeholder: a processing main_text block carrying the
    //    生成中 progress copy（web 版视频链路同款文案）——崩溃恢复会把它落定，
    //    正常完成时整组块被最终结果替换。
    final assistantTime = now.add(const Duration(microseconds: 1));
    final assistantMessageId = generateId('msg');
    final mediaBlockId = generateId('block');
    final progressText = mode == InputMode.image
        ? '正在生成图像，请稍候…'
        : '正在生成视频，请稍候…\n\n视频生成通常需要几分钟时间，请耐心等待。';
    final placeholderBlock = MessageBlock.mainText(
      id: mediaBlockId,
      messageId: assistantMessageId,
      status: MessageBlockStatus.processing,
      createdAt: assistantTime,
      content: progressText,
    );
    final assistantMessage = Message(
      id: assistantMessageId,
      role: MessageRole.assistant,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: assistantTime,
      status: MessageStatus.streaming,
      model: effective,
      askId: userMessageId,
      blocks: <String>[mediaBlockId],
    );
    await _repo.saveMessage(assistantMessage);
    await _repo.saveMessageBlock(placeholderBlock);

    final userView = ChatMessageView(
      id: userMessageId,
      role: MessageRole.user,
      status: MessageStatus.success,
      text: trimmed,
      blocks: userBlocks,
      createdAt: now,
    );
    var assistantView = ChatMessageView(
      id: assistantMessageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      text: progressText,
      createdAt: assistantTime,
      modelName: effective.name,
      providerName: current.provider.name,
      askId: userMessageId,
    );
    final views = [...snapshot.messages, userView, assistantView];
    _emitTurn(topicId, views, streaming: true);

    // 3. Generate via the provider route, then finalize blocks in place.
    final api = ref.read(mediaGenerationApiProvider);
    try {
      final List<MessageBlock> finalBlocks;
      if (mode == InputMode.video &&
          !MediaGenerationApi.isVideoGenerationModel(effective)) {
        throw StateError(
          '模型 ${effective.name} 不支持视频生成。'
          '请选择支持视频生成的模型，如 HunyuanVideo 或 Wan-AI 系列模型。',
        );
      }
      if (mode == InputMode.image) {
        final urls = await api.generateImages(
          model: effective,
          prompt: trimmed,
        );
        finalBlocks = <MessageBlock>[
          for (final url in urls)
            MessageBlock.image(
              id: generateId('block'),
              messageId: assistantMessageId,
              status: MessageBlockStatus.success,
              createdAt: assistantTime,
              updatedAt: DateTime.now(),
              url: url,
              mimeType: url.startsWith('data:image/jpeg')
                  ? 'image/jpeg'
                  : 'image/png',
            ),
        ];
      } else {
        final url = await api.generateVideo(model: effective, prompt: trimmed);
        finalBlocks = <MessageBlock>[
          MessageBlock.video(
            id: generateId('block'),
            messageId: assistantMessageId,
            status: MessageBlockStatus.success,
            createdAt: assistantTime,
            updatedAt: DateTime.now(),
            url: url,
            mimeType: 'video/mp4',
          ),
        ];
      }
      await _persistMessageBlocks(
        messageId: assistantMessageId,
        status: MessageStatus.success,
        blocks: finalBlocks,
      );
      assistantView = await _reloadView(assistantMessageId, assistantView);
      _replace(views, assistantView);
    } catch (error) {
      final messageText = error is StateError
          ? error.message
          : _errorMessage(error);
      await _persistMessageBlocks(
        messageId: assistantMessageId,
        status: MessageStatus.error,
        blocks: <MessageBlock>[
          MessageBlock.error(
            id: generateId('block'),
            messageId: assistantMessageId,
            status: MessageBlockStatus.error,
            createdAt: assistantTime,
            updatedAt: DateTime.now(),
            content: '',
            message: messageText,
          ),
        ],
      );
      assistantView = assistantView.copyWith(
        status: MessageStatus.error,
        errorText: messageText,
      );
      _replace(views, assistantView);
    }
    _emitTurn(topicId, views, streaming: false);
  }
}
