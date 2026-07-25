import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_state.dart';
import 'package:aetherlink_flutter/features/chat/application/mcp_tools_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/composer/ocr_service.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_content_image.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_tool_call.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/settings/application/auxiliary_model_controller.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/mcp_prompt.dart';
import 'package:aetherlink_flutter/shared/utils/regex_replacement.dart';

/// Tool-block metadata keys stamped by the streaming loop and read back when
/// re-serialising persisted tool rounds into LLM history.
const String kToolModeMetadataKey = 'mcpMode';
const String kToolRoundMetadataKey = 'toolRoundId';

/// Trims [views] to the last [count] entries so only recent history is sent
/// to the model. When [count] covers all views the list is returned as-is.
List<ChatMessageView> trimViewsForContext(
  List<ChatMessageView> views,
  int count,
) {
  if (views.length <= count) return views;
  return views.sublist(views.length - count);
}

/// Multi-model 对比 context hygiene: the displayed list inlines every
/// sibling of a group, but the conversation continues from the `foldSelected`
/// one — so LLM history keeps only that sibling per group. Siblings of
/// [excludeGroupId] (the group being regenerated) are dropped entirely, so
/// each model answers the shared conversation independently instead of
/// seeing its siblings' answers to the same question.
/// Groups without a `foldSelected` member (pre-flag data) keep their last
/// sibling instead, so the turn never silently vanishes from the context.
List<ChatMessageView> filterSiblingsForContext(
  List<ChatMessageView> views, {
  int? excludeGroupId,
}) {
  final keptOfGroup = <int, ChatMessageView>{};
  for (final view in views) {
    final group = view.siblingsGroupId;
    if (group == 0 || group == excludeGroupId) continue;
    final kept = keptOfGroup[group];
    if (kept == null || !kept.foldSelected) keptOfGroup[group] = view;
  }
  return [
    for (final view in views)
      if (view.siblingsGroupId == 0 ||
          identical(keptOfGroup[view.siblingsGroupId], view))
        view,
  ];
}

/// Serialises rendered conversation views into the [LlmMessage] history for a
/// request: tool rounds are re-woven per their persisted 调用方式 (native
/// function-call vs 提示词注入), FILE blocks are decoded into text, 发送期
/// 正则规则 are applied, and the OCR fallback textualises images for
/// non-vision chat models. Owned by the chat controller; the [Ref] is a getter
/// callback because the controller's Ref is replaced on every provider rebuild.
class LlmHistoryBuilder {
  const LlmHistoryBuilder(this._refOf);

  final Ref Function() _refOf;

  Ref get _ref => _refOf();

  /// Builds the [LlmMessage] list for [views], applying the OCR fallback when
  /// [chatModel] cannot see images: for each image-bearing turn the images are
  /// recognized by the configured OCR (vision) model and the resulting text is
  /// prepended to the turn's content (and the images dropped), so a non-vision
  /// chat model still receives the image content as text. When no OCR fallback
  /// applies the messages are built exactly as before (images sent inline).
  ///
  /// [dropEmptyAssistant] mirrors the existing
  /// `role != assistant || text.isNotEmpty` filter; pass `false` for paths that
  /// build raw history (e.g. continue-generating) and append their own turns.
  Future<List<LlmMessage>> buildLlmMessages(
    Iterable<ChatMessageView> views, {
    required Model chatModel,
    List<AssistantRegex>? regexRules,
    bool dropEmptyAssistant = true,
    required McpMode toolMode,
  }) async {
    final ocr = await resolveOcrFallback(chatModel);
    final messages = <LlmMessage>[];
    for (final view in views) {
      final hasToolBlocks = view.blocks.any((block) => block is ToolBlock);
      if (dropEmptyAssistant &&
          view.role == MessageRole.assistant &&
          view.text.isEmpty &&
          !hasToolBlocks) {
        continue;
      }
      if (view.role == MessageRole.assistant && hasToolBlocks) {
        messages.addAll(
          toolHistoryMessages(
            view,
            fallbackMode: toolMode,
            regexRules: regexRules,
          ),
        );
        continue;
      }
      var content = requestContent(view, regexRules: regexRules);
      var images = requestImages(view);
      if (ocr != null && images != null && images.isNotEmpty) {
        final ocrText = await _ref
            .read(ocrServiceProvider)
            .recognizeImages(
              images: images,
              ocrModel: ocr.model,
              prompt: ocr.prompt,
            );
        if (ocrText != null && ocrText.isNotEmpty) {
          content = content.isEmpty ? ocrText : '$ocrText\n\n$content';
          images = null;
        }
      }
      messages.add(
        LlmMessage(role: view.role, content: content, images: images),
      );
    }
    return messages;
  }

