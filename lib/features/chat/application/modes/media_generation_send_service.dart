// 图像/视频生成模式的发送链路，从 ChatController 的 part/mixin 服务化：
// 输入框的「图像生成 / 视频生成」互斥模式（InputMode.image / .video）激活时，
// send() 不再走 LLM 对话，而是走 MediaGenerationGateway 的供应商路由（web 版
// handleMessageSend → handleImageGeneration / handleVideoPrompt 的移植）。
// 依赖经 [ChatModeContext] 显式注入，不再靠 mixin 的 this 共享私有成员。

import 'package:aetherlink_flutter/app/di/media_model_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/message_versioning.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/modes/chat_mode_context.dart';
import 'package:aetherlink_flutter/features/chat/application/send/chat_error_capture.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/chat_error.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';

/// 图像/视频生成模式的发送链路（[ChatController] 的协作对象）。
class MediaGenerationSendService {
  const MediaGenerationSendService(this._ctx);

  final ChatModeContext _ctx;

  /// Runs an image / video generation turn for [mode]. The armed input mode
  /// is intentionally kept after the turn — it behaves like the chat-model
  /// selection and stays active until the user toggles it off, picks a chat
  /// model in the selector, or restarts the app.
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
    // Media models live in their own slots (设置 → 辅助模型 → 媒体), never
    // the app-level chat model — Cherry Studio does the same (painting model
    // in ModelSettings, separate from the default chat model).
    final current = await _ctx.ref.read(
      mode == InputMode.image
          ? appMediaImageModelProvider.future
          : appMediaVideoModelProvider.future,
    );
    final effective = current == null ? null : effectiveModelFor(current);

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

    // 2. Assistant placeholder: a processing IMAGE/VIDEO block — rendered as
    //    a media-shaped skeleton card (shimmer + elapsed timer) instead of a
    //    static line of text, so the wait reads as generation progress.
    //    崩溃恢复会把它落定，正常完成时整组块被最终结果替换。
    final assistantTime = now.add(const Duration(microseconds: 1));
    final assistantMessageId = generateId('msg');
    final placeholderBlock = _mediaPlaceholder(
      mode,
      assistantMessageId,
      assistantTime,
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
      blocks: <String>[placeholderBlock.id],
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
    final assistantView = ChatMessageView(
      id: assistantMessageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      text: mode == InputMode.image ? '正在生成图像' : '正在生成视频',
      blocks: <MessageBlock>[placeholderBlock],
      createdAt: assistantTime,
      modelName: effective?.name,
      providerName: current?.provider.name,
      askId: userMessageId,
    );
    final views = [...snapshot.messages, userView, assistantView];
    _ctx.emitTurn(topicId, views, streaming: true);

    await _generateAndFinalize(
      mode,
      trimmed,
      topicId: topicId,
      assistantMessageId: assistantMessageId,
      assistantTime: assistantTime,
      views: views,
      assistantView: assistantView,
      effective: effective,
      current: current,
    );
  }

  /// Re-runs a media-generation turn in place for [target] — the counterpart
  /// of `ChatController.regenerate` for messages whose result is IMAGE/VIDEO
  /// blocks. Archives the current content as a version, resets the message to
  /// a fresh processing media placeholder, then generates again against the
  /// media slot (not the chat LLM). Shares its finalize tail with
  /// [sendMediaGeneration].
  Future<void> regenerateMediaGeneration(
    InputMode mode,
    String prompt, {
    required Message target,
    required int index,
    required List<ChatMessageView> views,
  }) async {
    final current = await _ctx.ref.read(
      mode == InputMode.image
          ? appMediaImageModelProvider.future
          : appMediaVideoModelProvider.future,
    );
    final effective = current == null ? null : effectiveModelFor(current);
    final now = DateTime.now();

    final prepared = await MessageVersioning(
      _ctx.repo,
    ).prepareForRegenerate(target, now);
    final oldBlocks = await _ctx.repo.getMessageBlocksByMessageId(target.id);
    for (final block in oldBlocks) {
      await _ctx.repo.deleteMessageBlock(block.id);
    }
    final placeholder = _mediaPlaceholder(mode, target.id, now);
    await _ctx.repo.saveMessageBlock(placeholder);
    await _ctx.repo.saveMessage(
      prepared.copyWith(
        status: MessageStatus.streaming,
        updatedAt: now,
        model: effective,
        blocks: <String>[placeholder.id],
        currentVersionId: null,
      ),
    );

    final assistantView = ChatMessageView(
      id: target.id,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
      blocks: <MessageBlock>[placeholder],
      createdAt: target.createdAt,
      modelName: effective?.name,
      providerName: current?.provider.name,
      askId: target.askId,
      siblingsGroupId: target.siblingsGroupId,
      multiModelMessageStyle: target.multiModelMessageStyle,
      foldSelected: target.foldSelected ?? false,
    );
    views[index] = assistantView;
    _ctx.emitTurn(target.topicId, views, streaming: true);

    await _generateAndFinalize(
      mode,
      prompt,
      topicId: target.topicId,
      assistantMessageId: target.id,
      assistantTime: now,
      views: views,
      assistantView: assistantView,
      effective: effective,
      current: current,
    );
  }

