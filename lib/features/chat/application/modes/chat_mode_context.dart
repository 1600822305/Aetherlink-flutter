import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/knowledge_access.dart';
import 'package:aetherlink_flutter/app/di/memory_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/send/llm_request_params.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/composer_attachment.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Signature of [TurnStreamBinder.streamInto] as exposed by the controller:
/// drives one assistant reply's gateway stream + MCP tool-call loop.
typedef StreamIntoFn =
    Future<void> Function({
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
      bool finalizeTurn,
    });

/// The explicit bundle of [ChatController] collaborators shared by the mode
/// send services (multi-model / debate / media generation / translate).
///
/// Every dependency the old `part`/mixin files reached through `this` is
/// injected here as a callback, making the coupling visible and keeping the
/// services testable without the controller. Accessors that resolve live
/// state ([ref], [repo], [assistantId], [topicId], [snapshot]) are functions
/// for the same reason the controller's own services take `() => ref`: a
/// long turn routinely spans provider rebuilds.
class ChatModeContext {
  const ChatModeContext(
    this._refOf, {
    required ChatRepository Function() repo,
    required String Function() assistantId,
    required String? Function() topicId,
    required ChatState? Function() snapshot,
    required this.clearTruncated,
    required this.ensureTopic,
    required this.emitTurn,
    required this.emit,
    required this.mcpSetup,
    required this.contextSettings,
    required this.parameterFields,
    required this.sendingRegexRules,
    required this.buildLlmMessages,
    required this.requestContent,
    required this.systemFor,
    required this.buildSystemPrompt,
    required this.buildSystemPromptWith,
    required this.joinInjectionSections,
    required this.knowledgeReferenceBlocks,
    required this.memoryInjectionBlocks,
    required this.attachmentBlock,
    required this.streamInto,
    required this.persistMessageBlocks,
    required this.reloadView,
    required this.reloadIntoState,
    required this.replace,
    required this.errorMessage,
    required this.orderBlocks,
    required this.trimViews,
    required this.filterSiblingsForContext,
    required this.refreshTopicPreview,
    required this.generateTitle,
    required this.maybeGenerateSuggestions,
    required this.maybeExtractMemory,
    required this.deleteMessage,
    required this.regenerate,
  }) : _repoOf = repo,
       _assistantIdOf = assistantId,
       _topicIdOf = topicId,
       _snapshotOf = snapshot;

  final Ref Function() _refOf;
  final ChatRepository Function() _repoOf;
  final String Function() _assistantIdOf;
  final String? Function() _topicIdOf;
  final ChatState? Function() _snapshotOf;

  Ref get ref => _refOf();
  ChatRepository get repo => _repoOf();
  String get assistantId => _assistantIdOf();
  String? get topicId => _topicIdOf();

  /// The controller's current `state.value` (null while first loading).
  ChatState? get snapshot => _snapshotOf();

  /// Clears the "继续生成" truncation marker before a new turn.
  final void Function() clearTruncated;

  final Future<String> Function() ensureTopic;
  final void Function(
    String turnTopicId,
    List<ChatMessageView> views, {
    required bool streaming,
  })
  emitTurn;
  final void Function(List<ChatMessageView> views, {required bool isStreaming})
  emit;

  final Future<McpSetup> Function() mcpSetup;
  final ({int contextCount, int? maxTokens}) Function() contextSettings;
  final LlmParameterFields Function() parameterFields;
  final Future<List<AssistantRegex>?> Function() sendingRegexRules;

  final Future<List<LlmMessage>> Function(
    Iterable<ChatMessageView> views, {
    required Model chatModel,
    List<AssistantRegex>? regexRules,
    required McpMode toolMode,
  })
  buildLlmMessages;
  final String Function(
    ChatMessageView view, {
    List<AssistantRegex>? regexRules,
  })
  requestContent;
  final String? Function(McpSetup mcp, String? base) systemFor;
  final Future<String?> Function({
    required String modelName,
    required String modelId,
    required String providerName,
  })
  buildSystemPrompt;
  final Future<String?> Function(
    String? memorySection, {
    required String modelName,
    required String modelId,
    required String providerName,
  })
  buildSystemPromptWith;
  final String? Function(String? a, String? b) joinInjectionSections;
  final List<MessageBlock> Function({
    required String messageId,
    required DateTime createdAt,
    required ChatKnowledgeInjection injection,
  })
  knowledgeReferenceBlocks;
  final List<MessageBlock> Function({
    required String messageId,
    required DateTime createdAt,
    required ChatMemoryInjection injection,
  })
  memoryInjectionBlocks;
  final MessageBlock Function({
    required String messageId,
    required DateTime createdAt,
    required ComposerAttachment attachment,
  })
  attachmentBlock;

  final StreamIntoFn streamInto;
  final Future<void> Function({
    required String messageId,
    required MessageStatus status,
    required List<MessageBlock> blocks,
  })
  persistMessageBlocks;
  final Future<ChatMessageView> Function(
    String messageId,
    ChatMessageView fallback,
  )
  reloadView;
  final Future<void> Function(String messageId) reloadIntoState;
  final void Function(List<ChatMessageView> views, ChatMessageView view)
  replace;
  final String Function(Object error) errorMessage;
  final List<MessageBlock> Function(
    List<String> order,
    List<MessageBlock> blocks,
  )
  orderBlocks;
  final List<ChatMessageView> Function(List<ChatMessageView> views, int count)
  trimViews;
  final List<ChatMessageView> Function(List<ChatMessageView> views)
  filterSiblingsForContext;

  final Future<void> Function(String turnTopicId) refreshTopicPreview;
  final Future<void> Function(String turnTopicId) generateTitle;
  final Future<void> Function(String turnTopicId, List<ChatMessageView> views)
  maybeGenerateSuggestions;
  final Future<void> Function(String turnTopicId) maybeExtractMemory;

  final Future<void> Function(String messageId, {bool cascade}) deleteMessage;
  final Future<void> Function(String messageId) regenerate;
}
