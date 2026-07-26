/// Bento 布局引擎：把页级 `"layout": {"type": ..., "cards": [...]}` 声明编译成
/// 绝对定位的原生元素（卡片圆角矩形 + 文本 + 装饰形状）。卡片定位、间距、
/// 边界由引擎保证 —— agent 只填内容，从源头消灭 out_of_bounds/间距不一致。
///
/// 内容页布局 7 种（focus/split/asymmetric/columns/hierarchy/hero/grid）+
/// 页型 4 种（cover/toc/section/end），卡片 6 类型
/// （text/data/list/tags/process/big_number），对齐 Akxan Bento Grid 体系。
library;

import 'deck_document.dart';
import 'deck_style.dart';

const double _kMargin = 0.42;
const double _kGap = 0.21;
const double _kTitleH = 0.62;
const double _kPad = 0.25;

/// Fallback palette when the deck has no style（对齐 writer 默认图表色板）.
const List<String> _kFallbackAccents = ['4472C4', 'ED7D31', 'FFC000', '70AD47'];

class _Palette {
  _Palette(DeckStyle? style)
    : background = style?.background ?? const DeckColor.raw('FFFFFF'),
      cardFill = style?.cardFill ?? const DeckColor.raw('F5F7FA'),
      cardBorder = style?.cardBorder,
      cardRadius = style?.cardRadius ?? 0.09,
      textPrimary = style?.textPrimary ?? const DeckColor.raw('1A1A1A'),
      textSecondary = style?.textSecondary ?? const DeckColor.raw('666666'),
      accents = style == null
          ? [for (final a in _kFallbackAccents) DeckColor.raw(a)]
          : style.accents,
      titleSize = style?.titleSize ?? 28,
      bodySize = style?.bodySize ?? 14,
      cardTitleSize = style?.cardTitleSize ?? 18,
      font = style?.bodyFont;

  final DeckColor background;
  final DeckColor cardFill;
  final DeckColor? cardBorder;
  final double cardRadius;
  final DeckColor textPrimary;
  final DeckColor textSecondary;
  final List<DeckColor> accents;
  final double titleSize;
  final double bodySize;
  final double cardTitleSize;
  final String? font;

  DeckColor accent(int i) => accents[i % accents.length];
}

/// Compiles one slide-level layout declaration into elements.
List<DeckElement> buildLayoutElements(
  Map<String, Object?> json,
  DeckLayout canvas,
  DeckStyle? style,
  String where,
) {
  final type = json['type'];
  if (type is! String) {
    throw DeckParseException(
      '$where.layout 缺少字符串字段 "type"'
      '（cover/toc/section/end/focus/split/asymmetric/columns/hierarchy/hero/grid）',
    );
  }
  final p = _Palette(style);
  final w = canvas.widthInches;
  final h = canvas.heightInches;
  return switch (type) {
    'cover' => _cover(json, w, h, p, where),
    'section' => _section(json, w, h, p, where),
    'end' => _end(json, w, h, p, where),
    'toc' => _toc(json, w, h, p, where),
    'focus' ||
    'split' ||
    'asymmetric' ||
    'columns' ||
    'hierarchy' ||
    'hero' ||
    'grid' => _contentPage(type, json, w, h, p, where),
    _ => throw DeckParseException(
      '$where.layout 未知 type "$type"（支持 cover/toc/section/end/'
      'focus/split/asymmetric/columns/hierarchy/hero/grid）',
    ),
  };
}

String _reqString(Map<String, Object?> json, String key, String where) {
  final v = json[key];
  if (v is! String || v.isEmpty) {
    throw DeckParseException('$where 缺少非空字符串 "$key"');
  }
  return v;
}

DeckTextElement _text(
  DeckFrame frame,
  List<(String, double, DeckColor, bool)> lines, {
  String? align,
  String? valign,
  String? font,
  bool bullet = false,
  double? lineSpacing,
}) => DeckTextElement(
  frame: frame,
  valign: valign,
  lineSpacing: lineSpacing,
  paragraphs: [
    for (final (text, size, color, bold) in lines)
      DeckParagraph(
        align: align,
        bullet: bullet,
        runs: [
          DeckTextRun(
            text: text,
            size: size,
            color: color,
            bold: bold,
            font: font,
          ),
        ],
      ),
  ],
);