  List<LlmMessage> toolHistoryMessages(
    ChatMessageView view, {
    required McpMode fallbackMode,
    List<AssistantRegex>? regexRules,
  }) {
    final messages = <LlmMessage>[];
    final pendingText = <String>[];
    final blocks = view.blocks;
    var index = 0;

    void flushText() {
      final content = applySendingRegex(
        pendingText.join('\n\n'),
        view.role,
        regexRules,
      );
      pendingText.clear();
      if (content.isNotEmpty) {
        messages.add(LlmMessage(role: view.role, content: content));
      }
    }

    while (index < blocks.length) {
      final block = blocks[index];
      if (block is MainTextBlock) {
        if (block.content.isNotEmpty) pendingText.add(block.content);
        index++;
        continue;
      }
      if (block is! ToolBlock) {
        index++;
        continue;
      }

      final roundId = block.metadata?[kToolRoundMetadataKey]?.toString();
      final round = <ToolBlock>[block];
      index++;
      while (index < blocks.length && blocks[index] is ToolBlock) {
        final next = blocks[index] as ToolBlock;
        final nextRoundId = next.metadata?[kToolRoundMetadataKey]?.toString();
        if (roundId != null ? nextRoundId != roundId : nextRoundId != null) {
          break;
        }
        round.add(next);
        index++;
      }

      final prose = applySendingRegex(
        pendingText.join('\n\n'),
        view.role,
        regexRules,
      );
      pendingText.clear();
      final mode = McpMode.fromStorage(
        block.metadata?[kToolModeMetadataKey]?.toString(),
      );
      final effectiveMode = block.metadata?[kToolModeMetadataKey] == null
          ? fallbackMode
          : mode;

      if (effectiveMode == McpMode.prompt) {
        messages.add(
          LlmMessage(
            role: MessageRole.assistant,
            content: <String>[
              if (prose.isNotEmpty) prose,
              for (final tool in round) promptToolCall(tool),
            ].join('\n\n'),
          ),
        );
        for (final tool in round) {
          messages.add(
            LlmMessage(
              role: MessageRole.user,
              content: formatToolUseResult(
                tool.toolName ?? tool.toolId,
                toolResultText(tool.content),
              ),
            ),
          );
        }
      } else {
        messages.add(
          LlmMessage(
            role: MessageRole.assistant,
            content: prose,
            toolCalls: [
              for (final tool in round)
                LlmToolCall(
                  id: tool.toolId,
                  name: tool.toolName ?? tool.toolId,
                  arguments: jsonEncode(tool.arguments ?? const {}),
                ),
            ],
          ),
        );
        for (final tool in round) {
          messages.add(
            LlmMessage(
              role: MessageRole.user,
              content: toolResultText(tool.content),
              toolCallId: tool.toolId,
              toolName: tool.toolName ?? tool.toolId,
            ),
          );
        }
      }
    }

    flushText();
    return messages;
  }

  String promptToolCall(ToolBlock block) {
    final name = block.toolName ?? block.toolId;
    final arguments = jsonEncode(block.arguments ?? const {});
    return '<tool_use>\n<name>$name</name>\n<arguments>$arguments</arguments>\n'
        '</tool_use>';
  }

  String toolResultText(Object? content) {
    if (content == null) return '';
    if (content is String) return content;
    return jsonEncode(content);
  }

