import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/thinking_settings_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/code_block/code_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/data_blocks.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/media_blocks.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/text_blocks.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_editor/file_editor_changeset_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/thinking_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/tool_renderer_registry.dart';

/// Dispatches an ordered list of [MessageBlock]s to per-type widgets, mirroring
/// the original `MessageBlockRenderer.tsx`.
///
/// Responsibilities ported here:
///   * render each block in `message.blocks` order with vertical spacing;
///   * group consecutive `IMAGE` blocks into a grid and de-duplicate repeated
///     `VIDEO` blocks by URL ([_groupSimilarBlocks]);
///   * show the streaming placeholder (「正在生成回复...」) when nothing visible
///     has been produced yet.
///
/// Thinking-phase tool calls are grouped and embedded inside the corresponding
/// thinking block as lightweight `InlineToolChip`s, mirroring the web's
/// `computeInlineToolGroups`. Once `MAIN_TEXT` appears the answer phase starts
/// and subsequent tool blocks render as independent top-level cards.
///
/// Gated on 思考过程设置 → 思考过程内显示工具调用 ([ThinkingSettings.thinkingToolInline]):
/// when off, thinking-phase tools are not consumed and render top-level like
/// any other tool block, mirroring the original's `thinkingToolInline` switch.
class MessageBlockRenderer extends ConsumerWidget {
  const MessageBlockRenderer({
    required this.blocks,
    required this.messageStatus,
    this.role,
    this.textColor,
    super.key,
  });

  final List<MessageBlock> blocks;
  final MessageStatus messageStatus;
  final MessageRole? role;
  final Color? textColor;

  bool get _isStreaming =>
      messageStatus == MessageStatus.streaming ||
      messageStatus == MessageStatus.processing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolInline = ref.watch(
      thinkingSettingsProvider.select((s) => s.thinkingToolInline),
    );
    // Phase-aware grouping: thinking-phase tool blocks are consumed and attached
    // to their corresponding ThinkingBlock instead of rendering top-level.
    final (:consumedToolIds, :inlineToolMap) = _computeInlineToolGroups(
      blocks,
      inlineEnabled: toolInline,
    );

    final grouped = _groupSimilarBlocks(blocks);
    final widgets = <Widget>[];
    var i = 0;
    while (i < grouped.length) {
      final item = grouped[i];
      // Coalesce a run (≥2) of consecutive top-level file-editor write tools
      // into one changeset card, mirroring Cursor/Windsurf "edited N files".
      if (_isChangesetEligible(item, consumedToolIds)) {
        final run = <ToolBlock>[];
        var j = i;
        while (j < grouped.length &&
            _isChangesetEligible(grouped[j], consumedToolIds)) {
          run.add((grouped[j] as _SingleBlock).block as ToolBlock);
          j++;
        }
        if (run.length >= 2) {
          widgets.add(FileEditorChangesetView(blocks: run));
          i = j;
          continue;
        }
      }
      final widget = _buildItem(item, consumedToolIds, inlineToolMap);
      if (widget != null) widgets.add(widget);
      i++;
    }

