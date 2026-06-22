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
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'context_condense_service.g.dart';

// ── Options & Result ────────────────────────────────────────────────────────

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

// ── Cancel Token ────────────────────────────────────────────────────────────

/// Lightweight cancellation primitive. The dialog holds this and calls
/// [cancel] if the user dismisses mid-operation; the service checks
/// [isCancelled] after each async gap.
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
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

// ── Provider (thin entry point) ─────────────────────────────────────────────

/// The provider is a thin shell that resolves all Ref-dependent values
/// *synchronously* and delegates to the stateless [ContextCondenseService].
/// Because the service itself never touches Ref, it is immune to provider
/// disposal during long-running async work.
@Riverpod(keepAlive: true)
ContextCondenseService contextCondenseService(Ref ref) {
  return ContextCondenseService(
    repo: ref.read(chatRepositoryProvider),
    readCurrentTopic: () => ref.read(currentTopicProvider.future),
    readIsStreaming: () =>
        ref.read(chatControllerProvider).value?.isStreaming ?? false,
    readAuxState: () => ref.read(auxiliaryModelControllerProvider),
    readProviders: () => ref.read(appModelProvidersProvider.future),
    buildGateway: (model) =>
        ref.read(llmGatewayFactoryProvider).forModel(model),
    refreshChat: () => ref.read(chatRefreshProvider.notifier).bump(),
  );
}

// ── Service (stateless, no Ref) ─────────────────────────────────────────────

/// Orchestrates the context compression flow:
///   1. Gather messages for the current topic
///   2. Split into "to compress" + "to keep"
///   3. Build the prompt from the auxiliary compress template
///   4. Call the compress model via streaming
///   5. Create a summary message + ContextSummaryBlock
///   6. Delete compressed messages, persist the summary, refresh UI
///
/// Design: no [Ref] is stored. All external dependencies are injected as
/// closures so they are captured once at provider creation time. The long
/// async work only uses the repository (whose lifetime is tied to the app
/// database, not a widget) and the LLM gateway (a stateless factory product).
class ContextCondenseService {
  ContextCondenseService({
    required ChatRepository repo,
    required this.readCurrentTopic,
    required this.readIsStreaming,
    required this.readAuxState,
    required this.readProviders,
    required this.buildGateway,
    required this.refreshChat,
  }) : _repo = repo;

  final ChatRepository _repo;

  // Closures that read live state — called only at the *start* of compress,
  // before any long-running work. They may throw if the container is disposed,
  // which is caught by the outer try/catch.
  final Future<Topic?> Function() readCurrentTopic;
  final bool Function() readIsStreaming;
  final AuxiliaryModelState Function() readAuxState;
  final Future<List<ModelProvider>> Function() readProviders;
  final LlmGateway Function(Model model) buildGateway;
  final void Function() refreshChat;

  /// Returns `true` when there are enough messages in the current topic to
  /// compress (more than keepRecentMessages + 1).
  Future<bool> canCompress({int keepRecentMessages = 3}) async {
    final topic = await readCurrentTopic();
    if (topic == null) return false;
    final messages = await _repo.getMessagesByTopicId(topic.id);
    return messages.length > keepRecentMessages + 1;
  }

