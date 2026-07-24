// 图像/视频生成模式的发送链路，从 ChatController 的 part/mixin 服务化：
// 输入框的「图像生成 / 视频生成」互斥模式（InputMode.image / .video）激活时，
// send() 不再走 LLM 对话，而是走 MediaGenerationGateway 的供应商路由（web 版
// handleMessageSend → handleImageGeneration / handleVideoPrompt 的移植）。
// 依赖经 [ChatModeContext] 显式注入，不再靠 mixin 的 this 共享私有成员。

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/modes/chat_mode_context.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';

/// 图像/视频生成模式的发送链路（[ChatController] 的协作对象）。
class MediaGenerationSendService {
  const MediaGenerationSendService(this._ctx);

  final ChatModeContext _ctx;

  /// Runs an image / video generation turn for [mode] (a one-shot: the mode is
  /// cleared before the request, like the web's `clearMode()` after dispatch).
  ///
  /// 用户消息照常持久化；助手消息以一个 processing 的 IMAGE/VIDEO 块占位，生成
  /// 成功后就地填入 URL，失败则替换为 error 块 —— 与 web 版行为一致（web 的
  /// 视频链路在生成前也会校验模型是否支持视频生成）。
  Future<void> sendMediaGeneration(
    InputMode mode,
    String trimmed, {
    required List<ComposerAttachment> attachments,
    required ChatState snapshot,
  }) async {
    _ctx.ref.read(inputModeControllerProvider.notifier).clear();

    final current = await _ctx.ref.read(appCurrentModelProvider.future);
    if (current == null) return;
    final effective = effectiveModelFor(current);

    final topicId = await _ctx.ensureTopic();
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
      assistantId: _ctx.assistantId,
      topicId: topicId,
      createdAt: assistantTime,
      status: MessageStatus.streaming,
      model: effective,
      askId: userMessageId,
      blocks: <String>[mediaBlockId],
    );
    await _ctx.repo.saveMessage(assistantMessage);
    await _ctx.repo.saveMessageBlock(placeholderBlock);

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
    _ctx.emitTurn(topicId, views, streaming: true);

    // 3. Generate via the provider route, then finalize blocks in place.
    final api = _ctx.ref.read(mediaGenerationApiProvider);
    try {
      final List<MessageBlock> finalBlocks;
      if (mode == InputMode.video && !api.isVideoGenerationModel(effective)) {
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
      await _ctx.persistMessageBlocks(
        messageId: assistantMessageId,
        status: MessageStatus.success,
        blocks: finalBlocks,
      );
      assistantView = await _ctx.reloadView(assistantMessageId, assistantView);
      _ctx.replace(views, assistantView);
    } catch (error) {
      final messageText = error is StateError
          ? error.message
          : _ctx.errorMessage(error);
      await _ctx.persistMessageBlocks(
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
      _ctx.replace(views, assistantView);
    }
    _ctx.emitTurn(topicId, views, streaming: false);
  }
}