DeckShapeElement _card(DeckFrame frame, _Palette p, {DeckColor? fill}) =>
    DeckShapeElement(
      frame: frame,
      kind: p.cardRadius <= 0 ? DeckShapeKind.rect : DeckShapeKind.roundRect,
      fill: fill ?? p.cardFill,
      lineColor: p.cardBorder,
      lineWidth: p.cardBorder == null ? null : 1,
      radius: p.cardRadius <= 0 ? null : p.cardRadius,
    );

// ── 页型 ──

List<DeckElement> _cover(
  Map<String, Object?> json,
  double w,
  double h,
  _Palette p,
  String where,
) {
  final title = _reqString(json, 'title', '$where.layout');
  final subtitle = json['subtitle'] as String?;
  final meta = json['meta'] as String?;
  return [
    DeckShapeElement(
      frame: DeckFrame(x: _kMargin, y: h * 0.34, w: 0.9, h: 0.07),
      kind: DeckShapeKind.rect,
      fill: p.accent(0),
    ),
    _text(
      DeckFrame(x: _kMargin, y: h * 0.40, w: w - _kMargin * 2, h: 1.4),
      [(title, 44, p.textPrimary, true)],
      font: p.font,
      valign: 'middle',
    ),
    if (subtitle != null)
      _text(
        DeckFrame(x: _kMargin, y: h * 0.40 + 1.45, w: w - _kMargin * 2, h: 0.6),
        [(subtitle, 20, p.textSecondary, false)],
        font: p.font,
      ),
    if (meta != null)
      _text(
        DeckFrame(
          x: _kMargin,
          y: h - _kMargin - 0.4,
          w: w - _kMargin * 2,
          h: 0.4,
        ),
        [(meta, 13, p.textSecondary, false)],
        font: p.font,
        valign: 'bottom',
      ),
  ];
}

List<DeckElement> _section(
  Map<String, Object?> json,
  double w,
  double h,
  _Palette p,
  String where,
) {
  final title = _reqString(json, 'title', '$where.layout');
  final label = json['label'] as String?;
  final lead = json['lead'] as String?;
  return [
    if (label != null)
      _text(
        DeckFrame(x: _kMargin, y: h * 0.32, w: w - _kMargin * 2, h: 0.45),
        [(label, 16, p.accent(0), true)],
        font: p.font,
        align: 'center',
      ),
    _text(
      DeckFrame(x: _kMargin, y: h * 0.40, w: w - _kMargin * 2, h: 1.1),
      [(title, 38, p.textPrimary, true)],
      font: p.font,
      align: 'center',
      valign: 'middle',
    ),
    if (lead != null)
      _text(
        DeckFrame(x: w * 0.2, y: h * 0.40 + 1.2, w: w * 0.6, h: 0.8),
        [(lead, 15, p.textSecondary, false)],
        font: p.font,
        align: 'center',
      ),
  ];
}

List<DeckElement> _end(
  Map<String, Object?> json,
  double w,
  double h,
  _Palette p,
  String where,
) {
  final title = _reqString(json, 'title', '$where.layout');
  final items = _stringList(json['items'], '$where.layout.items');
  final meta = json['meta'] as String?;
  return [
    _text(
      DeckFrame(x: _kMargin, y: h * 0.26, w: w - _kMargin * 2, h: 1.0),
      [(title, 38, p.textPrimary, true)],
      font: p.font,
      align: 'center',
      valign: 'middle',
    ),
    if (items.isNotEmpty)
      _text(
        DeckFrame(
          x: w * 0.25,
          y: h * 0.26 + 1.2,
          w: w * 0.5,
          h: items.length * 0.42,
        ),
        [for (final it in items) (it, 15, p.textSecondary, false)],
        font: p.font,
        align: 'center',
        lineSpacing: 1.3,
      ),
    if (meta != null)
      _text(
        DeckFrame(
          x: _kMargin,
          y: h - _kMargin - 0.4,
          w: w - _kMargin * 2,
          h: 0.4,
        ),
        [(meta, 13, p.textSecondary, false)],
        font: p.font,
        align: 'center',
        valign: 'bottom',
      ),
  ];
}