    if (widgets.isEmpty) {
      if (_isStreaming) return const PlaceholderBlockView();
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widgets.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          widgets[i],
        ],
      ],
    );
  }

  /// Whether [item] is a top-level (not thinking-inlined) file-editor write
  /// tool block, eligible to be merged into a changeset card.
  static bool _isChangesetEligible(_RenderItem item, Set<String> consumedToolIds) {
    if (item is! _SingleBlock) return false;
    final block = item.block;
    return block is ToolBlock &&
        !consumedToolIds.contains(block.id) &&
        isFileEditorWriteTool(block.toolName);
  }

  Widget? _buildItem(
    _RenderItem item,
    Set<String> consumedToolIds,
    Map<String, List<ToolBlock>> inlineToolMap,
  ) {
    switch (item) {
      case _ImageGroup(:final images):
        return ImageBlockGroupView(blocks: images);
      case _SingleBlock(:final block):
        return _buildBlock(block, consumedToolIds, inlineToolMap);
    }
  }

  Widget? _buildBlock(
    MessageBlock block,
    Set<String> consumedToolIds,
    Map<String, List<ToolBlock>> inlineToolMap,
  ) {
    switch (block) {
      case UnknownBlock(:final content, :final status):
        if (status == MessageBlockStatus.processing) {
          return const PlaceholderBlockView();
        }
        final text = cleanMainText(content ?? '');
        if (text.isEmpty) return null;
        return AppMarkdown(
          content: text,
          style: textColor == null
              ? null
              : TextStyle(color: textColor, height: 1.6),
        );
      case MainTextBlock():
        if (cleanMainText(block.content).isEmpty) return null;
        return MainTextBlockView(
          block: block,
          role: role,
          textColor: textColor,
        );
      case ThinkingBlock():
        return ThinkingBlockView(
          block: block,
          inlineToolBlocks: inlineToolMap[block.id] ?? const [],
        );
      case ImageBlock():
        return ImageBlockView(block: block);
      case VideoBlock():
        return VideoBlockView(block: block);
      case CodeBlock():
        return CodeBlockViewBlock(block: block);
      case ToolBlock():
        // Skip tool blocks that were consumed into a thinking block.
        if (consumedToolIds.contains(block.id)) return null;
        return buildSpecialToolBlock(block) ?? ToolBlockView(block: block);
      case FileBlock():
        return FileBlockView(block: block);
      case ErrorBlock():
        return ErrorBlockView(block: block);
      case CitationBlock():
        return CitationBlockView(block: block);
      case TranslationBlock():
        return TranslationBlockView(block: block);
      case ChartBlock():
        return ChartBlockView(block: block);
      case MathBlock():
        return MathBlockView(block: block);
      case KnowledgeReferenceBlock():
        return KnowledgeReferenceBlockView(block: block);
      case ContextSummaryBlock():
        return ContextSummaryBlockView(block: block);
      case MemoryInjectionBlock():
        return MemoryInjectionBlockView(block: block);
    }
  }

  /// Groups consecutive `IMAGE` blocks and drops duplicate `VIDEO` blocks by
  /// URL, mirroring `groupSimilarBlocks`.
  static List<_RenderItem> _groupSimilarBlocks(List<MessageBlock> blocks) {
    final result = <_RenderItem>[];
    final seenVideoUrls = <String>{};
    var imageRun = <ImageBlock>[];

    void flushImages() {
      if (imageRun.isEmpty) return;
      result.add(_ImageGroup(List<ImageBlock>.of(imageRun)));
      imageRun = <ImageBlock>[];
    }

    for (final block in blocks) {
      if (block is ImageBlock) {
        imageRun.add(block);
        continue;
      }
      flushImages();
      if (block is VideoBlock) {
        if (!seenVideoUrls.add(block.url)) continue;
      }
      result.add(_SingleBlock(block));
    }
    flushImages();
    return result;
  }
}

/// A code block rendered as a top-level block (`CODE`), reusing the same view
/// the Markdown fenced-code builder uses.
class CodeBlockViewBlock extends StatelessWidget {
  const CodeBlockViewBlock({required this.block, super.key});

  final CodeBlock block;

  @override
  Widget build(BuildContext context) {
    return CodeBlockView(
      language: block.language ?? 'text',
      code: block.content,
    );
  }
}

/// Phase-aware grouping: TOOL blocks that appear after a THINKING block and
/// before the first MAIN_TEXT are "thinking-phase" tools. They get consumed
/// into the thinking block and removed from the top-level flow.
///
/// Mirrors `computeInlineToolGroups` in the web's `MessageBlockRenderer.tsx`.
///
/// When [inlineEnabled] is false the grouping is skipped entirely, so no tool
/// block is consumed and every tool renders as an independent top-level card.
({Set<String> consumedToolIds, Map<String, List<ToolBlock>> inlineToolMap})
_computeInlineToolGroups(
  List<MessageBlock> blocks, {
  required bool inlineEnabled,
}) {
  final consumedToolIds = <String>{};
  final inlineToolMap = <String, List<ToolBlock>>{};
  if (!inlineEnabled) {
    return (consumedToolIds: consumedToolIds, inlineToolMap: inlineToolMap);
  }
  String? currentThinkingId;

  for (final block in blocks) {
    if (block is ThinkingBlock) {
      currentThinkingId = block.id;
    } else if (block is MainTextBlock) {
      // Answer phase starts — subsequent tools stay top-level.
      currentThinkingId = null;
    } else if (block is ToolBlock && currentThinkingId != null) {
      inlineToolMap.putIfAbsent(currentThinkingId, () => []).add(block);
      consumedToolIds.add(block.id);
    }
  }

  return (consumedToolIds: consumedToolIds, inlineToolMap: inlineToolMap);
}

sealed class _RenderItem {
  const _RenderItem();
}

class _SingleBlock extends _RenderItem {
  const _SingleBlock(this.block);
  final MessageBlock block;
}

class _ImageGroup extends _RenderItem {
  const _ImageGroup(this.images);
  final List<ImageBlock> images;
}
