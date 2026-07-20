// 像素宠物动画组件：CustomPainter 渲染 32×32 像素图，Ticker 驱动
// 60fps 补间动画 —— 呼吸起伏、周期眨眼、被摸时挤压回弹 + 爱心粒子，
// 闪光个体金色调 + 星光闪烁。帽子像素图锚定在头顶叠加。

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:aetherlink_flutter/features/buddy/domain/buddy_types.dart';
import 'package:aetherlink_flutter/features/buddy/domain/pixel_arts/pixel_arts.dart';
import 'package:aetherlink_flutter/features/buddy/presentation/vector_pets/vector_pet.dart';

/// 眨眼周期：每 ~3.7s 闭眼 0.15s。
const double _blinkCycle = 3.7;
const double _blinkLen = 0.15;

/// 呼吸（起伏 + 纵向缩放）周期。
const double _breathCycle = 2.4;

/// 被摸动画总时长（挤压回弹 0.6s，爱心上浮 1.4s）。
const double _squashLen = 0.6;
const double _heartsLen = 1.4;

/// 像素宠物。[petTrigger] 每次递增触发一次「被摸」动画。
class BuddyPixelPet extends StatefulWidget {
  const BuddyPixelPet({
    super.key,
    required this.bones,
    this.size = 128,
    this.petTrigger = 0,
  });

  final BuddyBones bones;
  final double size;
  final int petTrigger;

  @override
  State<BuddyPixelPet> createState() => _BuddyPixelPetState();
}

class _BuddyPixelPetState extends State<BuddyPixelPet>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  double _petStart = -100;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    })
      ..start();
  }

  @override
  void didUpdateWidget(covariant BuddyPixelPet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.petTrigger != oldWidget.petTrigger) {
      _petStart = _time.value;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _PetPainter(
          time: _time,
          bones: widget.bones,
          petStartOf: () => _petStart,
        ),
      ),
    );
  }
}

/// 静态像素图渲染（孵化蛋等非宠物图用）。
class BuddyPixelArtView extends StatelessWidget {
  const BuddyPixelArtView({super.key, required this.art, this.size = 96});

  final BuddyPixelArt art;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StaticArtPainter(art)),
    );
  }
}

class _StaticArtPainter extends CustomPainter {
  _StaticArtPainter(this.art);