List<DeckElement> _toc(
  Map<String, Object?> json,
  double w,
  double h,
  _Palette p,
  String where,
) {
  final title = (json['title'] as String?) ?? '目录';
  final items = _stringList(json['items'], '$where.layout.items');
  if (items.length < 2 || items.length > 6) {
    throw DeckParseException('$where.layout(toc) 的 items 需要 2-6 条');
  }
  final elements = <DeckElement>[..._titleBar(title, w, p)];
  final frames = _gridFrames(items.length, w, h, columnsForCount(items.length));
  for (final (i, frame) in frames.indexed) {
    elements
      ..add(_card(frame, p))
      ..add(
        _text(
          DeckFrame(
            x: frame.x + _kPad,
            y: frame.y + _kPad,
            w: frame.w - _kPad * 2,
            h: 0.5,
          ),
          [('0${i + 1}', 22, p.accent(i), true)],
          font: p.font,
        ),
      )
      ..add(
        _text(
          DeckFrame(
            x: frame.x + _kPad,
            y: frame.y + _kPad + 0.55,
            w: frame.w - _kPad * 2,
            h: frame.h - _kPad * 2 - 0.55,
          ),
          [(items[i], p.cardTitleSize, p.textPrimary, true)],
          font: p.font,
        ),
      );
  }
  return elements;
}

int columnsForCount(int n) => switch (n) {
  <= 3 => n,
  4 => 2,
  _ => 3,
};

// ── 内容页 ──

List<DeckElement> _titleBar(String title, double w, _Palette p) => [
  DeckShapeElement(
    frame: const DeckFrame(x: _kMargin, y: 0.30, w: 0.07, h: 0.42),
    kind: DeckShapeKind.rect,
    fill: p.accent(0),
  ),
  _text(
    DeckFrame(
      x: _kMargin + 0.18,
      y: 0.21,
      w: w - _kMargin * 2 - 0.18,
      h: _kTitleH,
    ),
    [(title, p.titleSize * 0.8, p.textPrimary, true)],
    font: p.font,
    valign: 'middle',
  ),
];

/// Card frames for the 7 content layouts within the content area.
List<DeckFrame> layoutCardFrames(String type, int n, double w, double h) {
  final x = _kMargin;
  final y = 0.21 + _kTitleH + 0.18;
  final cw = w - _kMargin * 2;
  final ch = h - y - _kMargin;
  List<DeckFrame> cols(List<double> weights) {
    final totalGap = _kGap * (weights.length - 1);
    final unit = (cw - totalGap) / weights.fold<double>(0, (a, b) => a + b);
    final frames = <DeckFrame>[];
    var cx = x;
    for (final wt in weights) {
      frames.add(DeckFrame(x: cx, y: y, w: unit * wt, h: ch));
      cx += unit * wt + _kGap;
    }
    return frames;
  }

  switch (type) {
    case 'focus':
      _requireCount(type, n, 1, 1);
      return [DeckFrame(x: x, y: y, w: cw, h: ch)];
    case 'split':
      _requireCount(type, n, 2, 2);
      return cols([1, 1]);
    case 'asymmetric':
      _requireCount(type, n, 2, 2);
      return cols([2, 1]);
    case 'columns':
      _requireCount(type, n, 3, 3);
      return cols([1, 1, 1]);
    case 'hierarchy':
      _requireCount(type, n, 3, 3);
      final mainW = (cw - _kGap) * 2 / 3;
      final sideW = cw - _kGap - mainW;
      final sideH = (ch - _kGap) / 2;
      return [
        DeckFrame(x: x, y: y, w: mainW, h: ch),
        DeckFrame(x: x + mainW + _kGap, y: y, w: sideW, h: sideH),
        DeckFrame(
          x: x + mainW + _kGap,
          y: y + sideH + _kGap,
          w: sideW,
          h: sideH,
        ),
      ];
    case 'hero':
      _requireCount(type, n, 3, 5);
      final heroH = ch * 0.42;
      final subN = n - 1;
      final subW = (cw - _kGap * (subN - 1)) / subN;
      return [
        DeckFrame(x: x, y: y, w: cw, h: heroH),
        for (var i = 0; i < subN; i++)
          DeckFrame(
            x: x + i * (subW + _kGap),
            y: y + heroH + _kGap,
            w: subW,
            h: ch - heroH - _kGap,
          ),
      ];
    case 'grid':
      _requireCount(type, n, 4, 6);
      final colsN = n <= 4 ? 2 : 3;
      return _gridFramesIn(n, x, y, cw, ch, colsN);
    default:
      throw DeckParseException('未知内容布局 "$type"');
  }
}

void _requireCount(String type, int n, int min, int max) {
  if (n < min || n > max) {
    throw DeckParseException(
      'layout "$type" 需要 $min${min == max ? '' : '-$max'} 张卡片，收到 $n',
    );
  }
}

