import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';

/// Resolves an [ImageBlock] to an [ImageProvider]. Prefers inline base64
/// (`base64Data` or a `data:` URL) and falls back to a network URL. The
/// original's `[图片:ID]` Dexie references have no Flutter equivalent yet, so
/// they resolve to null (rendered as the load-failure placeholder).
ImageProvider? _imageProvider(ImageBlock block) {
  final b64 = block.base64Data;
  if (b64 != null && b64.isNotEmpty) {
    try {
      return MemoryImage(base64Decode(b64));
    } on FormatException {
      // fall through
    }
  }
  final url = block.url;
  if (url.startsWith('data:')) {
    final marker = url.indexOf('base64,');
    if (marker >= 0) {
      try {
        return MemoryImage(base64Decode(url.substring(marker + 7)));
      } on FormatException {
        return null;
      }
    }
  }
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  return null;
}

/// Renders an `IMAGE` block, mirroring `ImageBlock.tsx`: a rounded thumbnail
/// (max 300px single / 180px grouped) with a zoom button, tap to open a
/// full-screen preview.
class ImageBlockView extends StatelessWidget {
  const ImageBlockView({required this.block, this.isSingle = true, super.key});

  final ImageBlock block;
  final bool isSingle;

  @override
  Widget build(BuildContext context) {
    final provider = _imageProvider(block);
    if (provider == null) return const _ImageError();

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _ImagePreviewDialog(provider: provider),
      ),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: isSingle ? 300 : 180),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _ImageError(),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.maximize2,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.circleAlert,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            '图片加载失败',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewDialog extends StatelessWidget {
  const _ImagePreviewDialog({required this.provider});

  final ImageProvider provider;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          child: Image(image: provider, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Renders consecutive `IMAGE` blocks as a grid, mirroring `ImageBlockGroup`:
/// 1 image = full width, 2-4 = two columns, more = three columns.
class ImageBlockGroupView extends StatelessWidget {
  const ImageBlockGroupView({required this.blocks, super.key});

  final List<ImageBlock> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.length == 1) {
      return ImageBlockView(block: blocks.first);
    }
    final columns = blocks.length <= 4 ? 2 : 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 4.0;
        final cell = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final block in blocks)
              SizedBox(
                width: cell,
                child: ImageBlockView(block: block, isSingle: false),
              ),
          ],
        );
      },
    );
  }
}

/// Renders a `VIDEO` block. Playback needs a video plugin (later slice); for
/// now this shows the poster (when present) or a placeholder card with a play
/// glyph and 「播放即将支持」.
class VideoBlockView extends StatelessWidget {
  const VideoBlockView({required this.block, super.key});

  final VideoBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 160,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.play, color: Colors.white, size: 32),
          const SizedBox(height: 6),
          Text(
            '视频 · 播放即将支持',
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Renders a `FILE` block, mirroring `FileBlock.tsx`: a compact card with a
/// file icon, the file name and its size. The download affordance is a later
/// (request/file-layer) slice.
class FileBlockView extends StatelessWidget {
  const FileBlockView({required this.block, super.key});

  final FileBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = _formatBytes(block.size);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.fileText,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  block.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (size.isNotEmpty)
                  Text(
                    size,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
