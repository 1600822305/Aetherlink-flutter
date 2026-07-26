// 基础类型：异常 / 画布 / 颜色 / 几何 / 文本 run / 段落。
part of 'deck_document.dart';

/// Thrown when a deck.json source is structurally invalid. [message] is a
/// model-facing, actionable description (which field, what was expected).
/// 解析器按元素/幻灯片批量收集错误（像编译器），[messages] 是全部错误；
/// [message] 把它们拼成一段，方便单条展示。
class DeckParseException implements Exception {
  DeckParseException(String message) : messages = [message];

  DeckParseException.all(this.messages)
    : assert(messages.isNotEmpty, 'messages 不能为空');

  final List<String> messages;

  String get message => messages.length == 1
      ? messages.first
      : '发现 ${messages.length} 处问题：\n${[for (final m in messages) '- $m'].join('\n')}';

  @override
  String toString() => 'DeckParseException: $message';
}

/// Slide canvas presets. Sizes in inches; EMU = inches × 914400.
enum DeckLayout {
  layout16x9(12192000, 6858000),
  layout4x3(9144000, 6858000);

  const DeckLayout(this.widthEmu, this.heightEmu);

  final int widthEmu;
  final int heightEmu;

  double get widthInches => widthEmu / 914400;
  double get heightInches => heightEmu / 914400;

  static DeckLayout parse(String? raw) => switch (raw) {
    null || '16x9' || '16:9' => DeckLayout.layout16x9,
    '4x3' || '4:3' => DeckLayout.layout4x3,
    _ => throw DeckParseException('未知 layout: "$raw"（支持 16x9 / 4x3）'),
  };
}

/// A validated 6-hex RGB color (`RRGGBB`, no `#`, no alpha). Transparency is
/// a separate field on the owning element — never encoded in the hex.
extension type const DeckColor._(String hex) {
  factory DeckColor(String raw) {
    final v = raw.startsWith('#') ? raw.substring(1) : raw;
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v)) {
      throw DeckParseException(
        '颜色必须是 6 位 hex（如 "1A73E8"，不带 # 不带 alpha）：收到 "$raw"',
      );
    }
    return DeckColor._(v.toUpperCase());
  }

  /// Trusted compile-time constructor for built-in style palettes; the hex
  /// must already be 6-digit uppercase.
  const DeckColor.raw(String hex) : this._(hex);

  String get value => hex;
}

/// Common geometry: position/size in inches from the slide's top-left.
class DeckFrame {
  const DeckFrame({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory DeckFrame.fromJson(Map<String, Object?> json, String where) {
    double req(String key) {
      final v = json[key];
      if (v is num) return v.toDouble();
      throw DeckParseException('$where 缺少数值字段 "$key"（单位英寸）');
    }

    final frame = DeckFrame(x: req('x'), y: req('y'), w: req('w'), h: req('h'));
    if (frame.w < 0 || frame.h < 0) {
      throw DeckParseException('$where 的 w/h 不能为负数');
    }
    return frame;
  }

  final double x;
  final double y;
  final double w;
  final double h;
}

/// A styled text run.
class DeckTextRun {
  const DeckTextRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.size,
    this.color,
    this.font,
  });

  factory DeckTextRun.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    final text = json['text'];
    if (text is! String) {
      throw DeckParseException('$where 的 run 缺少字符串字段 "text"');
    }
    // 别名容错：fontSize 是 LLM 最自然的写法，等价于 size。
    final size = json['size'] ?? json['fontSize'];
    if (size != null && (size is! num || size <= 0)) {
      throw DeckParseException('$where 的 run.size 必须是正数（单位 pt）');
    }
    return DeckTextRun(
      text: text,
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      size: (size as num?)?.toDouble(),
      // 风格推导：省略颜色/字体时用风格的正文色与字体栈。
      color: json['color'] == null
          ? style?.textPrimary
          : DeckColor(json['color'] as String),
      font: (json['font'] as String?) ?? style?.bodyFont,
    );
  }

  final String text;
  final bool bold;
  final bool italic;

  /// Font size in points.
  final double? size;
  final DeckColor? color;
  final String? font;
}

/// A paragraph: runs plus paragraph-level bullet/align/indent.
class DeckParagraph {
  const DeckParagraph({
    required this.runs,
    this.bullet = false,
    this.indentLevel = 0,
    this.align,
  });

  factory DeckParagraph.fromJson(
    Map<String, Object?> json,
    String where, {
    DeckStyle? style,
  }) {
    final rawRuns = json['runs'];
    if (rawRuns is! List || rawRuns.isEmpty) {
      throw DeckParseException('$where 的段落缺少非空数组 "runs"');
    }
    final align = json['align'] as String?;
    if (align != null && !const {'left', 'center', 'right'}.contains(align)) {
      throw DeckParseException('$where 的段落 align 只支持 left/center/right');
    }
    final indent = (json['indentLevel'] as num?)?.toInt() ?? 0;
    if (indent < 0 || indent > 8) {
      throw DeckParseException('$where 的段落 indentLevel 必须在 0-8 之间');
    }
    return DeckParagraph(
      runs: [
        for (final (i, r) in rawRuns.indexed)
          DeckTextRun.fromJson(
            _asMap(r, '$where.runs[$i]'),
            '$where.runs[$i]',
            style: style,
          ),
      ],
      bullet: json['bullet'] == true,
      indentLevel: indent,
      align: align,
    );
  }

  final List<DeckTextRun> runs;
  final bool bullet;
  final int indentLevel;

  /// left / center / right; null = left.
  final String? align;

  String get plainText => runs.map((r) => r.text).join();
}

/// Sniffs [bytes] for a PNG/JPEG header. Returns `'png'`, `'jpeg'`, or null.
String? detectImageFormat(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'jpeg';
  }
  return null;
}