List<DeckFrame> _gridFrames(int n, double w, double h, int colsN) {
  final y = 0.21 + _kTitleH + 0.18;
  return _gridFramesIn(
    n,
    _kMargin,
    y,
    w - _kMargin * 2,
    h - y - _kMargin,
    colsN,
  );
}

List<DeckFrame> _gridFramesIn(
  int n,
  double x,
  double y,
  double cw,
  double ch,
  int colsN,
) {
  final rows = (n + colsN - 1) ~/ colsN;
  final cellW = (cw - _kGap * (colsN - 1)) / colsN;
  final cellH = (ch - _kGap * (rows - 1)) / rows;
  final frames = <DeckFrame>[];
  for (var i = 0; i < n; i++) {
    final r = i ~/ colsN;
    final c = i % colsN;
    // 最后一行不满时居中。
    final inLastRow = r == rows - 1;
    final lastRowCount = n - (rows - 1) * colsN;
    final offset = inLastRow && lastRowCount < colsN
        ? (cw - (cellW * lastRowCount + _kGap * (lastRowCount - 1))) / 2
        : 0.0;
    frames.add(
      DeckFrame(
        x: x + offset + c * (cellW + _kGap),
        y: y + r * (cellH + _kGap),
        w: cellW,
        h: cellH,
      ),
    );
  }
  return frames;
}

List<DeckElement> _contentPage(
  String type,
  Map<String, Object?> json,
  double w,
  double h,
  _Palette p,
  String where,
) {
  final title = _reqString(json, 'title', '$where.layout');
  final rawCards = json['cards'];
  if (rawCards is! List || rawCards.isEmpty) {
    throw DeckParseException('$where.layout 缺少非空数组 "cards"');
  }
  final frames = layoutCardFrames(type, rawCards.length, w, h);
  final elements = <DeckElement>[..._titleBar(title, w, p)];
  for (final (i, raw) in rawCards.indexed) {
    if (raw is! Map) {
      throw DeckParseException('$where.layout.cards[$i] 必须是 JSON 对象');
    }
    elements.addAll(
      _cardElements(
        raw.cast<String, Object?>(),
        frames[i],
        p,
        i,
        '$where.layout.cards[$i]',
      ),
    );
  }
  return elements;
}

// ── 6 种卡片类型 ──

List<String> _stringList(Object? raw, String where) {
  if (raw == null) return const [];
  if (raw is! List || raw.any((e) => e is! String)) {
    throw DeckParseException('$where 必须是字符串数组');
  }
  return raw.cast<String>();
}