  final BuddyPixelArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final cols = art.rows.first.length;
    final px = size.width / cols;
    final paint = Paint();
    for (var r = 0; r < art.rows.length; r++) {
      final row = art.rows[r];
      for (var c = 0; c < row.length; c++) {
        final ch = row[c];
        if (ch == '.') continue;
        paint.color = Color(art.palette[ch] ?? 0xFF000000);
        canvas.drawRect(
          Rect.fromLTWH(c * px, r * px, px, px).inflate(0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StaticArtPainter oldDelegate) =>
      oldDelegate.art != art;
}

class _PetPainter extends CustomPainter {
  _PetPainter({
    required ValueListenable<double> time,
    required this.bones,
    required this.petStartOf,
  })  : _time = time,
        super(repaint: time);

  final ValueListenable<double> _time;
  final BuddyBones bones;
  final double Function() petStartOf;

  static final Map<BuddySpecies, int> _bodyColorCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final art = kBuddyPixelArts[bones.species]!;
    final t = _time.value;
    final cols = art.rows.first.length;
    final rows = art.rows.length;
    final px = size.width / cols;

    final petT = t - petStartOf();
    final squashing = petT >= 0 && petT < _squashLen;

    // 呼吸：轻微起伏 + 纵向缩放（锚定底部）。
    final breath = sin(t * 2 * pi / _breathCycle);
    var scaleY = 1 + 0.015 * breath;
    var scaleX = 1 - 0.008 * breath;
    var bob = -0.12 * px * (breath + 1) / 2;

    // 被摸：挤压回弹（覆盖呼吸）。
    if (squashing) {
      final k = sin(pi * petT / _squashLen);
      scaleY = 1 - 0.18 * k;
      scaleX = 1 + 0.12 * k;
      bob = 0;
    }

    canvas.save();
    canvas.translate(size.width / 2, size.height + bob);
    canvas.scale(scaleX, scaleY);
    canvas.translate(-size.width / 2, -size.height);

    final blink = (t % _blinkCycle) < _blinkLen;
    final bodyColor = _bodyColor(art);
    final paint = Paint();

    // 有矢量版的物种优先用矢量渲染（任意缩放不糊）。
    final vector = kBuddyVectorArts[bones.species];
    if (vector != null) {
      vector.paint(canvas, size, blink: blink, tint: _tint);
      _paintVectorHat(canvas, size, paint);
      canvas.restore();
      if (bones.shiny) _paintSparkles(canvas, size, t, paint);
      if (petT >= 0 && petT < _heartsLen) {
        _paintHearts(canvas, size, petT / _heartsLen, paint);
      }
      return;
    }

    for (var r = 0; r < rows; r++) {
      final row = art.rows[r];
      for (var c = 0; c < cols; c++) {
        final ch = row[c];
        if (ch == '.') continue;
        var color = art.palette[ch] ?? 0xFF000000;
        final isEye = ch == 'E';
        if (isEye && blink) color = bodyColor;
        paint.color = _tint(Color(color));
        final rect = Rect.fromLTWH(c * px, r * px, px, px).inflate(0.5);
        canvas.drawRect(rect, paint);
        if (isEye && blink) {
          // 闭眼：眼睛区域下缘画一条深色眼睑线。
          paint.color = _tint(Color(art.palette['E'] ?? kBuddyEyeColor));
          canvas.drawRect(
            Rect.fromLTWH(c * px, (r + 0.7) * px, px, px * 0.3).inflate(0.25),
            paint,
          );
        }
      }
    }

    // 眼睛高光：每片眼睛区域左上角一粒白点（睁眼时）。
    if (!blink) {
      paint.color = const Color(0xCCFFFFFF);
      for (final cell in _eyeHighlights(art)) {
        canvas.drawRect(
          Rect.fromLTWH(cell.$2 * px + px * 0.15, cell.$1 * px + px * 0.15,
              px * 0.4, px * 0.4),
          paint,
        );
      }
    }

    _paintHat(canvas, art, px, paint);

    canvas.restore();

    // 闪光个体：金色星光在四周闪烁。
    if (bones.shiny) _paintSparkles(canvas, size, t, paint);

    // 被摸：爱心粒子上浮渐隐。
    if (petT >= 0 && petT < _heartsLen) {
      _paintHearts(canvas, size, petT / _heartsLen, paint);
    }
  }

  /// 矢量物种的帽子：仍用帽子像素图，按 32 格居中压在头顶。
  void _paintVectorHat(Canvas canvas, Size size, Paint paint) {
    if (bones.hat == BuddyHat.none) return;
    final hat = kBuddyHatArts[bones.hat];
    if (hat == null) return;
    final px = size.width / 32;
    final hatW = hat.rows.first.length;
    final hatH = hat.rows.length;
    final startC = (16 - hatW / 2).round();
    final lift = bones.hat == BuddyHat.halo ? 2 : 1;
    final startR = 1 - hatH + lift;
    for (var r = 0; r < hatH; r++) {
      final row = hat.rows[r];
      for (var c = 0; c < row.length; c++) {
        final ch = row[c];
        if (ch == '.') continue;
        paint.color = _tint(Color(hat.palette[ch] ?? 0xFF000000));
        canvas.drawRect(
          Rect.fromLTWH((startC + c) * px, (startR + r) * px, px, px)
              .inflate(0.5),
          paint,
        );
      }
    }
  }

  void _paintHat(Canvas canvas, BuddyPixelArt art, double px, Paint paint) {
    if (bones.hat == BuddyHat.none) return;
    final hat = kBuddyHatArts[bones.hat];
    if (hat == null) return;

    // 头顶锚点：第一行非透明像素，取其上两行内的身体横跨范围居中。
    var topRow = 0;
    outer:
    for (var r = 0; r < art.rows.length; r++) {
      for (final ch in art.rows[r].split('')) {
        if (ch != '.') {
          topRow = r;
          break outer;
        }
      }
    }
    var minC = art.rows.first.length;
    var maxC = 0;
    for (var r = topRow; r < topRow + 3 && r < art.rows.length; r++) {
      final row = art.rows[r];
      for (var c = 0; c < row.length; c++) {
        if (row[c] != '.') {
          minC = min(minC, c);
          maxC = max(maxC, c);
        }
      }
    }
    final hatW = hat.rows.first.length;
    final hatH = hat.rows.length;
    final startC = ((minC + maxC + 1) / 2 - hatW / 2).round();
    // 帽子底行压在头顶行上；光环悬空一格。
    final lift = bones.hat == BuddyHat.halo ? 2 : 1;
    final startR = topRow - hatH + lift;

    for (var r = 0; r < hatH; r++) {
      final row = hat.rows[r];
      for (var c = 0; c < row.length; c++) {
        final ch = row[c];
        if (ch == '.') continue;
        paint.color = _tint(Color(hat.palette[ch] ?? 0xFF000000));
        canvas.drawRect(
          Rect.fromLTWH((startC + c) * px, (startR + r) * px, px, px)
              .inflate(0.5),
          paint,
        );
      }
    }
  }

  void _paintSparkles(Canvas canvas, Size size, double t, Paint paint) {
    const positions = [
      Offset(0.12, 0.22),
      Offset(0.88, 0.15),
      Offset(0.08, 0.65),
      Offset(0.92, 0.58),
    ];
    for (var i = 0; i < positions.length; i++) {
      final phase = (t / 1.6 + i * 0.25) % 1;
      final a = (sin(phase * pi)).clamp(0.0, 1.0);
      if (a < 0.05) continue;
      paint.color = Color.fromARGB((a * 230).round(), 255, 224, 130);
      final o = Offset(
          positions[i].dx * size.width, positions[i].dy * size.height);
      final s = size.width * 0.025 * (0.7 + 0.6 * a);
      // 四角星：横竖两条短杠。
      canvas.drawRect(
          Rect.fromCenter(center: o, width: s * 3, height: s), paint);
      canvas.drawRect(
          Rect.fromCenter(center: o, width: s, height: s * 3), paint);
    }
  }

  void _paintHearts(Canvas canvas, Size size, double progress, Paint paint) {
    const xs = [0.2, 0.42, 0.62, 0.8, 0.5];
    for (var i = 0; i < xs.length; i++) {
      final delay = i * 0.08;
      final p = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final a = (1 - p).clamp(0.0, 1.0);
      paint.color = Color.fromARGB((a * 255).round(), 236, 72, 153);
      final x = xs[i] * size.width + sin((p + i) * 6) * size.width * 0.02;
      final y = size.height * 0.35 - p * size.height * 0.4;
      final s = size.width * 0.035;
      // 像素小爱心：两点 + 底部一点。
      canvas.drawRect(Rect.fromLTWH(x - s, y - s, s, s), paint);
      canvas.drawRect(Rect.fromLTWH(x, y - s, s, s), paint);
      canvas.drawRect(
          Rect.fromLTWH(x - s * 1.5, y, s * 3, s), paint);
      canvas.drawRect(Rect.fromLTWH(x - s * 0.5, y + s, s, s), paint);
    }
  }

  /// 闪光个体整体向金色偏移。
  Color _tint(Color color) {
    if (!bones.shiny) return color;
    return Color.lerp(color, const Color(0xFFF2C14E), 0.3)!;
  }

  /// 身体主色 = 像素图中出现最多的非眼睛/腮红颜色（眨眼时填眼睛用）。
  int _bodyColor(BuddyPixelArt art) {
    return _bodyColorCache.putIfAbsent(bones.species, () {
      final counts = <String, int>{};
      for (final row in art.rows) {
        for (final ch in row.split('')) {
          if (ch == '.' || ch == 'E' || ch == 'p') continue;
          counts[ch] = (counts[ch] ?? 0) + 1;
        }
      }
      if (counts.isEmpty) return 0xFF888888;
      final top =
          counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return art.palette[top] ?? 0xFF888888;
    });
  }

  /// 每片连续眼睛区域的左上角像素（画高光用）。
  List<(int, int)> _eyeHighlights(BuddyPixelArt art) {
    final cells = <(int, int)>[];
    for (var r = 0; r < art.rows.length; r++) {
      final row = art.rows[r];
      for (var c = 0; c < row.length; c++) {
        if (row[c] != 'E') continue;
        final leftE = c > 0 && row[c - 1] == 'E';
        final upE = r > 0 &&
            c < art.rows[r - 1].length &&
            art.rows[r - 1][c] == 'E';
        if (!leftE && !upE) cells.add((r, c));
      }
    }
    return cells;
  }

  @override
  bool shouldRepaint(covariant _PetPainter oldDelegate) =>
      oldDelegate.bones != bones;
}