  /// Resolves the OCR fallback for [chatModel]: returns the configured OCR
  /// (vision) model + prompt only when [chatModel] itself lacks vision support
  /// and a usable 辅助模型 → OCR model is configured. Vision support is read
  /// from the model's detected capabilities (registry/inference) or an explicit
  /// `ModelType.vision` selection (see `isVisionModel`).
  /// Returns `null` otherwise, so vision-capable models keep receiving images
  /// directly and image turns are left untouched when no OCR model is set
  /// (footnote: "未设置时使用聊天模型识别图片").
  Future<({Model model, String prompt})?> resolveOcrFallback(
    Model chatModel,
  ) async {
    if (isVisionModel(chatModel)) return null;
    final auxState = _ref.read(auxiliaryModelControllerProvider);
    final providers = await _ref.read(appModelProvidersProvider.future);
    final resolved = resolveAuxiliaryModel(auxState.ocrModelKey, providers);
    if (resolved == null) return null;
    return (model: effectiveModelFor(resolved), prompt: auxState.ocrPrompt);
  }

  /// The image parts on [view] (raw base64) for a multimodal request, decoded
  /// from its `IMAGE` blocks; `null` when it has none so plain-text turns are
  /// serialised unchanged.
  List<LlmContentImage>? requestImages(ChatMessageView view) {
    final images = <LlmContentImage>[
      for (final block in view.blocks)
        if (block is ImageBlock)
          if (imagePart(block) case final part?) part,
    ];
    return images.isEmpty ? null : images;
  }

  /// Resolves an [ImageBlock] to a request image part, preferring its raw
  /// [ImageBlock.base64Data] and falling back to the file reference's `data:`
  /// URI; `null` when neither carries data.
  LlmContentImage? imagePart(ImageBlock block) {
    final raw = block.base64Data;
    if (raw != null && raw.isNotEmpty) {
      return LlmContentImage(mimeType: block.mimeType, base64Data: raw);
    }
    final reference = block.file?.base64Data;
    if (reference != null && reference.isNotEmpty) {
      final comma = reference.indexOf(',');
      final encoded = comma >= 0 ? reference.substring(comma + 1) : reference;
      if (encoded.isNotEmpty) {
        return LlmContentImage(mimeType: block.mimeType, base64Data: encoded);
      }
    }
    return null;
  }

  /// The request content for [view]: its main text with each FILE block's
  /// decoded text appended, so the model receives pasted-as-file content (and
  /// likewise for history, since the view projection carries FILE blocks
  /// through).
  ///
  /// When [regexRules] are supplied, the assistant's non-`visualOnly` 正则规则
  /// are applied (scoped by `view.role`) before sending — the port of the web
  /// `applyRegexRulesForSending` step in `apiPreparation.ts`.
  String requestContent(
    ChatMessageView view, {
    List<AssistantRegex>? regexRules,
  }) {
    final parts = <String>[
      if (view.text.isNotEmpty) view.text,
      for (final block in view.blocks)
        if (block is FileBlock)
          if (decodeFileText(block) case final text? when text.isNotEmpty) text,
    ];
    final content = parts.join('\n\n');
    return applySendingRegex(content, view.role, regexRules);
  }

  String applySendingRegex(
    String content,
    MessageRole role,
    List<AssistantRegex>? regexRules,
  ) {
    final scope = _regexScopeFor(role);
    if (scope == null || regexRules == null || regexRules.isEmpty) {
      return content;
    }
    return applyRegexRulesForSending(content, regexRules, scope);
  }

  /// Maps a [MessageRole] to its 正则 scope, or null for roles (e.g. system)
  /// that 正则规则 never target.
  static AssistantRegexScope? _regexScopeFor(MessageRole role) =>
      switch (role) {
        MessageRole.user => AssistantRegexScope.user,
        MessageRole.assistant => AssistantRegexScope.assistant,
        _ => null,
      };

  /// Decodes a FILE block's inline text, or `null` when it carries no decodable
  /// `text/plain` base64 data URI.
  String? decodeFileText(FileBlock block) {
    if (block.mimeType != 'text/plain') return null;
    final data = block.file?.base64Data;
    if (data == null || data.isEmpty) return null;
    final comma = data.indexOf(',');
    final encoded = comma >= 0 ? data.substring(comma + 1) : data;
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return null;
    }
  }
}