List<DeckElement> _cardElements(
  Map<String, Object?> json,
  DeckFrame f,
  _Palette p,
  int index,
  String where,
) {
  final type = (json['type'] as String?) ?? 'text';
  final accent = p.accent(index);
  final inner = DeckFrame(
    x: f.x + _kPad,
    y: f.y + _kPad,
    w: f.w - _kPad * 2,
    h: f.h - _kPad * 2,
  );
  final elements = <DeckElement>[_card(f, p)];
  switch (type) {
    case 'text':
      final title = json['title'] as String?;
      final body = _stringList(json['body'], '$where.body');
      if (body.isEmpty) {
        throw DeckParseException('$where(text) 缺少非空数组 "body"（段落）');
      }
      var top = inner.y;
      if (title != null) {
        elements.add(
          _text(DeckFrame(x: inner.x, y: top, w: inner.w, h: 0.42), [
            (title, p.cardTitleSize, accent, true),
          ], font: p.font),
        );
        top += 0.52;
      }
      elements.add(
        _text(
          DeckFrame(x: inner.x, y: top, w: inner.w, h: inner.y + inner.h - top),
          [for (final b in body) (b, p.bodySize, p.textPrimary, false)],
          font: p.font,
          lineSpacing: 1.35,
        ),
      );
    case 'data':
      final value = _reqString(json, 'value', '$where(data)');
      final label = json['label'] as String?;
      final desc = json['desc'] as String?;
      elements
        ..add(
          _text(DeckFrame(x: inner.x, y: inner.y, w: inner.w, h: 0.85), [
            (value, 38, accent, true),
          ], font: p.font),
        )
        ..add(
          _text(DeckFrame(x: inner.x, y: inner.y + 0.9, w: inner.w, h: 0.4), [
            (label ?? '', p.bodySize, p.textSecondary, false),
          ], font: p.font),
        );
      if (desc != null) {
        elements.add(
          _text(
            DeckFrame(
              x: inner.x,
              y: inner.y + 1.35,
              w: inner.w,
              h: inner.h - 1.35,
            ),
            [(desc, p.bodySize - 1, p.textPrimary, false)],
            font: p.font,
            lineSpacing: 1.3,
          ),
        );
      }
    case 'list':
      final title = json['title'] as String?;
      final items = _stringList(json['items'], '$where.items');
      if (items.length < 2) {
        throw DeckParseException('$where(list) 的 items 至少 2 条');
      }
      var top = inner.y;
      if (title != null) {
        elements.add(
          _text(DeckFrame(x: inner.x, y: top, w: inner.w, h: 0.42), [
            (title, p.cardTitleSize, accent, true),
          ], font: p.font),
        );
        top += 0.52;
      }
      elements.add(
        DeckTextElement(
          frame: DeckFrame(
            x: inner.x,
            y: top,
            w: inner.w,
            h: inner.y + inner.h - top,
          ),
          lineSpacing: 1.4,
          paragraphs: [
            for (final it in items)
              DeckParagraph(
                bullet: true,
                runs: [
                  DeckTextRun(
                    text: it,
                    size: p.bodySize,
                    color: p.textPrimary,
                    font: p.font,
                  ),
                ],
              ),
          ],
        ),
      );
    case 'tags':
      final title = json['title'] as String?;
      final tags = _stringList(json['tags'], '$where.tags');
      if (tags.length < 3) {
        throw DeckParseException('$where(tags) 的 tags 至少 3 个');
      }
      var top = inner.y;
      if (title != null) {
        elements.add(
          _text(DeckFrame(x: inner.x, y: top, w: inner.w, h: 0.42), [
            (title, p.cardTitleSize, accent, true),
          ], font: p.font),
        );
        top += 0.55;
      }
      const tagH = 0.34;
      var tx = inner.x;
      var ty = top;
      for (final (ti, tag) in tags.indexed) {
        final tagW = 0.28 + tag.length * 0.15;
        if (tx + tagW > inner.x + inner.w && tx > inner.x) {
          tx = inner.x;
          ty += tagH + 0.12;
        }
        if (ty + tagH > inner.y + inner.h) break;
        elements
          ..add(
            DeckShapeElement(
              frame: DeckFrame(x: tx, y: ty, w: tagW, h: tagH),
              kind: DeckShapeKind.roundRect,
              fill: p.accent(ti),
              fillTransparency: 82,
              lineColor: p.accent(ti),
              lineWidth: 1,
              radius: 0.5,
            ),
          )
          ..add(
            _text(
              DeckFrame(x: tx, y: ty + 0.03, w: tagW, h: tagH - 0.06),
              [(tag, p.bodySize - 2, p.textPrimary, false)],
              font: p.font,
              align: 'center',
              valign: 'middle',
            ),
          );
        tx += tagW + 0.12;
      }
    case 'process':
      final title = json['title'] as String?;
      final steps = _stringList(json['steps'], '$where.steps');
      if (steps.length < 3) {
        throw DeckParseException('$where(process) 的 steps 至少 3 步');
      }
      var top = inner.y;
      if (title != null) {
        elements.add(
          _text(DeckFrame(x: inner.x, y: top, w: inner.w, h: 0.42), [
            (title, p.cardTitleSize, accent, true),
          ], font: p.font),
        );
        top += 0.55;
      }
      const dot = 0.34;
      final stepH = (inner.y + inner.h - top) / steps.length;
      for (final (si, step) in steps.indexed) {
        final cy = top + si * stepH;
        if (si < steps.length - 1) {
          elements.add(
            DeckShapeElement(
              frame: DeckFrame(
                x: inner.x + dot / 2 - 0.012,
                y: cy + dot,
                w: 0.024,
                h: stepH - dot,
              ),
              kind: DeckShapeKind.rect,
              fill: p.accent(index),
              fillTransparency: 55,
            ),
          );
        }
        elements
          ..add(
            DeckShapeElement(
              frame: DeckFrame(x: inner.x, y: cy, w: dot, h: dot),
              kind: DeckShapeKind.ellipse,
              fill: accent,
            ),
          )
          ..add(
            _text(
              DeckFrame(x: inner.x, y: cy + 0.02, w: dot, h: dot - 0.04),
              [
                (
                  '${si + 1}',
                  p.bodySize - 2,
                  const DeckColor.raw('FFFFFF'),
                  true,
                ),
              ],
              font: p.font,
              align: 'center',
              valign: 'middle',
            ),
          )
          ..add(
            _text(
              DeckFrame(
                x: inner.x + dot + 0.16,
                y: cy,
                w: inner.w - dot - 0.16,
                h: stepH,
              ),
              [(step, p.bodySize, p.textPrimary, false)],
              font: p.font,
              valign: si == steps.length - 1 ? 'top' : 'top',
            ),
          );
      }
    case 'big_number':
      final value = _reqString(json, 'value', '$where(big_number)');
      final label = json['label'] as String?;
      elements.add(
        _text(
          DeckFrame(
            x: inner.x,
            y: inner.y,
            w: inner.w,
            h: label == null ? inner.h : inner.h - 0.5,
          ),
          [(value, 54, accent, true)],
          font: p.font,
          align: 'center',
          valign: 'middle',
        ),
      );
      if (label != null) {
        elements.add(
          _text(
            DeckFrame(
              x: inner.x,
              y: inner.y + inner.h - 0.5,
              w: inner.w,
              h: 0.5,
            ),
            [(label, p.bodySize, p.textSecondary, false)],
            font: p.font,
            align: 'center',
          ),
        );
      }
    default:
      throw DeckParseException(
        '$where 未知卡片 type "$type"'
        '（支持 text/data/list/tags/process/big_number）',
      );
  }
  return elements;
}

