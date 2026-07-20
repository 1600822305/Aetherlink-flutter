// 奶龙矢量版：CustomPainter 贝塞尔曲线绘制，任意缩放不糊。
// 照动画原型还原：胖蛋形黄身子（径向渐变）+ 奶白圆肚皮 + 白底大黑
// 眼睛（双高光）+ 张嘴咧笑（口腔 + 粉舌头）+ 橙色脸蛋 + 小手小脚
// 小尾巴 + 鼻孔点。

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'vector_pet.dart';

class NailongVectorArt implements BuddyVectorArt {
  const NailongVectorArt();

  @override
  void paint(
    Canvas canvas,
    Size size, {
    required bool blink,
    required Color Function(Color) tint,
  }) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;

    Color c(int argb) => tint(Color(argb));

    // 尾巴：右下一截上翘的胖尾巴。
    final tail = Path()
      ..moveTo(w * 0.76, h * 0.84)
      ..cubicTo(w * 0.94, h * 0.86, w * 1.00, h * 0.74, w * 0.95, h * 0.64)
      ..cubicTo(w * 0.95, h * 0.76, w * 0.86, h * 0.78, w * 0.74, h * 0.74)
      ..close();
    paint.color = c(0xFFF2B123);
    canvas.drawPath(tail, paint);

    // 身体：头大身小的胖蛋形（头身一体），径向渐变提亮头顶。
    final body = Path()
      ..moveTo(w * 0.50, h * 0.03)
      ..cubicTo(w * 0.80, h * 0.03, w * 0.90, h * 0.22, w * 0.87, h * 0.44)
      ..cubicTo(w * 0.86, h * 0.66, w * 0.82, h * 0.94, w * 0.50, h * 0.94)
      ..cubicTo(w * 0.18, h * 0.94, w * 0.14, h * 0.66, w * 0.13, h * 0.44)
      ..cubicTo(w * 0.10, h * 0.22, w * 0.20, h * 0.03, w * 0.50, h * 0.03)
      ..close();
    paint.shader = ui.Gradient.radial(
      Offset(w * 0.42, h * 0.20),
      w * 0.80,
      [c(0xFFFFD75E), c(0xFFFFC63B), c(0xFFF0AC20)],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawPath(body, paint);
    paint.shader = null;

    // 小手：两侧圆润短臂（略深一点的黄）。
    paint.color = c(0xFFFAC133);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.12, h * 0.62),
          width: w * 0.13,
          height: h * 0.20),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.88, h * 0.62),
          width: w * 0.13,
          height: h * 0.20),
      paint,
    );

    // 小脚：底部两只深黄圆脚。
    paint.color = c(0xFFE59B18);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.35, h * 0.94),
          width: w * 0.20,
          height: h * 0.10),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.65, h * 0.94),
          width: w * 0.20,
          height: h * 0.10),
      paint,
    );

    // 肚皮：奶白大椭圆。
    paint.color = c(0xFFFFF3D0);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.73),
          width: w * 0.46,
          height: h * 0.34),
      paint,
    );

    // 脸蛋：橙色柔光圆。
    paint.color = c(0xFFF59E4A).withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.21, h * 0.36),
          width: w * 0.14,
          height: h * 0.10),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(w * 0.79, h * 0.36),
          width: w * 0.14,
          height: h * 0.10),
      paint,
    );

    // 眼睛：白底 + 大棕黑瞳孔 + 双高光；眨眼画弧线眼睑。
    final eyeLC = Offset(w * 0.35, h * 0.27);
    final eyeRC = Offset(w * 0.65, h * 0.27);
    if (blink) {
      paint
        ..color = c(0xFF4A3A26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round;
      final lidL = Path()
        ..moveTo(eyeLC.dx - w * 0.07, eyeLC.dy)
        ..quadraticBezierTo(
            eyeLC.dx, eyeLC.dy + h * 0.045, eyeLC.dx + w * 0.07, eyeLC.dy);
      final lidR = Path()
        ..moveTo(eyeRC.dx - w * 0.07, eyeRC.dy)
        ..quadraticBezierTo(
            eyeRC.dx, eyeRC.dy + h * 0.045, eyeRC.dx + w * 0.07, eyeRC.dy);
      canvas.drawPath(lidL, paint);
      canvas.drawPath(lidR, paint);
      paint.style = PaintingStyle.fill;
    } else {
      for (final center in [eyeLC, eyeRC]) {
        paint.color = const Color(0xFFFFFFFF);
        canvas.drawOval(
          Rect.fromCenter(
              center: center, width: w * 0.17, height: h * 0.155),
          paint,
        );
        paint.color = c(0xFF3A2A1A);
        canvas.drawOval(
          Rect.fromCenter(
              center: Offset(center.dx, center.dy + h * 0.008),
              width: w * 0.125,
              height: h * 0.125),
          paint,
        );
        paint.color = c(0xFF1E140C);
        canvas.drawCircle(
            Offset(center.dx, center.dy + h * 0.012), w * 0.038, paint);
        paint.color = const Color(0xFFFFFFFF);
        canvas.drawCircle(
            Offset(center.dx + w * 0.028, center.dy - h * 0.022),
            w * 0.022,
            paint);
        paint.color = const Color(0x99FFFFFF);
        canvas.drawCircle(
            Offset(center.dx - w * 0.025, center.dy + h * 0.028),
            w * 0.012,
            paint);
      }
    }

    // 鼻孔：两粒小点。
    paint.color = c(0xFFE0A028);
    canvas.drawCircle(Offset(w * 0.455, h * 0.375), w * 0.011, paint);
    canvas.drawCircle(Offset(w * 0.545, h * 0.375), w * 0.011, paint);

    // 嘴巴：张口咧笑——深色口腔（圆底 D 形）+ 粉舌头。
    final mouth = Path()
      ..moveTo(w * 0.33, h * 0.435)
      ..quadraticBezierTo(w * 0.50, h * 0.415, w * 0.67, h * 0.435)
      ..quadraticBezierTo(w * 0.66, h * 0.56, w * 0.50, h * 0.565)
      ..quadraticBezierTo(w * 0.34, h * 0.56, w * 0.33, h * 0.435)
      ..close();
    paint.color = c(0xFF6B3A1E);
    canvas.drawPath(mouth, paint);
    final tongue = Path()
      ..moveTo(w * 0.39, h * 0.51)
      ..quadraticBezierTo(w * 0.50, h * 0.475, w * 0.61, h * 0.51)
      ..quadraticBezierTo(w * 0.60, h * 0.56, w * 0.50, h * 0.562)
      ..quadraticBezierTo(w * 0.40, h * 0.56, w * 0.39, h * 0.51)
      ..close();
    paint.color = c(0xFFE8788A);
    canvas.drawPath(tongue, paint);
  }
}
