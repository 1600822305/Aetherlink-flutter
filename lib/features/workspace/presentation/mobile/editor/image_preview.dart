import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/editor_placeholders.dart';
import 'package:aetherlink_flutter/features/workspace/presentation/mobile/editor/workspace_file_share.dart';

/// Reads an image file's raw bytes through [backend] and renders it with
/// pinch-to-zoom / pan support, a live zoom readout (tap to reset) and a
/// share button. Falls back to an error placeholder when the decode fails
/// (corrupt file, unsupported format, backend can't read bytes).
class ImagePreview extends ConsumerStatefulWidget {
  const ImagePreview({
    super.key,
    required this.entry,
    required this.backend,
  });

  final WorkspaceEntry entry;
  final WorkspaceBackend backend;

  @override
  ConsumerState<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends ConsumerState<ImagePreview> {
  late Future<Uint8List> _load;
  final _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    _load = _readBytes();
  }

  Future<Uint8List> _readBytes() async {
    final bytes = await widget.backend
        .readFileBytes(widget.entry.path);
    return Uint8List.fromList(bytes);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Uint8List>(
      future: _load,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
          return UnsupportedFilePlaceholder(
            entry: widget.entry,
            icon: LucideIcons.imageOff,
            title: '无法加载图片',
            message: '${snap.error ?? '读取失败'}',
          );
        }
        final bytes = snap.data!;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onDoubleTapDown: (details) {
                  final scale = _controller.value.getMaxScaleOnAxis();
                  final next = scale > 1.0 ? 1.0 : 3.0;
                  _controller.value = Matrix4.identity()
                    ..translate(
                        details.localPosition.dx, details.localPosition.dy)
                    ..scale(next)
                    ..translate(
                        -details.localPosition.dx, -details.localPosition.dy);
                },
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 0.5,
                  maxScale: 8.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          UnsupportedFilePlaceholder(
                        entry: widget.entry,
                        icon: LucideIcons.imageOff,
                        title: '图片解码失败',
                        message: '该文件可能已损坏或格式不受支持。',
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: '点击重置缩放',
                    child: InkWell(
                      onTap: () => _controller.value = Matrix4.identity(),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: ValueListenableBuilder<Matrix4>(
                          valueListenable: _controller,
                          builder: (context, m, _) => Text(
                            '${(m.getMaxScaleOnAxis() * 100).round()}%'
                            ' · ${formatBytes(bytes.length)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    tooltip: '分享 / 用其他应用打开',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(LucideIcons.share2, size: 16),
                    onPressed: () => shareWorkspaceFile(
                      context,
                      ref,
                      entry: widget.entry,
                      bytes: bytes,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
