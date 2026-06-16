import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/error/failure.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'chat_controller.g.dart';

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

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  Future<ChatState> build() async {
    final topic = await ref.watch(currentTopicProvider.future);
    if (topic == null) {
      _topicId = null;
      return ChatState.initial();
    }
    _topicId = topic.id;
    _assistantId = topic.assistantId;

    final messages = await _repo.getMessagesByTopicId(topic.id)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final views = <ChatMessageView>[];
    for (final message in messages) {
      views.add(await _viewOf(message));
    }
    return ChatState(messages: views);
  }

  /// Sends [text] as a user message and streams the assistant reply. A
  /// blank message, a missing current model, or an in-flight stream are no-ops
  /// (the composer also disables the button in those cases).
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final snapshot = state.value ?? ChatState.initial();
    if (snapshot.isStreaming) return;

    final current = await ref.read(appCurrentModelProvider.future);
    if (current == null) return;

    final topicId = await _ensureTopic();
    final now = DateTime.now();

    // 1. User message + main_text block, persisted.
    final userMessageId = generateId('msg');
    final userBlockId = generateId('block');
    final userMessage = Message(
      id: userMessageId,
      role: MessageRole.user,
      assistantId: _assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.success,
      blocks: <String>[userBlockId],
    );
    await _repo.saveMessage(userMessage);
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: userBlockId,
        messageId: userMessageId,
        status: MessageBlockStatus.success,
        createdAt: now,
        content: trimmed,
      ),
    );

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
    );
    var assistantView = ChatMessageView(
      id: assistantMessageId,
      role: MessageRole.assistant,
      status: MessageStatus.streaming,
    );
    final views = [...snapshot.messages, userView, assistantView];
    _emit(views, isStreaming: true);

    // 3. Build the request from the current model + history (the user turn we
    // just added included; the empty assistant placeholder excluded).
    final request = LlmChatRequest(
      model: effective,
      messages: [
        for (final view in views)
          if (view.role != MessageRole.assistant || view.text.isNotEmpty)
            LlmMessage(role: view.role, content: view.text),
      ],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );

    final gateway = ref.read(llmGatewayFactoryProvider).forModel(effective);

    final buffer = StringBuffer();
    final thinking = StringBuffer();

    void update() {
      assistantView = assistantView.copyWith(
        text: buffer.toString(),
        thinking: thinking.toString(),
      );
      _replace(views, assistantView);
      _emit(views, isStreaming: true);
    }

    try {
      await for (final chunk in gateway.streamChat(request)) {
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
            update();
          case LlmReasoningDelta(:final text):
            thinking.write(text);
            update();
          case LlmDone():
            break;
        }
      }
      await _finalizeSuccess(
        messageId: assistantMessageId,
        mainBlockId: assistantBlockId,
        createdAt: assistantTime,
        text: buffer.toString(),
        thinking: thinking.toString(),
      );
      assistantView = assistantView.copyWith(status: MessageStatus.success);
      _replace(views, assistantView);
      _emit(views, isStreaming: false);
    } on Object catch (error) {
      final messageText = _errorMessage(error);
      await _finalizeError(
        messageId: assistantMessageId,
        createdAt: assistantTime,
        text: buffer.toString(),
        errorText: messageText,
      );
      assistantView = assistantView.copyWith(
        status: MessageStatus.error,
        errorText: messageText,
      );
      _replace(views, assistantView);
      _emit(views, isStreaming: false);
    }
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

  Future<void> _finalizeSuccess({
    required String messageId,
    required String mainBlockId,
    required DateTime createdAt,
    required String text,
    required String thinking,
  }) async {
    final now = DateTime.now();
    final blockIds = <String>[];
    if (thinking.isNotEmpty) {
      final thinkingBlockId = generateId('block');
      blockIds.add(thinkingBlockId);
      await _repo.saveMessageBlock(
        MessageBlock.thinking(
          id: thinkingBlockId,
          messageId: messageId,
          status: MessageBlockStatus.success,
          createdAt: createdAt,
          updatedAt: now,
          content: thinking,
        ),
      );
    }
    blockIds.add(mainBlockId);
    await _repo.saveMessageBlock(
      MessageBlock.mainText(
        id: mainBlockId,
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: createdAt,
        updatedAt: now,
        content: text,
      ),
    );
    final message = await _repo.getMessage(messageId);
    if (message != null) {
      await _repo.saveMessage(
        message.copyWith(
          status: MessageStatus.success,
          updatedAt: now,
          blocks: blockIds,
        ),
      );
    }
  }

  Future<void> _finalizeError({
    required String messageId,
    required DateTime createdAt,
    required String text,
    required String errorText,
  }) async {
    final now = DateTime.now();
    final errorBlockId = generateId('block');
    await _repo.saveMessageBlock(
      MessageBlock.error(
        id: errorBlockId,
        messageId: messageId,
        status: MessageBlockStatus.error,
        createdAt: createdAt,
        updatedAt: now,
        content: text,
        message: errorText,
      ),
    );
    final message = await _repo.getMessage(messageId);
    if (message != null) {
      await _repo.saveMessage(
        message.copyWith(
          status: MessageStatus.error,
          updatedAt: now,
          blocks: <String>[errorBlockId],
        ),
      );
    }
  }

  Future<ChatMessageView> _viewOf(Message message) async {
    final blocks = await _repo.getMessageBlocksByMessageId(message.id);
    final text = blocks
        .whereType<MainTextBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final thinking = blocks
        .whereType<ThinkingBlock>()
        .map((block) => block.content)
        .join('\n\n');
    final errors = blocks.whereType<ErrorBlock>();
    final error = errors.isEmpty ? null : errors.first;
    return ChatMessageView(
      id: message.id,
      role: message.role,
      status: message.status,
      text: text,
      thinking: thinking,
      errorText: error?.message ?? error?.content,
    );
  }

  void _emit(List<ChatMessageView> views, {required bool isStreaming}) {
    state = AsyncData(
      ChatState(
        messages: List<ChatMessageView>.of(views),
        isStreaming: isStreaming,
      ),
    );
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
