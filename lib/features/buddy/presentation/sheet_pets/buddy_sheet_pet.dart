// Codex Pet spritesheet 渲染：兼容 codex-pet.org 的宠物包格式——
// 一张 8 列 × 9 行的精灵图（9 种动画状态，每行 8 帧）。
// 待机行循环播放；被摸时播一遍「挥手」行再回到待机。

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Codex 宠物包的固定网格：8 列（帧）× 9 行（状态）。
const int kCodexSheetCols = 8;
const int kCodexSheetRows = 9;

/// 状态行索引（与 codex-pet.org 预览顺序一致）。
const int kCodexRowIdle = 0;
const int kCodexRowWave = 3;

/// 待机一轮 8 帧的时长（与官网 CSS --sprite-sequence-duration 一致）。
const double _idleCycleSec = 8.4;

/// 被摸「挥手」一轮播放时长。
const double _waveCycleSec = 1.6;

/// 内置 Codex 精灵图的物种映射（asset 路径）。
const Map<String, String> kBuddyBuiltinSheetAssets = {
  'nailong': 'assets/buddy/nailong0.webp',
};

class BuddySheetPet extends StatefulWidget {
  const BuddySheetPet({
    super.key,
    required this.image,
    this.size = 128,
    this.petTrigger = 0,
  });

  final ImageProvider image;
  final double size;
  final int petTrigger;

  @override
  State<BuddySheetPet> createState() => _BuddySheetPetState();
}

class _BuddySheetPetState extends State<BuddySheetPet>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  double _petStart = -100;
  ui.Image? _sheet;
  ImageStream? _stream;
  late final ImageStreamListener _listener =
      ImageStreamListener((info, _) {
    if (mounted) setState(() => _sheet = info.image);
  });

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    })
      ..start();
    _resolveImage();
  }

  void _resolveImage() {
    final stream = widget.image.resolve(ImageConfiguration.empty);
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void didUpdateWidget(covariant BuddySheetPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.petTrigger != oldWidget.petTrigger) {
      _petStart = _time.value;
    }
    if (widget.image != oldWidget.image) _resolveImage();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: _sheet == null
          ? null
          : CustomPaint(
              painter: _SheetPainter(
                time: _time,
                sheet: _sheet!,
                petStartOf: () => _petStart,
              ),
            ),
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter({
    required ValueListenable<double> time,
    required this.sheet,
    required this.petStartOf,
  })  : _time = time,
        super(repaint: time);

  final ValueListenable<double> _time;
  final ui.Image sheet;
  final double Function() petStartOf;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _time.value;
    final frameW = sheet.width / kCodexSheetCols;
    final frameH = sheet.height / kCodexSheetRows;

    var row = kCodexRowIdle;
    var frame =
        ((t % _idleCycleSec) / _idleCycleSec * kCodexSheetCols).floor();
    final petT = t - petStartOf();
    if (petT >= 0 && petT < _waveCycleSec) {
      row = kCodexRowWave;
      frame = (petT / _waveCycleSec * kCodexSheetCols).floor();
    }
    frame = frame.clamp(0, kCodexSheetCols - 1);

    final src = Rect.fromLTWH(frame * frameW, row * frameH, frameW, frameH);
    // 按帧宽高比适配到目标区域（锚定底部居中）。
    final scale = (size.width / frameW < size.height / frameH)
        ? size.width / frameW
        : size.height / frameH;
    final dw = frameW * scale;
    final dh = frameH * scale;
    final dst =
        Rect.fromLTWH((size.width - dw) / 2, size.height - dh, dw, dh);
    canvas.drawImageRect(
      sheet,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _SheetPainter oldDelegate) =>
      oldDelegate.sheet != sheet;
}