// ── 形状合成图表（infographic）──

/// Expands an `{"type": "infographic", "kind": ...}` element into editable
/// native shapes/text —— 导出后在 PowerPoint 里仍是可编辑形状组，
/// 但不是"图表对象"（不能改数据重算）。
List<DeckElement> buildInfographicElements(
  Map<String, Object?> json,
  DeckStyle? style,
  String where,
) {
  final kind = json['kind'];
  final p = _Palette(style);
  final f = DeckFrame.fromJson(json, where);
  return switch (kind) {
    'progress' => _progress(json, f, p, where),
    'kpi' => _kpi(json, f, p, where),
    'waffle' => _waffle(json, f, p, where),
    'timeline' => _timeline(json, f, p, where),
    'funnel' => _funnel(json, f, p, where),
    'gauge' => _gauge(json, f, p, where),
    _ => throw DeckParseException(
      '$where 的 infographic kind 必须是 '
      'progress/kpi/waffle/timeline/funnel/gauge：收到 "$kind"',
    ),
  };
}

double _percent(Map<String, Object?> json, String where) {
  final v = json['value'];
  if (v is! num || v < 0 || v > 100) {
    throw DeckParseException('$where 缺少 0-100 的数值 "value"（百分比）');
  }
  return v.toDouble();
}

List<DeckElement> _progress(
  Map<String, Object?> json,
  DeckFrame f,
  _Palette p,
  String where,
) {
  final value = _percent(json, '$where(progress)');
  final label = json['label'] as String?;
  final barH = 0.28;
  final labelH = label == null ? 0.0 : 0.36;
  final barY = f.y + labelH + (f.h - labelH - barH) / 2;
  return [
    if (label != null)
      _text(DeckFrame(x: f.x, y: f.y, w: f.w, h: 0.34), [
        (label, p.bodySize, p.textSecondary, false),
      ], font: p.font),
    DeckShapeElement(
      frame: DeckFrame(x: f.x, y: barY, w: f.w - 0.85, h: barH),
      kind: DeckShapeKind.roundRect,
      fill: p.accent(0),
      fillTransparency: 80,
      radius: 0.5,
    ),
    if (value > 0)
      DeckShapeElement(
        frame: DeckFrame(
          x: f.x,
          y: barY,
          w: (f.w - 0.85) * value / 100,
          h: barH,
        ),
        kind: DeckShapeKind.roundRect,
        fill: p.accent(0),
        radius: 0.5,
      ),
    _text(
      DeckFrame(x: f.x + f.w - 0.8, y: barY - 0.08, w: 0.8, h: 0.44),
      [('${_fmtNum(value)}%', p.cardTitleSize, p.accent(0), true)],
      font: p.font,
      align: 'right',
      valign: 'middle',
    ),
  ];
}

