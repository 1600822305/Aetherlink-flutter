import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';

/// Opens the full-screen image viewer (Hero transition, pinch/double-tap zoom,
/// swipe-down dismiss, save/share toolbar). [heroTag] must be unique per image
/// and match the thumbnail's [Hero] tag.
void showImagePreview(
  BuildContext context, {
  required ImageProvider provider,
  required String heroTag,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => ImagePreviewPage(
        provider: provider,
        heroTag: heroTag,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// 全屏图片查看器：双指/双击缩放、下滑关闭、保存到相册、分享。
/// 对齐微信 / Telegram / ChatGPT 的图片查看交互。
class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    required this.provider,
    required this.heroTag,
    super.key,
  });

  final ImageProvider provider;
  final String heroTag;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  static const _dismissDistance = 120.0;
  static const _zoomedScale = 2.5;

  final _viewerController = TransformationController();
  var _dragOffset = 0.0;
  var _busy = false;

  bool get _zoomed => _viewerController.value.getMaxScaleOnAxis() > 1.01;

  void _toggleZoom(TapDownDetails details) {
    if (_zoomed) {
      _viewerController.value = Matrix4.identity();
      return;
    }
    final position = details.localPosition;
    _viewerController.value = Matrix4.identity()
      ..translate(-position.dx * (_zoomedScale - 1),
          -position.dy * (_zoomedScale - 1))
      ..scale(_zoomedScale);
  }

  void _onVerticalDrag(DragUpdateDetails details) {
    // Zoomed in: let InteractiveViewer pan instead of dismissing.
    if (_zoomed) return;
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    if (_dragOffset.abs() > _dismissDistance) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _dragOffset = 0.0);
  }

  Future<Uint8List> _imageBytes() async {
    final completer = Completer<ui.Image>();
    final stream = widget.provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info.image);
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    final image = await completer.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('image encode failed');
    return data.buffer.asUint8List();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await Gal.requestAccess(toAlbum: false);
      if (!granted) {
        if (mounted) AppToast.error(context, '没有相册权限');
        return;
      }
      await Gal.putImageBytes(await _imageBytes());
      if (mounted) AppToast.success(context, '已保存到相册');
    } catch (e) {
      if (mounted) AppToast.error(context, '保存失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/aetherlink_image.png');
      await file.writeAsBytes(await _imageBytes(), flush: true);
      await SharePlus.instance
          .share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (mounted) AppToast.error(context, '分享失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - _dragOffset.abs() / (_dismissDistance * 2))
        .clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            onDoubleTapDown: _toggleZoom,
            onDoubleTap: () {},
            onVerticalDragUpdate: _onVerticalDrag,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Center(
                child: Hero(
                  tag: widget.heroTag,
                  child: InteractiveViewer(
                    transformationController: _viewerController,
                    maxScale: 8,
                    child: Image(
                      image: widget.provider,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(LucideIcons.x, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ActionButton(
                  icon: LucideIcons.download,
                  label: '保存',
                  busy: _busy,
                  onTap: _save,
                ),
                const SizedBox(width: 24),
                _ActionButton(
                  icon: LucideIcons.share2,
                  label: '分享',
                  busy: _busy,
                  onTap: _share,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
