import 'dart:convert';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'package:aetherlink_flutter/features/chat/domain/entities/message_block.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/file_block_preview.dart';

/// Resolves an [ImageBlock] to an [ImageProvider]. Prefers inline base64
/// (`base64Data` or a `data:` URL) and falls back to a network URL. The
/// original's `[图片:ID]` Dexie references have no Flutter equivalent yet, so
/// they resolve to null (rendered as the load-failure placeholder).
///
/// Results are cached by block identity so `base64Decode` doesn't repeat on
/// every parent rebuild.
ImageProvider? _imageProvider(ImageBlock block) {
  final cached = _imageProviderCache[block.id];
  if (cached != null) return cached;

  final result = _resolveImageProvider(block);
  if (result != null) _imageProviderCache[block.id] = result;
  return result;
}

final Map<String, ImageProvider> _imageProviderCache = {};

ImageProvider? _resolveImageProvider(ImageBlock block) {
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

/// Renders a `VIDEO` block, mirroring `VideoBlock.tsx`: an inline player
/// (chewie controls, tap-to-play, fullscreen) capped at 400px like the web's
/// `<video>`. Sources resolve the same way the web does — an http(s) URL plays
/// directly; inline base64 (`base64Data` or a `data:` URL) is materialized to
/// a temp file first since the platform players can't stream data URIs.
class VideoBlockView extends StatefulWidget {
  const VideoBlockView({required this.block, super.key});

  final VideoBlock block;

  @override
  State<VideoBlockView> createState() => _VideoBlockViewState();
}

class _VideoBlockViewState extends State<VideoBlockView> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final controller = await _createController(widget.block);
      if (controller == null) {
        if (mounted) setState(() => _error = true);
        return;
      }
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _videoController = controller;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
      );
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  static Future<VideoPlayerController?> _createController(
    VideoBlock block,
  ) async {
    final url = block.url;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return VideoPlayerController.networkUrl(Uri.parse(url));
    }
    var b64 = block.base64Data;
    if (b64 == null || b64.isEmpty) {
      if (url.startsWith('data:')) {
        final marker = url.indexOf('base64,');
        if (marker >= 0) b64 = url.substring(marker + 7);
      }
    }
    if (b64 == null || b64.isEmpty) return null;
    final bytes = base64Decode(b64);
    final dir = await getTemporaryDirectory();
    final ext = _extensionFor(block.mimeType);
    final file = File('${dir.path}/video_block_${block.id}$ext');
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return VideoPlayerController.file(file);
  }

  static String _extensionFor(String mimeType) => switch (mimeType) {
    'video/webm' => '.webm',
    'video/quicktime' => '.mov',
    'video/x-matroska' => '.mkv',
    _ => '.mp4',
  };

  @override
  Widget build(BuildContext context) {
    if (_error) return const _VideoError();
    final chewie = _chewieController;
    if (chewie == null) {
      return Container(
        height: 160,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ColoredBox(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: chewie.aspectRatio ?? 16 / 9,
            child: Chewie(controller: chewie),
          ),
        ),
      ),
    );
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 160,
      width: double.infinity,
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
            '视频加载失败',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
/// file icon, the file name and its size. Tapping it opens the attachment
/// preview (text / image inline, other types via the OS share sheet).
class FileBlockView extends StatelessWidget {
  const FileBlockView({required this.block, super.key});

  final FileBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = _formatBytes(block.size);
    final card = Container(
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
    return GestureDetector(
      onTap: () => showFileBlockPreview(context, block),
      child: card,
    );
  }
}
