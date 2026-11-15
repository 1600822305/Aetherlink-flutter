import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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
  Size? _imageSize;

  /// True when a gesture began on the image itself (vs. the black margin).
  /// 微信同款语义：拖拽关闭/双击缩放只在图片上生效，黑色区域只响应点按关闭。
  var _gestureOnImage = false;

  bool get _zoomed => _viewerController.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  /// The viewer child is sized exactly to the fitted image rect (no letterbox
  /// inside the child), so `toScene` bounds checks can tell image from margin.
  void _loadImageSize() {
    final stream = widget.provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (mounted) {
          setState(() {
            _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
          });
        }
      },
      onError: (_, _) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }

  /// Maps a viewport position into child coords and checks the image bounds.
  bool _insideImage(Offset viewportPosition) {
    final size = _imageSize;
    if (size == null) return true;
    final scene = _viewerController.toScene(viewportPosition);
    return scene.dx >= 0 &&
        scene.dy >= 0 &&
        scene.dx <= size.width &&
        scene.dy <= size.height;
  }

  void _toggleZoom(TapDownDetails details) {
    if (_zoomed) {
      _viewerController.value = Matrix4.identity();
      return;
    }
    if (!_insideImage(details.localPosition)) return;
    // Anchor the zoom at the tapped point: map the viewport position into the
    // child's (image) coordinate space via toScene.
    const s = _zoomedScale;
    final focal = details.localPosition;
    final scene = _viewerController.toScene(focal);
    _viewerController.value = Matrix4.identity()
      ..translate(focal.dx - s * scene.dx, focal.dy - s * scene.dy)
      ..scale(s);
  }

  void _onVerticalDragStart(DragStartDetails details) {
    _gestureOnImage = _insideImage(details.localPosition);
    _dragOffset = 0.0;
  }

  void _onVerticalDrag(DragUpdateDetails details) {
    if (!_gestureOnImage) return;
    if (_zoomed) {
      // The outer detector already claimed this drag; InteractiveViewer can't
      // take it back, so pan the zoomed image by translating its matrix.
      _viewerController.value = _viewerController.value.clone()
        ..translate(0.0, details.delta.dy);
      return;
    }
    setState(() => _dragOffset += details.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    if (_gestureOnImage && _dragOffset.abs() > _dismissDistance) {
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
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDrag,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: Center(
                child: Hero(
                  tag: widget.heroTag,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = _imageSize;
                      if (size == null ||
                          size.width <= 0 ||
                          size.height <= 0) {
                        return const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white70,
                          ),
                        );
                      }
                      // BoxFit.contain math: the child IS the image, so the
                      // black margin is outside the InteractiveViewer child.
                      final scale = math.min(
                        constraints.maxWidth / size.width,
                        constraints.maxHeight / size.height,
                      );
                      return InteractiveViewer(
                        transformationController: _viewerController,
                        maxScale: 8,
                        child: SizedBox(
                          width: size.width * scale,
                          height: size.height * scale,
                          child: Image(
                            image: widget.provider,
                            fit: BoxFit.fill,
                          ),
                        ),
                      );
                    },
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
