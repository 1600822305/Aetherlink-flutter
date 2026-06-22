import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
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
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'context_condense_service.g.dart';

/// Options for the context compression operation.
class CondenseOptions {
  const CondenseOptions({
    this.keepRecentMessages = 3,
    this.targetTokens = 2000,
    this.additionalPrompt = '',
  });

  /// Number of recent messages to keep uncompressed.
  final int keepRecentMessages;

  /// Target token count for the compressed summary.
  final int targetTokens;

  /// Extra user instructions appended to the compress prompt.
  final String additionalPrompt;
}

/// Result of a compression operation.
class CondenseResult {
  const CondenseResult({
    required this.success,
    this.error,
    this.originalMessageCount = 0,
    this.originalTokens = 0,
    this.compressedTokens = 0,
  });

  final bool success;
  final String? error;
  final int originalMessageCount;
  final int originalTokens;
  final int compressedTokens;

  int get tokensSaved => originalTokens - compressedTokens;
}

// ── Token estimation ────────────────────────────────────────────────────────

/// Estimates token count: Chinese chars ×1.5, other chars ÷4.
int estimateTokens(String content) {
  if (content.isEmpty) return 0;
  final chineseRegExp = RegExp(r'[\u4e00-\u9fa5]');
  int chineseCount = 0;
  for (final rune in content.runes) {
    if (chineseRegExp.hasMatch(String.fromCharCode(rune))) chineseCount++;
  }
  final otherCount = content.length - chineseCount;
  return (chineseCount * 1.5 + otherCount / 4).ceil();
}

// ── Service ─────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
ContextCondenseService contextCondenseService(Ref ref) =>
    ContextCondenseService(ref);

/// Orchestrates the context compression flow:
///   1. Gather messages for the current topic
///   2. Split into "to compress" + "to keep"
///   3. Build the prompt from the auxiliary compress template
///   4. Call the compress model (fallback: chat model → global default)
///   5. Create a summary message + ContextSummaryBlock
///   6. Delete compressed messages, persist the summary, refresh UI
class ContextCondenseService {
  ContextCondenseService(this._ref) {
    _ref.onDispose(() => _disposed = true);
  }

  final Ref _ref;
  bool _disposed = false;

  ChatRepository get _repo => _ref.read(chatRepositoryProvider);

  /// Returns `true` when there are enough messages in the current topic to
  /// compress (more than keepRecentMessages + 1).
  Future<bool> canCompress({int keepRecentMessages = 3}) async {
    final topic = await _ref.read(currentTopicProvider.future);
    if (topic == null) return false;
    final messages = await _repo.getMessagesByTopicId(topic.id);
    return messages.length > keepRecentMessages + 1;
  }

  /// Runs the compression. Returns a [CondenseResult].
  /// [onProgress] is called with status strings for UI feedback.
  Future<CondenseResult> compress({
    required CondenseOptions options,
    void Function(String status)? onProgress,
  }) async {
    try {
      return await _compressImpl(options: options, onProgress: onProgress);
    } on Object catch (e) {
      return CondenseResult(success: false, error: '压缩失败: $e');
    }
  }