List<DeckElement> _kpi(
  Map<String, Object?> json,
  DeckFrame f,
  _Palette p,
  String where,
) {
  final value = _reqString(json, 'value', '$where(kpi)');
  final label = json['label'] as String?;
  final trend = json['trend'] as String?;
  final trendUp = trend == null || !trend.startsWith('-');
  return [
    _card(f, p),
    _text(
      DeckFrame(x: f.x + _kPad, y: f.y + _kPad, w: f.w - _kPad * 2, h: 0.36),
      [(label ?? '', p.bodySize, p.textSecondary, false)],
      font: p.font,
    ),
    _text(
      DeckFrame(
        x: f.x + _kPad,
        y: f.y + _kPad + 0.36,
        w: f.w - _kPad * 2,
        h: f.h - _kPad * 2 - (trend == null ? 0.36 : 0.72),
      ),
      [(value, 34, p.accent(0), true)],
      font: p.font,
      valign: 'middle',
    ),
    if (trend != null)
      _text(
        DeckFrame(
          x: f.x + _kPad,
          y: f.y + f.h - _kPad - 0.36,
          w: f.w - _kPad * 2,
          h: 0.36,
        ),
        [
          (
            '${trendUp ? '▲' : '▼'} $trend',
            p.bodySize - 1,
            trendUp
                ? const DeckColor.raw('16A34A')
                : const DeckColor.raw('DC2626'),
            true,
          ),
        ],
        font: p.font,
      ),
  ];
}

List<DeckElement> _waffle(
  Map<String, Object?> json,
  DeckFrame f,
  _Palette p,
  String where,
) {
  final value = _percent(json, '$where(waffle)');
  final label = json['label'] as String?;
  final labelH = label == null ? 0.0 : 0.4;
  final grid = f.h - labelH;
  final side = (grid < f.w ? grid : f.w);
  final cell = side / 10;
  final dot = cell * 0.72;
  final filled = value.round();
  final elements = <DeckElement>[
    if (label != null)
      _text(DeckFrame(x: f.x, y: f.y, w: f.w, h: 0.36), [
        ('$label ${_fmtNum(value)}%', p.bodySize, p.textSecondary, false),
      ], font: p.font),
  ];
  for (var i = 0; i < 100; i++) {
    final r = i ~/ 10;
    final c = i % 10;
    elements.add(
      DeckShapeElement(
        frame: DeckFrame(
          x: f.x + c * cell,
          y: f.y + labelH + r * cell,
          w: dot,
          h: dot,
        ),
        kind: DeckShapeKind.roundRect,
        fill: p.accent(0),
        fillTransparency: i < filled ? 0 : 85,
        radius: 0.3,
      ),
    );
  }
  return elements;
}

List<DeckElement> _timeline(
  Map<String, Object?> json,
  DeckFrame f,
  _Palette p,
  String where,
) {
  final rawSteps = json['steps'];
  if (rawSteps is! List || rawSteps.length < 2) {
    throw DeckParseException('$where(timeline) 的 steps 至少 2 个');
  }
  final steps = <({String label, String? desc})>[];
  for (final (i, raw) in rawSteps.indexed) {
    if (raw is String) {
      steps.add((label: raw, desc: null));
    } else if (raw is Map) {
      final m = raw.cast<String, Object?>();
      steps.add((
        label: _reqString(m, 'label', '$where.steps[$i]'),
        desc: m['desc'] as String?,
      ));
    } else {
      throw DeckParseException('$where.steps[$i] 必须是字符串或对象');
    }
  }
  const dot = 0.26;
  final lineY = f.y + 0.55;
  final stepW = f.w / steps.length;
  return [
    DeckShapeElement(
      frame: DeckFrame(
        x: f.x + stepW / 2,
        y: lineY + dot / 2 - 0.012,
        w: f.w - stepW,
        h: 0.024,
      ),
      kind: DeckShapeKind.rect,
      fill: p.accent(0),
      fillTransparency: 45,
    ),
    for (final (i, step) in steps.indexed) ...[
      DeckShapeElement(
        frame: DeckFrame(
          x: f.x + i * stepW + stepW / 2 - dot / 2,
          y: lineY,
          w: dot,
          h: dot,
        ),
        kind: DeckShapeKind.ellipse,
        fill: p.accent(i),
      ),
      _text(
        DeckFrame(x: f.x + i * stepW, y: f.y, w: stepW, h: 0.44),
        [(step.label, p.bodySize, p.textPrimary, true)],
        font: p.font,
        align: 'center',
      ),
      if (step.desc != null)
        _text(
          DeckFrame(
            x: f.x + i * stepW + 0.06,
            y: lineY + dot + 0.14,
            w: stepW - 0.12,
            h: f.y + f.h - lineY - dot - 0.14,
          ),
          [(step.desc!, p.bodySize - 2, p.textSecondary, false)],
          font: p.font,
          align: 'center',
          lineSpacing: 1.25,
        ),
    ],
  ];
}

