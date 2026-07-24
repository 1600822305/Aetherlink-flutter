// 消息翻译相关的会话操作，从 ChatController 的 part/mixin 服务化：
// 消息翻译（流式 TranslationBlock）、翻译块增量更新、翻译块持久化。
// 依赖经 [ChatModeContext] 显式注入，不再靠 mixin 的 this 共享私有成员。

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_versioning.dart';
import 'package:aetherlink_flutter/features/chat/application/modes/chat_mode_context.dart';
import 'package:aetherlink_flutter/features/chat/application/translate/translate_controller.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/translate/translate_language.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';

/// 消息翻译的发送链路（[ChatController] 的协作对象）。
class TranslateSendService {
  const TranslateSendService(this._ctx);

  final ChatModeContext _ctx;

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
    final snapshot = _ctx.snapshot;
    if (snapshot == null || snapshot.isStreaming) return;
    final message = await _ctx.repo.getMessage(messageId);
    if (message == null) return;
    final fetched = await _ctx.repo.getMessageBlocksByMessageId(messageId);
    final content = mainTextOf(
      _ctx.orderBlocks(message.blocks, fetched),
    ).trim();
    if (content.isEmpty) return;

    final current = await _ctx.ref.read(translateModelProvider.future);
    if (current == null) return;
    final effective = effectiveModelFor(current);

    final now = DateTime.now();
    final translationBlockId = generateId('block');
    await _ctx.repo.saveMessageBlock(
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
    await _ctx.repo.saveMessage(
      message.copyWith(
        blocks: [...message.blocks, translationBlockId],
        updatedAt: now,
      ),
    );
    await _ctx.reloadIntoState(messageId);

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

    final gateway = _ctx.ref
        .read(llmGatewayFactoryProvider)
        .forModel(effective);
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
      await _ctx.reloadIntoState(messageId);
      await _ctx.ref
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
        '翻译失败：${_ctx.errorMessage(error)}',
        MessageBlockStatus.error,
      );
      await _ctx.reloadIntoState(messageId);
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
    final snapshot = _ctx.snapshot;
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
    _ctx.emit(views, isStreaming: snapshot.isStreaming);
  }

  Future<void> _persistTranslationBlock(
    String blockId,
    String content,
    MessageBlockStatus status,
  ) async {
    final existing = await _ctx.repo.getMessageBlock(blockId);
    if (existing is TranslationBlock) {
      await _ctx.repo.saveMessageBlock(
        existing.copyWith(
          content: content,
          status: status,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }
}