  Future<CondenseResult> _compressImpl({
    required CondenseOptions options,
    void Function(String status)? onProgress,
  }) async {
    // 1. Resolve the current topic
    final topic = await _ref.read(currentTopicProvider.future);
    if (_disposed) {
      return const CondenseResult(success: false, error: '操作已取消');
    }
    final topicId = topic?.id;
    if (topicId == null) {
      return const CondenseResult(success: false, error: '没有活跃的对话');
    }

    // 1.5 Reject when a streaming reply is in progress.
    final chatState = _ref.read(chatControllerProvider);
    final isStreaming = chatState.value?.isStreaming ?? false;
    if (isStreaming) {
      return const CondenseResult(success: false, error: '请等待当前回复完成后再压缩');
    }

    onProgress?.call('正在收集消息…');

    // 2. Gather and sort messages
    final allMessages = await _repo.getMessagesByTopicId(topicId);
    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (allMessages.length <= options.keepRecentMessages + 1) {
      return const CondenseResult(success: false, error: '消息数量不足，无法压缩');
    }

    // 3. Split: compress older messages, keep recent N
    final messagesToCompress = allMessages.sublist(
      0,
      allMessages.length - options.keepRecentMessages,
    );
    // Build text representation
    final textParts = <String>[];
    int totalOriginalTokens = 0;
    for (final msg in messagesToCompress) {
      final blocks = await _repo.getMessageBlocksByMessageId(msg.id);
      final text = blocks
          .whereType<MainTextBlock>()
          .map((b) => b.content)
          .join('\n');
      if (text.trim().isEmpty) continue;
      final role = msg.role == MessageRole.user ? '用户' : 'AI';
      final truncated = text.length > 2000
          ? '${text.substring(0, 2000)}…'
          : text;
      textParts.add('$role: $truncated');
      totalOriginalTokens += estimateTokens(text);
    }

    if (textParts.isEmpty) {
      return const CondenseResult(success: false, error: '没有可压缩的文本内容');
    }
    if (_disposed) {
      return const CondenseResult(success: false, error: '操作已取消');
    }

    final conversationText = textParts.join('\n\n');

    onProgress?.call('正在压缩…');

    // 4. Resolve model
    final auxState = _ref.read(auxiliaryModelControllerProvider);
    final providers = await _ref.read(appModelProvidersProvider.future);
    final model = _resolveCompressModel(auxState, providers);
    if (model == null) {
      return const CondenseResult(
        success: false,
        error: '未找到可用的压缩模型，请在辅助模型设置中配置',
      );
    }

    // 5. Build prompt
    final additionalContext = options.additionalPrompt.trim().isNotEmpty
        ? '用户附加指令: ${options.additionalPrompt.trim()}'
        : '';
    final prompt = auxState.compressPrompt
        .replaceAll('{content}', conversationText)
        .replaceAll('{target_tokens}', options.targetTokens.toString())
        .replaceAll('{additional_context}', additionalContext);

    // 6. Call LLM
    final effective = effectiveModelFor(model);
    final request = LlmChatRequest(
      model: effective,
      messages: [LlmMessage(role: MessageRole.user, content: prompt)],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );
    if (_disposed) {
      return const CondenseResult(success: false, error: '操作已取消');
    }
    final gateway = _ref.read(llmGatewayFactoryProvider).forModel(effective);
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
    final summary = buffer.toString().trim();

    if (summary.isEmpty) {
      return CondenseResult(
        success: false,
        error: '压缩失败: 模型返回空结果',
        originalMessageCount: messagesToCompress.length,
        originalTokens: totalOriginalTokens,
      );
    }

    if (_disposed) {
      return const CondenseResult(success: false, error: '操作已取消');
    }

    onProgress?.call('正在保存…');

    // 7. Calculate stats
    final compressedTokens = estimateTokens(summary);

    // 8. Create summary message + block
    // 摘要的时间戳取被压缩的最后一条消息的时间，确保排在保留消息之前
    final summaryTime = messagesToCompress.last.createdAt;
    final summaryMessageId = generateId('msg');
    final summaryBlockId = generateId('block');

    final summaryBlock = MessageBlock.contextSummary(
      id: summaryBlockId,
      messageId: summaryMessageId,
      status: MessageBlockStatus.success,
      createdAt: summaryTime,
      content: summary,
      originalMessageCount: messagesToCompress.length,
      originalTokens: totalOriginalTokens,
      compressedTokens: compressedTokens,
      tokensSaved: totalOriginalTokens - compressedTokens,
      compressedAt: DateTime.now(),
      modelId: model.model.id,
    );

    final summaryMessage = Message(
      id: summaryMessageId,
      role: MessageRole.assistant,
      assistantId: allMessages.first.assistantId,
      topicId: topicId,
      createdAt: summaryTime,
      status: MessageStatus.success,
      blocks: [summaryBlockId],
      metadata: {'isSummary': true},
    );

    // 9. Persist atomically: delete compressed messages + their blocks, save
    // the summary — all inside a single transaction so a mid-way failure can't
    // leave the topic with deleted history but no summary.
    await _repo.runInTransaction(() async {
      for (final msg in messagesToCompress) {
        await _repo.deleteMessage(msg.id);
      }
      await _repo.saveMessageBlock(summaryBlock);
      await _repo.saveMessage(summaryMessage);
    });

    // 10. Reload the chat UI
    onProgress?.call('完成');
    if (!_disposed) {
      _ref.read(chatRefreshProvider.notifier).bump();
    }

    return CondenseResult(
      success: true,
      originalMessageCount: messagesToCompress.length,
      originalTokens: totalOriginalTokens,
      compressedTokens: compressedTokens,
    );
  }

  /// Compress model → chat model → global default.
  CurrentModel? _resolveCompressModel(
    AuxiliaryModelState auxState,
    List<ModelProvider> providers,
  ) {
    // Try compress model
    var resolved = resolveAuxiliaryModel(auxState.compressModelKey, providers);
    if (resolved != null) return resolved;
    // Try chat model
    resolved = resolveAuxiliaryModel(auxState.chatModelKey, providers);
    if (resolved != null) return resolved;
    // Try global default
    return findCurrentModel(providers);
  }
}
