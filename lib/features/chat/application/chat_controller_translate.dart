// 消息翻译相关的会话操作，从 chat_controller.dart 主体拆出的 part 文件：
// 消息翻译（流式 TranslationBlock）、翻译块增量更新、翻译块持久化。
// 以 part + mixin 的形式与 ChatController 同库拆分（mixin 里声明所依赖的
// 私有成员抽象签名，由 ChatController 本体提供实现）。

part of 'chat_controller.dart';

mixin _ChatTranslate on _$ChatController {
  // --- 由 ChatController 本体提供的成员 ---

  ChatRepository get _repo;
  Future<void> _reloadIntoState(String messageId);
  List<MessageBlock> _orderBlocks(
    List<String> order,
    List<MessageBlock> blocks,
  );
  void _emit(List<ChatMessageView> views, {required bool isStreaming});
  String _errorMessage(Object error);

  // --- 搬出的方法 ---

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
          case LlmToolCallDelta():
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
}
