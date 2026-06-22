import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_block_status.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_status.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/app_markdown.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/code_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/data_blocks.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/media_blocks.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/text_blocks.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/thinking_block_view.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/web_search_block_view.dart';

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
/// The thinking-phase inline-tool grouping and the 16 thinking display styles
/// are later slices; tool blocks render as their own cards for now.
class MessageBlockRenderer extends StatelessWidget {
  const MessageBlockRenderer({
    required this.blocks,
    required this.messageStatus,
    this.textColor,
    super.key,
  });

  final List<MessageBlock> blocks;
  final MessageStatus messageStatus;
  final Color? textColor;

  bool get _isStreaming =>
      messageStatus == MessageStatus.streaming ||
      messageStatus == MessageStatus.processing;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupSimilarBlocks(blocks);
    final widgets = <Widget>[];
    for (final item in grouped) {
      final widget = _buildItem(item);
      if (widget != null) widgets.add(widget);
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

  Widget? _buildItem(_RenderItem item) {
    switch (item) {
      case _ImageGroup(:final images):
        return ImageBlockGroupView(blocks: images);
      case _SingleBlock(:final block):
        return _buildBlock(block);
    }
  }

  Widget? _buildBlock(MessageBlock block) {
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
        return MainTextBlockView(block: block, textColor: textColor);
      case ThinkingBlock():
        return ThinkingBlockView(block: block);
      case ImageBlock():
        return ImageBlockView(block: block);
      case VideoBlock():
        return VideoBlockView(block: block);
      case CodeBlock():
        return CodeBlockViewBlock(block: block);
      case ToolBlock():
        if (block.toolName == 'builtin_web_search') {
          return WebSearchBlockView(block: block);
        }
        return ToolBlockView(block: block);
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
