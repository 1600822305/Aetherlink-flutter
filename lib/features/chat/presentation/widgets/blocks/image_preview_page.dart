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
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => ImagePreviewPage(
        provider: provider,
        heroTag: heroTag,
      ),
      transitionsBuilder: (_, _, _, child) => child,
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

class _ImagePreviewPageState extends State<ImagePreviewPage>
    with SingleTickerProviderStateMixin {
  static const _kDismissDistance = 100.0;
  static const _kZoomedScale = 2.5;

  var _scale = 1.0;
  var _offset = Offset.zero;
  var _dismissOffset = Offset.zero;
  var _dismissScale = 1.0;
  var _dismissAnchor = Offset.zero;
  var _isDismissing = false;
  var _isDismissFromZoom = false;
  var _isGestureOnImage = false;
  var _busy = false;
  var _pointerCount = 0;
  var _lastFocal = Offset.zero;
  var _scaleReference = 1.0;
  var _gestureScale = 1.0;
  var _doubleTapPosition = Offset.zero;
  Size _viewport = Size.zero;
  Size? _imageSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;

  late final AnimationController _motion = AnimationController(vsync: this);
  VoidCallback? _motionTick;

  bool get _isZoomed => _scale > 1.01;
  Offset get _center => _viewport.center(Offset.zero);
  double get _effectiveScale => _scale * _dismissScale;
  Offset get _effectiveOffset =>
      _offset * _dismissScale +
      (_dismissAnchor - _center) * (1 - _dismissScale) +
      _dismissOffset;

  Size get _fittedSize {
    final size = _imageSize;
    if (size == null || size.isEmpty || _viewport.isEmpty) return _viewport;
    final scale = math.min(
      _viewport.width / size.width,
      _viewport.height / size.height,
    );
    return Size(size.width * scale, size.height * scale);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadImageSize();
  }

  void _removeImageListener() {
    final listener = _imageListener;
    if (listener != null) _imageStream?.removeListener(listener);
    _imageStream = null;
    _imageListener = null;
  }

  void _loadImageSize() {
    _removeImageListener();
    final stream = widget.provider.resolve(
      createLocalImageConfiguration(context),
    );
    _imageStream = stream;
    _imageListener = ImageStreamListener(
      (info, _) {
        _removeImageListener();
        if (!mounted) return;
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
      onError: (_, _) => _removeImageListener(),
    );
    stream.addListener(_imageListener!);
  }

  bool _insideImage(Offset position) {
    final local = (position - _center - _effectiveOffset) / _effectiveScale;
    return Rect.fromCenter(
      center: Offset.zero,
      width: _fittedSize.width,
      height: _fittedSize.height,
    ).contains(local);
  }

  Offset _clampOffset(Offset offset, double scale) {
    final size = _fittedSize;
    final x = math.max(0.0, (size.width * scale - _viewport.width) / 2);
    final y = math.max(0.0, (size.height * scale - _viewport.height) / 2);
    return Offset(
      offset.dx.clamp(-x, x).toDouble(),
      offset.dy.clamp(-y, y).toDouble(),
    );
  }

  void _stopMotion() {
    _motion.stop();
    final tick = _motionTick;
    if (tick != null) _motion.removeListener(tick);
    _motionTick = null;
  }

  void _animateTo(double scale, Offset offset, Duration duration) {
    _stopMotion();
    final fromScale = _scale;
    final fromOffset = _offset;
    final fromDismissOffset = _dismissOffset;
    final fromDismissScale = _dismissScale;
    _motion.duration = duration;
    _motionTick = () {
      if (!mounted) return;
      final t = Curves.easeOutCubic.transform(_motion.value);
      setState(() {
        _scale = fromScale + (scale - fromScale) * t;
        _offset = Offset.lerp(fromOffset, offset, t)!;
        _dismissOffset = Offset.lerp(fromDismissOffset, Offset.zero, t)!;
        _dismissScale = fromDismissScale + (1 - fromDismissScale) * t;
      });
    };
    _motion.addListener(_motionTick!);
    _motion.forward(from: 0);
  }

  void _toggleZoom() {
    if (_isDismissing) return;
    if (_isZoomed) {
      _animateTo(1, Offset.zero, const Duration(milliseconds: 250));
      return;
    }
    if (!_insideImage(_doubleTapPosition)) return;
    final scene =
        (_doubleTapPosition - _center - _effectiveOffset) / _effectiveScale;
    final offset = _doubleTapPosition - _center - scene * _kZoomedScale;
    _animateTo(
      _kZoomedScale,
      _clampOffset(offset, _kZoomedScale),
      const Duration(milliseconds: 250),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _stopMotion();
    // 回弹中再次触摸时，先合并成同一个变换，避免跳动。
    _offset = _effectiveOffset;
    _scale = _effectiveScale;
    _dismissOffset = Offset.zero;
    _dismissScale = 1;
    _lastFocal = details.localFocalPoint;
    _dismissAnchor = _lastFocal;
    _isGestureOnImage = _insideImage(_lastFocal);
    _pointerCount = details.pointerCount;
    _gestureScale = _scale;
    _scaleReference = 1;
    _isDismissFromZoom = false;
    setState(() {
      _isDismissing =
          !_isZoomed && _pointerCount == 1 && _isGestureOnImage;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final focal = details.localFocalPoint;
    final delta = focal - _lastFocal;
    if (_isDismissing && !_isDismissFromZoom && details.pointerCount > 1) {
      _offset = _effectiveOffset;
      _scale = _effectiveScale;
      _dismissOffset = Offset.zero;
      _dismissScale = 1;
      setState(() => _isDismissing = false);
    }
    if (!_isDismissing && details.pointerCount != _pointerCount) {
      _pointerCount = details.pointerCount;
      _gestureScale = _scale;
      _scaleReference = details.scale;
      _lastFocal = focal;
      return;
    }
    if (!_isDismissing &&
        _isZoomed &&
        details.pointerCount == 1 &&
        delta.dy > 0) {
      final top =
          _center.dy + _offset.dy - _fittedSize.height * _scale / 2;
      if (top >= -0.5) {
        _dismissAnchor = _lastFocal;
        _isDismissing = true;
        _isDismissFromZoom = true;
      }
    }
    setState(() {
      if (_isDismissing) {
        _dismissOffset += delta;
        final down = math.max(0.0, _dismissOffset.dy);
        _dismissScale =
            (1 - down / _viewport.height).clamp(0.4, 1.0).toDouble();
      } else if (_isZoomed || details.pointerCount > 1) {
        final nextScale = (_gestureScale * details.scale / _scaleReference)
            .clamp(0.9, 8.0)
            .toDouble();
        final scene = (_lastFocal - _center - _offset) / _scale;
        _offset = _clampOffset(
          focal - _center - scene * nextScale,
          nextScale,
        );
        _scale = nextScale;
      }
    });
    _lastFocal = focal;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isDismissing &&
        (_dismissOffset.dy > _kDismissDistance ||
            details.velocity.pixelsPerSecond.dy > 700)) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isDismissing = false);
    final scale = _scale < 1 ? 1.0 : _scale;
    _animateTo(
      scale,
      _clampOffset(_offset, scale),
      const Duration(milliseconds: 220),
    );
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
    _removeImageListener();
    _stopMotion();
    _motion.dispose();
    super.dispose();
  }

  Widget _buildImage() {
    final size = _fittedSize;
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(_effectiveOffset.dx, _effectiveOffset.dy)
          ..scale(_effectiveScale),
        child: Hero(
          tag: widget.heroTag,
          flightShuttleBuilder: (_, animation, _, _, _) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) => ClipRRect(
                borderRadius: BorderRadius.circular(
                  8 * (1 - animation.value),
                ),
                child: Image(
                  image: widget.provider,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            );
          },
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: ClipRRect(
              child: Image(
                image: widget.provider,
                fit: _imageSize == null ? BoxFit.contain : BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chrome(Widget child) {
    return IgnorePointer(
      ignoring: _isDismissing,
      child: AnimatedOpacity(
        opacity: _isDismissing ? 0 : 1,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)!.animation!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          _viewport = constraints.biggest;
          return AnimatedBuilder(
            animation: routeAnimation,
            builder: (context, _) {
              final down = math.max(0.0, _dismissOffset.dy);
              final dragOpacity =
                  (1 - down / _viewport.height).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: Colors.black.withValues(
                      alpha: routeAnimation.value * dragOpacity,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    onDoubleTapDown: (details) {
                      _doubleTapPosition = details.localPosition;
                    },
                    onDoubleTap: _toggleZoom,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    child: _buildImage(),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 8,
                    child: _chrome(
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                    child: _chrome(
                      Row(
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
                  ),
                ],
              );
            },
          );
        },
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
