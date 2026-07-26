// text 元素：原生文本框（<p:sp> + <p:txBody>）。
part of 'deck_document.dart';

/// A native text box (`<p:sp>` with a `<p:txBody>`).
class DeckTextElement extends DeckElement {
  const DeckTextElement({
    required super.frame,
    required this.paragraphs,
    this.valign,
    this.fill,
    this.lineSpacing,
  });

  factory DeckTextElement.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    var rawParas = json['paragraphs'];
    // 简写容错：顶层 "text" 字符串（可配 size/fontSize/bold/color/font/align）
    // 自动展开成 paragraphs/runs —— 这是 LLM 最自然的写法。
    if (rawParas == null && json['text'] is String) {
      final runProps = <String, Object?>{
        'size': ?(json['size'] ?? json['fontSize']),
        if (json['bold'] == true) 'bold': true,
        if (json['color'] is String) 'color': json['color'],
        if (json['font'] is String) 'font': json['font'],
      };
      final align = json['align'] is String ? json['align'] : null;
      rawParas = [
        for (final line in (json['text'] as String).split('\n'))
          {
            'align': ?align,
            'runs': [
              {'text': line, ...runProps},
            ],
          },
      ];
    }
    if (rawParas is! List || rawParas.isEmpty) {
      throw DeckParseException(
        '$where 缺少非空数组 "paragraphs"（或简写字符串 "text"）',
      );
    }
    final valign = json['valign'] as String?;
    if (valign != null && !const {'top', 'middle', 'bottom'}.contains(valign)) {
      throw DeckParseException('$where 的 valign 只支持 top/middle/bottom');
    }
    final spacing = json['lineSpacing'];
    if (spacing != null && (spacing is! num || spacing <= 0)) {
      throw DeckParseException('$where 的 lineSpacing 必须是正数（倍数，如 1.2）');
    }
    return DeckTextElement(
      frame: DeckFrame.fromJson(json, where),
      paragraphs: [
        for (final (i, p) in rawParas.indexed)
          DeckParagraph.fromJson(
            _asMap(p, '$where.paragraphs[$i]'),
            '$where.paragraphs[$i]',
            style: style,
          ),
      ],
      valign: valign,
      fill: json['fill'] == null ? null : DeckColor(json['fill'] as String),
      lineSpacing: (spacing as num?)?.toDouble(),
    );
  }

  final List<DeckParagraph> paragraphs;

  /// top / middle / bottom; null = top.
  final String? valign;

  /// Optional box background fill.
  final DeckColor? fill;

  /// Line spacing multiple (e.g. 1.2); null = single.
  final double? lineSpacing;
}