  /// The `processing` IMAGE/VIDEO placeholder rendered as the generating
  /// skeleton while the provider call is in flight.
  MessageBlock _mediaPlaceholder(
    InputMode mode,
    String assistantMessageId,
    DateTime createdAt,
  ) {
    return mode == InputMode.image
        ? MessageBlock.image(
            id: generateId('block'),
            messageId: assistantMessageId,
            status: MessageBlockStatus.processing,
            createdAt: createdAt,
            url: '',
            mimeType: 'image/png',
          )
        : MessageBlock.video(
            id: generateId('block'),
            messageId: assistantMessageId,
            status: MessageBlockStatus.processing,
            createdAt: createdAt,
            url: '',
            mimeType: 'video/mp4',
          );
  }

  /// The shared generate-then-finalize tail of [sendMediaGeneration] and
  /// [regenerateMediaGeneration]: provider call, then persist IMAGE/VIDEO or
  /// error blocks in place and update the view.
  Future<void> _generateAndFinalize(
    InputMode mode,
    String prompt, {
    required String topicId,
    required String assistantMessageId,
    required DateTime assistantTime,
    required List<ChatMessageView> views,
    required ChatMessageView assistantView,
    required Model? effective,
    required CurrentModel? current,
  }) async {
    final api = _ctx.ref.read(mediaGenerationApiProvider);
    try {
      final List<MessageBlock> finalBlocks;
      if (effective == null) {
        throw StateError(
          mode == InputMode.image
              ? '未配置图像生成模型。请到 设置 → 辅助模型 → 媒体 选择支持图像生成的模型。'
              : '未配置视频生成模型。请到 设置 → 辅助模型 → 媒体 选择支持视频生成的模型。',
        );
      }
      if (mode == InputMode.image && !isGenerateImageModel(effective)) {
        throw StateError(
          '模型 ${effective.name} 不支持图像生成。'
          '请在 设置 → 辅助模型 → 媒体 中选择支持图像生成的模型。',
        );
      }
      if (mode == InputMode.video && !api.isVideoGenerationModel(effective)) {
        throw StateError(
          '模型 ${effective.name} 不支持视频生成。'
          '请选择支持视频生成的模型，如 HunyuanVideo 或 Wan-AI 系列模型。',
        );
      }
      if (mode == InputMode.image) {
        final urls = await api.generateImages(model: effective, prompt: prompt);
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
        final url = await api.generateVideo(model: effective, prompt: prompt);
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
    } on Object catch (error, stackTrace) {
      final chatError = _ctx.ref
          .read(chatErrorCaptureProvider)
          .capture(
            error,
            stackTrace,
            phase: ChatErrorPhase.media,
            provider: current?.provider,
            model: effective,
          );
      final messageText = error is StateError
          ? error.message
          : chatError.message;
      final errorBlocks = <MessageBlock>[
        MessageBlock.error(
          id: generateId('block'),
          messageId: assistantMessageId,
          status: MessageBlockStatus.error,
          createdAt: assistantTime,
          updatedAt: DateTime.now(),
          content: '',
          message: messageText,
          error: chatError.toJson(),
        ),
      ];
      await _ctx.persistMessageBlocks(
        messageId: assistantMessageId,
        status: MessageStatus.error,
        blocks: errorBlocks,
      );
      // The view must drop the processing placeholder too — otherwise the
      // generating skeleton keeps animating next to the error state.
      assistantView = assistantView.copyWith(
        status: MessageStatus.error,
        errorText: messageText,
        blocks: errorBlocks,
      );
      _ctx.replace(views, assistantView);
    }
    _ctx.emitTurn(topicId, views, streaming: false);
  }
}
