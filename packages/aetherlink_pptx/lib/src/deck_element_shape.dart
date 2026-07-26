// shape 元素：预设几何形状（<p:sp> + <a:prstGeom>）。
part of 'deck_document.dart';

/// Preset shape kinds the writer maps to OOXML preset geometries.
enum DeckShapeKind {
  rect('rect'),
  roundRect('roundRect'),
  ellipse('ellipse'),
  line('line'),
  pie('pie');

  const DeckShapeKind(this.preset);

  /// The `<a:prstGeom prst="...">` value.
  final String preset;

  static DeckShapeKind parse(String? raw, String where) => switch (raw) {
    'rect' => DeckShapeKind.rect,
    'roundRect' => DeckShapeKind.roundRect,
    'ellipse' => DeckShapeKind.ellipse,
    'line' => DeckShapeKind.line,
    'pie' => DeckShapeKind.pie,
    _ => throw DeckParseException(
      '$where 的 shape 必须是 rect/roundRect/ellipse/line/pie：收到 "$raw"',
    ),
  };
}

/// A native shape (`<p:sp>` with a preset geometry).
class DeckShapeElement extends DeckElement {
  const DeckShapeElement({
    required super.frame,
    required this.kind,
    this.fill,
    this.fillTransparency = 0,
    this.lineColor,
    this.lineWidth,
    this.radius,
    this.angleStart,
    this.angleEnd,
  });

  factory DeckShapeElement.fromJson(Map<String, Object?> json, String where) {
    final transparency = (json['fillTransparency'] as num?)?.toInt() ?? 0;
    if (transparency < 0 || transparency > 100) {
      throw DeckParseException('$where 的 fillTransparency 必须在 0-100 之间');
    }
    final lineWidth = json['lineWidth'];
    if (lineWidth != null && (lineWidth is! num || lineWidth <= 0)) {
      throw DeckParseException('$where 的 lineWidth 必须是正数（单位 pt）');
    }
    final radius = json['radius'];
    if (radius != null && (radius is! num || radius < 0 || radius > 0.5)) {
      throw DeckParseException('$where 的 radius 必须在 0-0.5 之间（相对短边比例）');
    }
    final kind = DeckShapeKind.parse(json['shape'] as String?, where);
    final angleStart = json['angleStart'];
    final angleEnd = json['angleEnd'];
    if (kind == DeckShapeKind.pie && (angleStart is! num || angleEnd is! num)) {
      throw DeckParseException(
        '$where 的 pie 形状需要数值 "angleStart"/"angleEnd"（角度，0=3 点钟方向顺时针）',
      );
    }
    return DeckShapeElement(
      frame: DeckFrame.fromJson(json, where),
      kind: kind,
      angleStart: (angleStart as num?)?.toDouble(),
      angleEnd: (angleEnd as num?)?.toDouble(),
      fill: json['fill'] == null ? null : DeckColor(json['fill'] as String),
      fillTransparency: transparency,
      lineColor: json['lineColor'] == null
          ? null
          : DeckColor(json['lineColor'] as String),
      lineWidth: (lineWidth as num?)?.toDouble(),
      radius: (radius as num?)?.toDouble(),
    );
  }

  final DeckShapeKind kind;
  final DeckColor? fill;

  /// 0-100; applied as `<a:alpha>` on the fill, never baked into the hex.
  final int fillTransparency;
  final DeckColor? lineColor;

  /// Outline width in points.
  final double? lineWidth;

  /// Corner radius for [DeckShapeKind.roundRect], as a 0-0.5 fraction of the
  /// shorter side.
  final double? radius;

  /// Wedge angles (degrees, 0 = 3 o'clock, clockwise) for [DeckShapeKind.pie].
  final double? angleStart;
  final double? angleEnd;
}
