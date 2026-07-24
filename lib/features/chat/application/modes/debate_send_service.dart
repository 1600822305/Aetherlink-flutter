// AI 辩论相关的会话操作，从 ChatController 的 part/mixin 服务化：
// 角色发言（无话题历史的流式回合）、系统通告、用户插话、静默一次性生成。
// 依赖经 [ChatModeContext] 显式注入，不再靠 mixin 的 this 共享私有成员。

import 'dart:async';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_selection_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/modes/chat_mode_context.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';

/// 从消息 metadata 里取辩论阶段标记（`metadata['debate']['phase']`）。
String? debatePhaseOf(Map<String, dynamic>? metadata) {
  final debate = metadata?['debate'];
  if (debate is! Map) return null;
  return debate['phase']?.toString();
}

/// AI 辩论模式的发送链路（[ChatController] 的协作对象）。
class DebateSendService {
  const DebateSendService(this._ctx);

  final ChatModeContext _ctx;

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
    final snapshot = _ctx.snapshot ?? ChatState.initial();
    if (snapshot.isStreaming) return null;

    _ctx.clearTruncated();
    final topicId = await _ctx.ensureTopic();
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
      assistantId: _ctx.assistantId,
      topicId: topicId,
      createdAt: now,
      status: MessageStatus.streaming,
      model: effective,
      metadata: metadata,
      blocks: <String>[assistantBlockId],
    );
    await _ctx.repo.saveMessage(assistantMessage);
    await _ctx.repo.saveMessageBlock(
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
      debatePhase: debatePhaseOf(metadata),
    );
    final views = <ChatMessageView>[...snapshot.messages, assistantView];
    _ctx.emitTurn(topicId, views, streaming: true);

    final mcp = toolsEnabled
        ? await _ctx.mcpSetup()
        : const McpSetup.disabled();
    final ctx = _ctx.contextSettings();
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
    await _ctx.streamInto(
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

    final blocks = await _ctx.repo.getMessageBlocksByMessageId(
      assistantMessageId,
    );
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
    final topicId = await _ctx.ensureTopic();
    final now = DateTime.now();
    final messageId = generateId('msg');
    final blockId = generateId('block');
    await _ctx.repo.saveMessage(
      Message(
        id: messageId,
        role: MessageRole.assistant,
        assistantId: _ctx.assistantId,
        topicId: topicId,
        createdAt: now,
        status: MessageStatus.success,
        metadata: metadata,
        blocks: <String>[blockId],
      ),
    );
    await _ctx.repo.saveMessageBlock(
      MessageBlock.mainText(
        id: blockId,
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: now,
        content: content,
      ),
    );
    _ctx.ref.read(chatRefreshProvider.notifier).bump();
    unawaited(_ctx.refreshTopicPreview(topicId));
  }

  /// AI 辩论的用户插话：只落一条普通用户消息（带 debate 标记），
  /// 不触发任何模型回复——发言内容由辩论引擎注入后续上下文。
  Future<void> sendDebateInterjection(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final topicId = await _ctx.ensureTopic();
    final now = DateTime.now();
    final messageId = generateId('msg');
    final blockId = generateId('block');
    await _ctx.repo.saveMessage(
      Message(
        id: messageId,
        role: MessageRole.user,
        assistantId: _ctx.assistantId,
        topicId: topicId,
        createdAt: now,
        status: MessageStatus.success,
        metadata: const {
          'debate': {'phase': 'interjection'},
        },
        blocks: <String>[blockId],
      ),
    );
    await _ctx.repo.saveMessageBlock(
      MessageBlock.mainText(
        id: blockId,
        messageId: messageId,
        status: MessageBlockStatus.success,
        createdAt: now,
        content: trimmed,
      ),
    );
    _ctx.ref.read(chatRefreshProvider.notifier).bump();
    unawaited(_ctx.refreshTopicPreview(topicId));
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
      final gateway = _ctx.ref
          .read(llmGatewayFactoryProvider)
          .forModel(effective);
      final buffer = StringBuffer();
      await for (final chunk in gateway.streamChat(request)) {
        switch (chunk) {
          case LlmTextDelta(:final text):
            buffer.write(text);
          case LlmReasoningDelta():
          case LlmToolCallDelta():
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