  /// Runs the compression. Returns a [CondenseResult].
  /// [onProgress] is called with status strings for UI feedback.
  /// [cancelToken] allows the caller to cancel mid-operation.
  Future<CondenseResult> compress({
    required CondenseOptions options,
    void Function(String status)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _compressImpl(
        options: options,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on Object catch (e) {
      return CondenseResult(success: false, error: '压缩失败: $e');
    }
  }

  Future<CondenseResult> _compressImpl({
    required CondenseOptions options,
    void Function(String status)? onProgress,
    CancelToken? cancelToken,
  }) async {
    // ── 1. Pre-flight checks (fast, use closures) ──

    // 1a. Reject when streaming
    if (readIsStreaming()) {
      return const CondenseResult(
        success: false,
        error: '请等待当前回复完成后再压缩',
      );
    }

    // 1b. Resolve current topic
    final topic = await readCurrentTopic();
    final topicId = topic?.id;
    if (topicId == null) {
      return const CondenseResult(success: false, error: '没有活跃的对话');
    }
    if (cancelToken?.isCancelled ?? false) {
      return const CondenseResult(success: false, error: '操作已取消');
    }

    // 1c. Resolve model (before any heavy I/O)
    final auxState = readAuxState();
    final providers = await readProviders();
    final model = _resolveCompressModel(auxState, providers);
    if (model == null) {
      return const CondenseResult(
        success: false,
        error: '未找到可用的压缩模型，请在辅助模型设置中配置',
      );
    }
    if (cancelToken?.isCancelled ?? false) {
      return const CondenseResult(success: false, error: '操作已取消');
    }

    // ── 2. Gather messages ──

    onProgress?.call('正在收集消息…');

    final allMessages = await _repo.getMessagesByTopicId(topicId);
    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (allMessages.length <= options.keepRecentMessages + 1) {
      return const CondenseResult(
        success: false,
        error: '消息数量不足，无法压缩',
      );
    }

    // Check if recent messages already contain a summary
    final recentMessages = allMessages.sublist(
      allMessages.length - options.keepRecentMessages,
    );
    final recentHasSummary = recentMessages.any(
      (m) => (m.metadata?['isSummary'] as bool?) == true,
    );
    if (recentHasSummary) {
      return const CondenseResult(
        success: false,
        error: '最近已经压缩过，请稍后再试',
      );
    }

    // ── 3. Split: compress older messages, keep recent N ──

    final messagesToCompress = allMessages.sublist(
      0,
      allMessages.length - options.keepRecentMessages,
    );

    final textParts = <String>[];
    int totalOriginalTokens = 0;
    for (final msg in messagesToCompress) {
      if (cancelToken?.isCancelled ?? false) {
        return const CondenseResult(success: false, error: '操作已取消');
      }
      final blocks = await _repo.getMessageBlocksByMessageId(msg.id);
      final text =
          blocks.whereType<MainTextBlock>().map((b) => b.content).join('\n');
      if (text.trim().isEmpty) continue;
      final role = msg.role == MessageRole.user ? '用户' : 'AI';
      final truncated =
          text.length > 2000 ? '${text.substring(0, 2000)}…' : text;
      textParts.add('$role: $truncated');
      totalOriginalTokens += estimateTokens(text);
    }

    if (textParts.isEmpty) {
      return const CondenseResult(
        success: false,
        error: '没有可压缩的文本内容',
      );
    }
    if (cancelToken?.isCancelled ?? false) {
      return const CondenseResult(success: false, error: '操作已取消');
    }

    // ── 4. Call LLM ──

    onProgress?.call('正在压缩…');

    final conversationText = textParts.join('\n\n');
    final additionalContext = options.additionalPrompt.trim().isNotEmpty
        ? '用户附加指令: ${options.additionalPrompt.trim()}'
        : '';
    final prompt = auxState.compressPrompt
        .replaceAll('{content}', conversationText)
        .replaceAll('{target_tokens}', options.targetTokens.toString())
        .replaceAll('{additional_context}', additionalContext);

    final effective = effectiveModelFor(model);
    final request = LlmChatRequest(
      model: effective,
      messages: [LlmMessage(role: MessageRole.user, content: prompt)],
      extraHeaders: effective.providerExtraHeaders,
      extraBody: effective.providerExtraBody,
    );
    final gateway = buildGateway(effective);
    final buffer = StringBuffer();

    await for (final chunk in gateway.streamChat(request)) {
      if (cancelToken?.isCancelled ?? false) {
        return const CondenseResult(success: false, error: '操作已取消');
      }
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
    if (cancelToken?.isCancelled ?? false) {
      return const CondenseResult(success: false, error: '操作已取消');
    }

    // ── 5. Persist ──

    onProgress?.call('正在保存…');

    final compressedTokens = estimateTokens(summary);
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

    // Atomic transaction: delete old messages + save summary
    await _repo.runInTransaction(() async {
      for (final msg in messagesToCompress) {
        await _repo.deleteMessage(msg.id);
      }
      await _repo.saveMessageBlock(summaryBlock);
      await _repo.saveMessage(summaryMessage);
    });

    // ── 6. Refresh UI ──

    onProgress?.call('完成');
    try {
      refreshChat();
    } on Object catch (_) {
      // If the provider container is gone by now, the UI will refresh on its
      // own when the user navigates back. Swallow silently.
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
    var resolved = resolveAuxiliaryModel(auxState.compressModelKey, providers);
    if (resolved != null) return resolved;
    resolved = resolveAuxiliaryModel(auxState.chatModelKey, providers);
    if (resolved != null) return resolved;
    return findCurrentModel(providers);
  }
}
