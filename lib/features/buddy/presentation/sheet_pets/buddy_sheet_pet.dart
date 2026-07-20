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

/// 内置 Codex 精灵图的物种映射（asset 路径）。奶龙已改用统一的
/// 64×64 像素风内置版，想要官方动画可用 Codex 皮肤导入。
const Map<String, String> kBuddyBuiltinSheetAssets = {};

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
  List<int> _frameCounts = const [];
  ImageStream? _stream;
  late final ImageStreamListener _listener =
      ImageStreamListener((info, _) {
    _onSheet(info.image);
  });

  /// 很多官方包的行不满 8 帧（剩余格子全透明），直接按 8 帧播会
  /// 闪现空白——加载时扫一遍 alpha，统计每行实际有效帧数。
  Future<void> _onSheet(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final counts = List<int>.filled(kCodexSheetRows, kCodexSheetCols);
    if (data != null) {
      final fw = image.width ~/ kCodexSheetCols;
      final fh = image.height ~/ kCodexSheetRows;
      bool frameEmpty(int row, int col) {
        for (var y = row * fh; y < (row + 1) * fh; y += 4) {
          for (var x = col * fw; x < (col + 1) * fw; x += 4) {
            if (data.getUint8((y * image.width + x) * 4 + 3) > 10) {
              return false;
            }
          }
        }
        return true;
      }

      for (var r = 0; r < kCodexSheetRows; r++) {
        var n = kCodexSheetCols;
        while (n > 1 && frameEmpty(r, n - 1)) {
          n--;
        }
        counts[r] = n;
      }
    }
    if (!mounted) return;
    setState(() {
      _sheet = image;
      _frameCounts = counts;
    });
  }

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
                frameCounts: _frameCounts,
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
    required this.frameCounts,
    required this.petStartOf,
  })  : _time = time,
        super(repaint: time);

  final ValueListenable<double> _time;
  final ui.Image sheet;
  final List<int> frameCounts;
  final double Function() petStartOf;

  int _framesOf(int row) =>
      row < frameCounts.length ? frameCounts[row] : kCodexSheetCols;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _time.value;
    final frameW = sheet.width / kCodexSheetCols;
    final frameH = sheet.height / kCodexSheetRows;

    var row = kCodexRowIdle;
    var frames = _framesOf(row);
    var frame = ((t % _idleCycleSec) / _idleCycleSec * frames).floor();
    final petT = t - petStartOf();
    if (petT >= 0 && petT < _waveCycleSec) {
      row = kCodexRowWave;
      frames = _framesOf(row);
      frame = (petT / _waveCycleSec * frames).floor();
    }
    frame = frame.clamp(0, frames - 1);

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
      oldDelegate.sheet != sheet || oldDelegate.frameCounts != frameCounts;
}
