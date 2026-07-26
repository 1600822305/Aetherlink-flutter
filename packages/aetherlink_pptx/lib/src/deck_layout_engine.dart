/// Bento 布局引擎：把页级 `"layout": {"type": ..., "cards": [...]}` 声明编译成
/// 绝对定位的原生元素（卡片圆角矩形 + 文本 + 装饰形状）。卡片定位、间距、
/// 边界由引擎保证 —— agent 只填内容，从源头消灭 out_of_bounds/间距不一致。
///
/// 内容页布局 7 种（focus/split/asymmetric/columns/hierarchy/hero/grid）+
/// 页型 4 种（cover/toc/section/end），卡片 6 类型
/// （text/data/list/tags/process/big_number），对齐 Akxan Bento Grid 体系。
library;

import 'deck_document.dart';
import 'deck_qa.dart'
    show
        kQaLineHeightFactor,
        kQaMinFontSize,
        kQaTextOverflowTolerance,
        qaTextWidthInches;
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
      [
        (
          title,
          _fitFontSize(title, w - _kMargin * 2, 1.4, 44, maxLines: 2),
          p.textPrimary,
          true,
        ),
      ],
      font: p.font,
      valign: 'middle',
    ),
    if (subtitle != null)
      _text(
        DeckFrame(x: _kMargin, y: h * 0.40 + 1.45, w: w - _kMargin * 2, h: 0.6),
        [
          (
            subtitle,
            _fitFontSize(subtitle, w - _kMargin * 2, 0.6, 20, maxLines: 2),
            p.textSecondary,
            false,
          ),
        ],
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
        [
          (
            meta,
            _fitFontSize(meta, w - _kMargin * 2, 0.4, 13),
            p.textSecondary,
            false,
          ),
        ],
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
        [
          (
            label,
            _fitFontSize(label, w - _kMargin * 2, 0.45, 16),
            p.accent(0),
            true,
          ),
        ],
        font: p.font,
        align: 'center',
      ),
    _text(
      DeckFrame(x: _kMargin, y: h * 0.40, w: w - _kMargin * 2, h: 1.1),
      [
        (
          title,
          _fitFontSize(title, w - _kMargin * 2, 1.1, 38, maxLines: 2),
          p.textPrimary,
          true,
        ),
      ],
      font: p.font,
      align: 'center',
      valign: 'middle',
    ),
    if (lead != null)
      _text(
        DeckFrame(x: w * 0.2, y: h * 0.40 + 1.2, w: w * 0.6, h: 0.8),
        [
          (
            lead,
            _fitFontSize(lead, w * 0.6, 0.8, 15, maxLines: 2),
            p.textSecondary,
            false,
          ),
        ],
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
  if (items.length > 8) {
    throw DeckParseException(
      '$where.layout(end) 的 items 最多 8 条：收到 ${items.length}',
    );
  }
  // 整体框高按条数给（每条 0.42）；字号按 QA 同一套逐段换行估算缩到
  // 全部装得下，避免任何一条换行把整块撑爆。
  final itemSize = _fitParagraphsFontSize(
    items,
    w * 0.5,
    items.length * 0.42,
    15,
    lineSpacing: 1.3,
  );
  return [
    _text(
      DeckFrame(x: _kMargin, y: h * 0.26, w: w - _kMargin * 2, h: 1.0),
      [
        (
          title,
          _fitFontSize(title, w - _kMargin * 2, 1.0, 38),
          p.textPrimary,
          true,
        ),
      ],
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
        [for (final it in items) (it, itemSize, p.textSecondary, false)],
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
        [
          (
            meta,
            _fitFontSize(meta, w - _kMargin * 2, 0.4, 13),
            p.textSecondary,
            false,
          ),
        ],
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
          [
            (
              items[i],
              _fitFontSize(
                items[i],
                frame.w - _kPad * 2,
                frame.h - _kPad * 2 - 0.55,
                p.cardTitleSize,
                maxLines: 2,
              ),
              p.textPrimary,
              true,
            ),
          ],
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
    [
      (
        title,
        _fitFontSize(
          title,
          w - _kMargin * 2 - 0.18,
          _kTitleH,
          p.titleSize * 0.8,
        ),
        p.textPrimary,
        true,
      ),
    ],
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
            (
              title,
              _fitFontSize(title, inner.w, 0.42, p.cardTitleSize),
              accent,
              true,
            ),
          ], font: p.font),
        );
        top += 0.52;
      }
      final bodyH = inner.y + inner.h - top;
      final bodyFit = _fitParagraphsFontSize(
        body,
        inner.w,
        bodyH,
        p.bodySize,
        lineSpacing: 1.35,
      );
      elements.add(
        _text(
          DeckFrame(x: inner.x, y: top, w: inner.w, h: bodyH),
          [for (final b in body) (b, bodyFit, p.textPrimary, false)],
          font: p.font,
          lineSpacing: 1.35,
        ),
      );
    case 'data':
      final value = _reqString(json, 'value', '$where(data)');
      final label = json['label'] as String?;
      final desc = json['desc'] as String?;
      elements.add(
        _text(DeckFrame(x: inner.x, y: inner.y, w: inner.w, h: 0.85), [
          (value, _fitFontSize(value, inner.w, 0.85, 38), accent, true),
        ], font: p.font),
      );
      if (label != null) {
        elements.add(
          _text(DeckFrame(x: inner.x, y: inner.y + 0.9, w: inner.w, h: 0.4), [
            (
              label,
              _fitFontSize(label, inner.w, 0.4, p.bodySize),
              p.textSecondary,
              false,
            ),
          ], font: p.font),
        );
      }
      // desc 区不足 0.2 英寸时直接不放（小卡片上强塞必然溢出）。
      if (desc != null && inner.h - 1.35 >= 0.2) {
        elements.add(
          _text(
            DeckFrame(
              x: inner.x,
              y: inner.y + 1.35,
              w: inner.w,
              h: inner.h - 1.35,
            ),
            [
              (
                desc,
                _fitParagraphsFontSize(
                  [desc],
                  inner.w,
                  inner.h - 1.35,
                  p.bodySize - 1,
                  lineSpacing: 1.3,
                ),
                p.textPrimary,
                false,
              ),
            ],
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
            (
              title,
              _fitFontSize(title, inner.w, 0.42, p.cardTitleSize),
              accent,
              true,
            ),
          ], font: p.font),
        );
        top += 0.52;
      }
      final itemFit = _fitParagraphsFontSize(
        items,
        inner.w,
        inner.y + inner.h - top,
        p.bodySize,
        lineSpacing: 1.4,
      );
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
                    size: itemFit,
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
            (
              title,
              _fitFontSize(title, inner.w, 0.42, p.cardTitleSize),
              accent,
              true,
            ),
          ], font: p.font),
        );
        top += 0.55;
      }
      const tagH = 0.34;
      var tx = inner.x;
      var ty = top;
      for (final (ti, tag) in tags.indexed) {
        // 药丸宽度按 QA 同一套宽度估算量出来，并钳到卡内；超长标签靠
        // 缩字号兜底，而不是让药丸伸出卡片/画布。
        var tagW = qaTextWidthInches(tag, p.bodySize - 2) + 0.28;
        if (tagW > inner.w) tagW = inner.w;
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
              [
                (
                  tag,
                  _fitFontSize(tag, tagW, tagH - 0.06, p.bodySize - 2),
                  p.textPrimary,
                  false,
                ),
              ],
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
            (
              title,
              _fitFontSize(title, inner.w, 0.42, p.cardTitleSize),
              accent,
              true,
            ),
          ], font: p.font),
        );
        top += 0.55;
      }
      const dot = 0.34;
      final stepH = (inner.y + inner.h - top) / steps.length;
      if (stepH < 0.2) {
        throw DeckParseException(
          '$where(process) 的 ${steps.length} 步在这张卡里放不下'
          '（每步至少 0.2 英寸）：减少步骤或换更高的卡位',
        );
      }
      for (final (si, step) in steps.indexed) {
        final cy = top + si * stepH;
        // 步距小于圆点时连接线高度为负 —— 直接不画。
        if (si < steps.length - 1 && stepH - dot > 0.02) {
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
                  _fitFontSize('${si + 1}', dot, dot - 0.04, p.bodySize - 2),
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
              [
                (
                  step,
                  _fitFontSize(
                    step,
                    inner.w - dot - 0.16,
                    stepH,
                    p.bodySize,
                    maxLines: 2,
                  ),
                  p.textPrimary,
                  false,
                ),
              ],
              font: p.font,
              valign: 'top',
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
          [
            (
              value,
              _fitFontSize(
                value,
                inner.w,
                label == null ? inner.h : inner.h - 0.5,
                54,
                maxLines: 2,
              ),
              accent,
              true,
            ),
          ],
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
            [
              (
                label,
                _fitFontSize(label, inner.w, 0.5, p.bodySize, maxLines: 2),
                p.textSecondary,
                false,
              ),
            ],
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
  if (f.w < 1.2 || f.h < 0.35) {
    throw DeckParseException(
      '$where(progress) 的框太小（至少 1.2×0.35 英寸）：收到 '
      '${f.w.toStringAsFixed(2)}×${f.h.toStringAsFixed(2)}',
    );
  }
  // 矮框（label + 条放不下）自动丢 label，保证条不越出容器。
  final label = f.h < 0.7 ? null : json['label'] as String?;
  final barH = 0.28;
  final labelH = label == null ? 0.0 : 0.36;
  final barY = f.y + labelH + (f.h - labelH - barH) / 2;
  // 百分比框按 QA text_overflow 的同一套启发式预留 —— 引擎自产的元素
  // 不允许溢出自己写的容器（字号来自 style.cardTitleSize，可变，所以
  // 不能写死 0.8×0.44）。槽宽按「最坏情况文本」而不是当前值预留：同页
  // 多条 progress 的槽宽必须一致，填充长度才可比（99% 不能比 100% 长）。
  final pctText = '${_fmtPct(value)}%';
  final pctSize = p.cardTitleSize;
  var pctW = qaTextWidthInches('88.8%', pctSize) + 0.06;
  if (pctW > f.w * 0.45) pctW = f.w * 0.45; // 窄容器：靠缩字号兜底
  var pctH =
      pctSize * kQaLineHeightFactor / 72 / kQaTextOverflowTolerance + 0.02;
  if (pctH < 0.44) pctH = 0.44;
  if (pctH > f.h) pctH = f.h;
  var pctY = barY + barH / 2 - pctH / 2;
  if (pctY + pctH > f.y + f.h) pctY = f.y + f.h - pctH;
  if (pctY < f.y) pctY = f.y;
  final rawBarW = f.w - pctW - 0.15;
  final barW = rawBarW < 0.1 ? 0.1 : rawBarW;
  return [
    if (label != null)
      _text(DeckFrame(x: f.x, y: f.y, w: f.w, h: 0.34), [
        (
          label,
          _fitFontSize(label, f.w, 0.34, p.bodySize),
          p.textSecondary,
          false,
        ),
      ], font: p.font),
    DeckShapeElement(
      frame: DeckFrame(x: f.x, y: barY, w: barW, h: barH),
      kind: DeckShapeKind.roundRect,
      fill: p.accent(0),
      fillTransparency: 80,
      radius: 0.5,
    ),
    if (value > 0)
      DeckShapeElement(
        frame: DeckFrame(x: f.x, y: barY, w: barW * value / 100, h: barH),
        kind: DeckShapeKind.roundRect,
        fill: p.accent(0),
        radius: 0.5,
      ),
    _text(
      DeckFrame(x: f.x + f.w - pctW, y: pctY, w: pctW, h: pctH),
      [
        (
          pctText,
          _fitFontSize(pctText, pctW, pctH, pctSize),
          p.accent(0),
          true,
        ),
      ],
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
  if (json['items'] is List) {
    throw DeckParseException(
      '$where(kpi) 不支持 "items" 数组：一个 kpi 元素只显示一个指标'
      '（"value" + 可选 "label"/"trend"）；多个指标请放多个 kpi 元素，'
      '或改用 layout 卡片 type "data"/"big_number"',
    );
  }
  final value = _reqString(json, 'value', '$where(kpi)');
  if (f.w < 1.0 || f.h < 0.6) {
    throw DeckParseException(
      '$where(kpi) 的框太小（至少 1.0×0.6 英寸）：收到 '
      '${f.w.toStringAsFixed(2)}×${f.h.toStringAsFixed(2)}',
    );
  }
  final label = json['label'] as String?;
  final trend = json['trend'] as String?;
  final trendUp = trend == null || !trend.startsWith('-');
  final innerW = f.w - _kPad * 2;
  // 矮卡片降级：先掉 trend 行、再掉 label 行，保住主数值的可读空间，
  // 而不是把数值压到 12pt 以下或产出负高度文本框。
  var showLabel = label != null;
  var showTrend = trend != null;
  double valueBoxH() =>
      f.h - _kPad * 2 - (showLabel ? 0.36 : 0) - (showTrend ? 0.36 : 0);
  if (valueBoxH() < 0.35 && showTrend) showTrend = false;
  if (valueBoxH() < 0.35 && showLabel) showLabel = false;
  var valueH = valueBoxH();
  if (valueH < 0.2) valueH = 0.2; // f.h < 0.7 的极小卡兜底
  return [
    _card(f, p),
    if (showLabel)
      _text(
        DeckFrame(x: f.x + _kPad, y: f.y + _kPad, w: innerW, h: 0.36),
        [
          (
            label!,
            _fitFontSize(label, innerW, 0.36, p.bodySize),
            p.textSecondary,
            false,
          ),
        ],
        font: p.font,
      ),
    _text(
      DeckFrame(
        x: f.x + _kPad,
        y: f.y + _kPad + (showLabel ? 0.36 : 0),
        w: innerW,
        h: valueH,
      ),
      [
        (value, _fitFontSize(value, innerW, valueH, 34), p.accent(0), true),
      ],
      font: p.font,
      valign: 'middle',
    ),
    if (showTrend)
      _text(
        DeckFrame(
          x: f.x + _kPad,
          y: f.y + f.h - _kPad - 0.36,
          w: innerW,
          h: 0.36,
        ),
        [
          (
            '${trendUp ? '▲' : '▼'} $trend',
            _fitFontSize('${trendUp ? '▲' : '▼'} $trend', innerW, 0.36,
                p.bodySize - 1),
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
  if (f.w < 0.8 || f.h - labelH < 0.8) {
    throw DeckParseException(
      '$where(waffle) 的框太小（10×10 点阵至少需要 0.8×'
      '${(labelH + 0.8).toStringAsFixed(1)} 英寸）：收到 '
      '${f.w.toStringAsFixed(2)}×${f.h.toStringAsFixed(2)}',
    );
  }
  final grid = f.h - labelH;
  final side = (grid < f.w ? grid : f.w);
  final cell = side / 10;
  final dot = cell * 0.72;
  final filled = value.round();
  final elements = <DeckElement>[
    if (label != null)
      _text(DeckFrame(x: f.x, y: f.y, w: f.w, h: 0.36), [
        (
          '$label ${_fmtPct(value)}%',
          _fitFontSize('$label ${_fmtPct(value)}%', f.w, 0.36, p.bodySize),
          p.textSecondary,
          false,
        ),
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
  if (rawSteps.length > 8) {
    throw DeckParseException(
      '$where(timeline) 的 steps 最多 8 个：收到 ${rawSteps.length}',
    );
  }
  // 标签行 0.44 + 轴线 0.55 起点 + 圆点 0.26：低于 0.9 英寸放不下。
  if (f.h < 0.9) {
    throw DeckParseException(
      '$where(timeline) 的框高至少 0.9 英寸：收到 ${f.h.toStringAsFixed(2)}',
    );
  }
  // desc 区（轴线下方）不足 0.25 英寸时自动丢弃 desc，避免负高度文本框。
  final showDesc = f.h - 0.95 >= 0.25;
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
        [
          (
            step.label,
            _fitFontSize(step.label, stepW, 0.44, p.bodySize),
            p.textPrimary,
            true,
          ),
        ],
        font: p.font,
        align: 'center',
      ),
      if (step.desc != null && showDesc)
        _text(
          DeckFrame(
            x: f.x + i * stepW + 0.06,
            y: lineY + dot + 0.14,
            w: stepW - 0.12,
            h: f.y + f.h - lineY - dot - 0.14,
          ),
          [
            (
              step.desc!,
              _fitFontSize(
                step.desc!,
                stepW - 0.12,
                f.y + f.h - lineY - dot - 0.14,
                p.bodySize - 2,
                maxLines: 3,
                lineSpacing: 1.25,
              ),
              p.textSecondary,
              false,
            ),
          ],
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
  if (rawStages.length > 8) {
    throw DeckParseException(
      '$where(funnel) 的 stages 最多 8 层：收到 ${rawStages.length}',
    );
  }
  {
    // 每层至少 0.2 英寸（12pt 文字的 QA 下限）+ 层间距 0.1。
    final minH = 0.2 * rawStages.length + 0.1 * (rawStages.length - 1);
    if (f.h < minH) {
      throw DeckParseException(
        '$where(funnel) ${rawStages.length} 层至少需要 '
        '${minH.toStringAsFixed(1)} 英寸高度：收到 ${f.h.toStringAsFixed(2)}',
      );
    }
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
            _fitFontSize(
              '${stage.label}  ${_fmtNum(stage.value)}',
              f.w,
              rowH,
              p.bodySize,
            ),
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
  if (f.w < 1.0 || f.h < 0.9) {
    throw DeckParseException(
      '$where(gauge) 的框太小（至少 1.0×0.9 英寸）：收到 '
      '${f.w.toStringAsFixed(2)}×${f.h.toStringAsFixed(2)}',
    );
  }
  final label = json['label'] as String?;
  // 半环仪表盘：底环（半透明）+ 数值弧（pie 形状）+ 背景色内圆抠出环形。
  // pie 形状的边界盒是整圆（下半圆不可见但仍参与 out_of_bounds 判定），
  // 所以直径受三重约束：宽、可见内容的垂直预算、整圆盒不越出容器。
  var d = (f.w < f.h * 2 ? f.w : f.h * 2) * 0.92;
  if (d > f.h) d = f.h;
  final dMax = (f.h - 0.5) * 2;
  if (d > dMax) d = dMax;
  final cx = f.x + f.w / 2;
  var topY = f.y + (f.h - d / 2 - 0.5) / 2;
  final topMax = f.y + f.h - d; // 整圆盒下缘不出容器
  if (topY > topMax) topY = topMax;
  if (topY < f.y) topY = f.y;
  final ring = d * 0.14;
  var pctY = topY + d / 2 - 0.75;
  if (pctY + 0.6 > f.y + f.h) pctY = f.y + f.h - 0.6;
  if (pctY < f.y) pctY = f.y;
  var labelY = topY + d / 2 + 0.06;
  if (labelY + 0.4 > f.y + f.h) labelY = f.y + f.h - 0.4;
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
      DeckFrame(x: cx - d / 2, y: pctY, w: d, h: 0.6),
      [
        (
          '${_fmtPct(value)}%',
          _fitFontSize('${_fmtPct(value)}%', d, 0.6, 30),
          p.accent(0),
          true,
        ),
      ],
      font: p.font,
      align: 'center',
      valign: 'bottom',
    ),
    if (label != null)
      _text(
        DeckFrame(x: cx - d / 2, y: labelY, w: d, h: 0.4),
        [
          (
            label,
            _fitFontSize(label, d, 0.4, p.bodySize),
            p.textSecondary,
            false,
          ),
        ],
        font: p.font,
        align: 'center',
      ),
  ];
}

String _fmtNum(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// 百分比专用格式：99.95-99.99 会被 toStringAsFixed(1) 进位成 "100.0"
/// （6 字符，比预留槽宽的最坏情况还宽，且把 <100 显示成 100）——夹回
/// "99.9"。整 100 仍走 _fmtNum 输出 "100"。
String _fmtPct(double v) {
  final s = _fmtNum(v);
  return s == '100.0' && v < 100 ? '99.9' : s;
}

/// [text] 在 w×h（英寸）框内、最多 [maxLines] 行时能通过 QA text_overflow
/// 启发式的最大字号：上限 [max]、下限 [kQaMinFontSize]。宽高都用与 QA
/// 完全相同的常数估算。引擎写死字号 + 框尺寸随外框/风格走的组合会在小
/// 卡片上自我溢出，引擎自产的展示文本都应经过这里。
double _fitFontSize(
  String text,
  double w,
  double h,
  double max, {
  int maxLines = 1,
  double lineSpacing = 1,
}) {
  if (text.trim().isEmpty || w <= 0 || h <= 0) return max;
  final unitW = qaTextWidthInches(text, 1); // 1pt 时的估算宽度（英寸）
  var best = kQaMinFontSize;
  // 对每个行数 n 取宽/高两个约束的下界，再在 n 间取最大：短文本自然选
  // 单行大字，长文本自动换行缩字。0.98 余量避免估算恰好压线。
  for (var lines = 1; lines <= maxLines; lines++) {
    final byWidth = unitW <= 0 ? max : lines * w / unitW;
    final byHeight =
        h * kQaTextOverflowTolerance * 72 /
        (kQaLineHeightFactor * lineSpacing * lines);
    final s = (byWidth < byHeight ? byWidth : byHeight) * 0.98;
    if (s > best) best = s;
  }
  return best > max ? max : best;
}

/// 多段落版 fit：按 QA 完全相同的逐段 ceil 换行估算总高度，从 [max]
/// 逐步降到能装进 w×h 为止（下限 [kQaMinFontSize]）。用于正文/列表这类
/// 允许换行、段数不定的引擎文本。
double _fitParagraphsFontSize(
  List<String> paragraphs,
  double w,
  double h,
  double max, {
  double lineSpacing = 1,
}) {
  if (w <= 0 || h <= 0) return max;
  double estimate(double s) {
    var total = 0.0;
    for (final t in paragraphs) {
      final lines = (qaTextWidthInches(t, s) / w).ceil().clamp(1, 1000);
      total += lines * s * kQaLineHeightFactor * lineSpacing / 72;
    }
    return total;
  }

  final target = h * kQaTextOverflowTolerance * 0.98;
  var s = max;
  while (s > kQaMinFontSize && estimate(s) > target) {
    s = s * 0.94;
  }
  return s < kQaMinFontSize ? kQaMinFontSize : s;
}