List<DeckElement> _funnel(
  Map<String, Object?> json,
  DeckFrame f,
  _Palette p,
  String where,
) {
  final rawStages = json['stages'];
  if (rawStages is! List || rawStages.length < 2) {
    throw DeckParseException('$where(funnel) 的 stages 至少 2 层');
  }
  final stages = <({String label, double value})>[];
  for (final (i, raw) in rawStages.indexed) {
    if (raw is! Map) {
      throw DeckParseException('$where.stages[$i] 必须是对象（label + value）');
    }
    final m = raw.cast<String, Object?>();
    final v = m['value'];
    if (v is! num || v < 0) {
      throw DeckParseException('$where.stages[$i] 缺少非负数值 "value"');
    }
    stages.add((
      label: _reqString(m, 'label', '$where.stages[$i]'),
      value: v.toDouble(),
    ));
  }
  final maxV = stages
      .map((s) => s.value)
      .fold<double>(0, (a, b) => a > b ? a : b);
  final rowH = (f.h - 0.1 * (stages.length - 1)) / stages.length;
  return [
    for (final (i, stage) in stages.indexed) ...[
      DeckShapeElement(
        frame: DeckFrame(
          x: f.x + (f.w - f.w * (maxV <= 0 ? 1 : stage.value / maxV)) / 2,
          y: f.y + i * (rowH + 0.1),
          w: f.w * (maxV <= 0 ? 1 : stage.value / maxV),
          h: rowH,
        ),
        kind: DeckShapeKind.roundRect,
        fill: p.accent(i),
        radius: 0.18,
      ),
      _text(
        DeckFrame(x: f.x, y: f.y + i * (rowH + 0.1), w: f.w, h: rowH),
        [
          (
            '${stage.label}  ${_fmtNum(stage.value)}',
            p.bodySize,
            const DeckColor.raw('FFFFFF'),
            true,
          ),
        ],
        font: p.font,
        align: 'center',
        valign: 'middle',
      ),
    ],
  ];
}

List<DeckElement> _gauge(
  Map<String, Object?> json,
  DeckFrame f,
  _Palette p,
  String where,
) {
  final value = _percent(json, '$where(gauge)');
  final label = json['label'] as String?;
  // 半环仪表盘：底环（半透明）+ 数值弧（pie 形状）+ 背景色内圆抠出环形。
  final d = (f.w < f.h * 2 ? f.w : f.h * 2) * 0.92;
  final cx = f.x + f.w / 2;
  final topY = f.y + (f.h - d / 2 - 0.5) / 2;
  final ring = d * 0.14;
  return [
    DeckShapeElement(
      frame: DeckFrame(x: cx - d / 2, y: topY, w: d, h: d),
      kind: DeckShapeKind.pie,
      angleStart: 180,
      angleEnd: 360,
      fill: p.accent(0),
      fillTransparency: 78,
    ),
    if (value > 0)
      DeckShapeElement(
        frame: DeckFrame(x: cx - d / 2, y: topY, w: d, h: d),
        kind: DeckShapeKind.pie,
        angleStart: 180,
        angleEnd: 180 + value * 1.8,
        fill: p.accent(0),
      ),
    DeckShapeElement(
      frame: DeckFrame(
        x: cx - d / 2 + ring,
        y: topY + ring,
        w: d - ring * 2,
        h: d - ring * 2,
      ),
      kind: DeckShapeKind.ellipse,
      fill: p.background,
    ),
    _text(
      DeckFrame(x: cx - d / 2, y: topY + d / 2 - 0.75, w: d, h: 0.6),
      [('${_fmtNum(value)}%', 30, p.accent(0), true)],
      font: p.font,
      align: 'center',
      valign: 'bottom',
    ),
    if (label != null)
      _text(
        DeckFrame(x: cx - d / 2, y: topY + d / 2 + 0.06, w: d, h: 0.4),
        [(label, p.bodySize, p.textSecondary, false)],
        font: p.font,
        align: 'center',
      ),
  ];
}

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
