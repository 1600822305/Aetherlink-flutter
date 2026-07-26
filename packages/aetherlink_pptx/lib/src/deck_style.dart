import 'deck_document.dart';

/// A deck-wide visual style: background/card/text/accent colors, type scale
/// and font stacks. deck.json declares `"style": "dark_tech"`（内置 id）or an
/// inline JSON object（自定义风格）; elements may omit colors and inherit
/// from the style — 换风格即换肤，无需重新生成内容.
class DeckStyle {
  const DeckStyle({
    required this.id,
    required this.name,
    required this.category,
    required this.background,
    required this.cardFill,
    required this.textPrimary,
    required this.textSecondary,
    required this.accents,
    this.backgroundAccent,
    this.cardBorder,
    this.cardRadius = 0.09,
    this.titleSize = 28,
    this.bodySize = 14,
    this.cardTitleSize = 18,
    this.displayFont,
    this.bodyFont,
    this.forbidden = const [],
  });

  /// Parses an inline style JSON object（字段对齐内置风格 schema 的子集）.
  factory DeckStyle.fromJson(Map<String, Object?> json, String where) {
    DeckColor color(String key) {
      final v = json[key];
      if (v is! String) {
        throw DeckParseException('$where 缺少颜色字段 "$key"（6 位 hex）');
      }
      return DeckColor(v);
    }

    DeckColor? optColor(String key) =>
        json[key] == null ? null : DeckColor(json[key] as String);

    final rawAccents = json['accents'];
    if (rawAccents is! List || rawAccents.isEmpty) {
      throw DeckParseException('$where 缺少非空数组 "accents"（hex 颜色列表）');
    }
    double size(String key, double fallback) {
      final v = json[key];
      if (v == null) return fallback;
      if (v is! num || v <= 0) {
        throw DeckParseException('$where 的 "$key" 必须是正数（单位 pt）');
      }
      return v.toDouble();
    }

    return DeckStyle(
      id: (json['id'] as String?) ?? 'custom',
      name: (json['name'] as String?) ?? '自定义风格',
      category: (json['category'] as String?) ?? 'custom',
      background: color('background'),
      backgroundAccent: optColor('backgroundAccent'),
      cardFill: color('cardFill'),
      cardBorder: optColor('cardBorder'),
      textPrimary: color('textPrimary'),
      textSecondary: color('textSecondary'),
      accents: [for (final a in rawAccents) DeckColor(a as String)],
      titleSize: size('titleSize', 28),
      bodySize: size('bodySize', 14),
      cardTitleSize: size('cardTitleSize', 18),
      displayFont: json['displayFont'] as String?,
      bodyFont: json['bodyFont'] as String?,
      forbidden: [
        for (final f in (json['forbidden'] as List? ?? const [])) f.toString(),
      ],
    );
  }

  /// Resolves the deck-level `style` field: null（不用风格）、内置 id 字符串、
  /// 或 inline JSON 对象.
  static DeckStyle? resolve(Object? raw, String where) {
    if (raw == null) return null;
    if (raw is String) {
      final style = kBuiltinDeckStyles[raw];
      if (style == null) {
        throw DeckParseException(
          '$where 未知风格 id "$raw"（内置：${kBuiltinDeckStyles.keys.join('/')}；'
          '也可以直接内联风格 JSON 对象）',
        );
      }
      return style;
    }
    if (raw is Map) {
      return DeckStyle.fromJson(raw.cast<String, Object?>(), where);
    }
    throw DeckParseException('$where 的 style 必须是内置风格 id 或风格 JSON 对象');
  }

  final String id;
  final String name;

  /// dark_professional / light_premium / vibrant / cultural_oriental /
  /// natural_retro / custom.
  final String category;
  final DeckColor background;

  /// Optional secondary background tone（章节条带/装饰块）.
  final DeckColor? backgroundAccent;
  final DeckColor cardFill;
  final DeckColor? cardBorder;

  /// Card corner radius as a 0-0.5 fraction of the shorter side.
  final double cardRadius;
  final DeckColor textPrimary;
  final DeckColor textSecondary;

  /// Accent palette（>=2）；图表系列默认色也从这里取.
  final List<DeckColor> accents;
  final double titleSize;
  final double bodySize;
  final double cardTitleSize;
  final String? displayFont;
  final String? bodyFont;

  /// Style-specific design taboos（进 QA 提示与技能，不做硬校验）.
  final List<String> forbidden;

  DeckColor accent(int index) => accents[index % accents.length];

  bool get isDark {
    final hex = background.value;
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    return (r * 299 + g * 587 + b * 114) / 1000 < 128;
  }
}

/// 12 built-in styles covering 5 大板块（暗色专业/浅色高级/活力鲜明/
/// 东方文化/自然复古）— palette 对齐 Akxan 风格系统同名风格的气质.
final Map<String, DeckStyle> kBuiltinDeckStyles = {
  for (final s in _builtinStyles) s.id: s,
};

const List<DeckStyle> _builtinStyles = [
  // ── 暗色专业 ──
  DeckStyle(
    id: 'dark_tech',
    name: '暗黑科技',
    category: 'dark_professional',
    background: DeckColor.raw('050B1F'),
    backgroundAccent: DeckColor.raw('0A1F3D'),
    cardFill: DeckColor.raw('16233D'),
    cardBorder: DeckColor.raw('2B3B5C'),
    textPrimary: DeckColor.raw('FFFFFF'),
    textSecondary: DeckColor.raw('9DB0CE'),
    accents: [
      DeckColor.raw('22D3EE'),
      DeckColor.raw('3B82F6'),
      DeckColor.raw('FDE047'),
      DeckColor.raw('F59E0B'),
    ],
    forbidden: ['马卡龙糖果色', '波浪分隔线', '衬线杂志感'],
  ),
  DeckStyle(
    id: 'xiaomi_orange',
    name: '发布会暗橙',
    category: 'dark_professional',
    background: DeckColor.raw('0A0A0A'),
    backgroundAccent: DeckColor.raw('1A1A1A'),
    cardFill: DeckColor.raw('1C1C1E'),
    cardBorder: DeckColor.raw('3A3A3C'),
    textPrimary: DeckColor.raw('FFFFFF'),
    textSecondary: DeckColor.raw('A1A1A6'),
    accents: [
      DeckColor.raw('FF6900'),
      DeckColor.raw('FF9F0A'),
      DeckColor.raw('32D74B'),
      DeckColor.raw('0A84FF'),
    ],
    forbidden: ['多彩渐变', '花哨装饰', '密集小字'],
  ),
  DeckStyle(
    id: 'luxury_purple',
    name: '奢华紫金',
    category: 'dark_professional',
    background: DeckColor.raw('17102B'),
    backgroundAccent: DeckColor.raw('241740'),
    cardFill: DeckColor.raw('2A1D4A'),
    cardBorder: DeckColor.raw('4A3878'),
    textPrimary: DeckColor.raw('F5F0FF'),
    textSecondary: DeckColor.raw('B4A5D6'),
    accents: [
      DeckColor.raw('D4AF37'),
      DeckColor.raw('A78BFA'),
      DeckColor.raw('F0ABFC'),
      DeckColor.raw('E9D5FF'),
    ],
    forbidden: ['廉价饱和色', '圆珠笔蓝', '拥挤排版'],
  ),
  // ── 浅色高级 ──
  DeckStyle(
    id: 'blue_white',
    name: '企业蓝白',
    category: 'light_premium',
    background: DeckColor.raw('F7F9FC'),
    backgroundAccent: DeckColor.raw('E8F0FE'),
    cardFill: DeckColor.raw('FFFFFF'),
    cardBorder: DeckColor.raw('D7E1F0'),
    textPrimary: DeckColor.raw('1A2B4A'),
    textSecondary: DeckColor.raw('5B6B85'),
    accents: [
      DeckColor.raw('1A73E8'),
      DeckColor.raw('0B57D0'),
      DeckColor.raw('12B5CB'),
      DeckColor.raw('F9AB00'),
    ],
    forbidden: ['大面积纯黑', '荧光色', '重阴影'],
  ),
  DeckStyle(
    id: 'minimal_gray',
    name: '极简灰奢',
    category: 'light_premium',
    background: DeckColor.raw('FAFAF8'),
    backgroundAccent: DeckColor.raw('F0EFEA'),
    cardFill: DeckColor.raw('FFFFFF'),
    cardBorder: DeckColor.raw('E2E0D8'),
    textPrimary: DeckColor.raw('1C1C1A'),
    textSecondary: DeckColor.raw('6E6E68'),
    accents: [
      DeckColor.raw('1C1C1A'),
      DeckColor.raw('8A8A80'),
      DeckColor.raw('B45309'),
      DeckColor.raw('44403C'),
    ],
    forbidden: ['彩色渐变', '圆角过大', '装饰图形堆砌'],
  ),
  DeckStyle(
    id: 'medical_pulse',
    name: '医疗脉搏',
    category: 'light_premium',
    background: DeckColor.raw('F5FAFC'),
    backgroundAccent: DeckColor.raw('E1F1F7'),
    cardFill: DeckColor.raw('FFFFFF'),
    cardBorder: DeckColor.raw('CBE3EE'),
    textPrimary: DeckColor.raw('0F3A4D'),
    textSecondary: DeckColor.raw('4E7B8E'),
    accents: [
      DeckColor.raw('0891B2'),
      DeckColor.raw('06B6D4'),
      DeckColor.raw('10B981'),
      DeckColor.raw('F43F5E'),
    ],
    forbidden: ['暗黑底色', '高饱和撞色', '娱乐化装饰'],
  ),
  DeckStyle(
    id: 'fresh_green',
    name: '清新植物',
    category: 'light_premium',
    background: DeckColor.raw('F7FAF5'),
    backgroundAccent: DeckColor.raw('E8F3E4'),
    cardFill: DeckColor.raw('FFFFFF'),
    cardBorder: DeckColor.raw('D5E6CE'),
    textPrimary: DeckColor.raw('1F3A28'),
    textSecondary: DeckColor.raw('5C7A64'),
    accents: [
      DeckColor.raw('3E8E5A'),
      DeckColor.raw('86BC4C'),
      DeckColor.raw('C89B3C'),
      DeckColor.raw('2F6B4F'),
    ],
    forbidden: ['科技冷光', '黑底霓虹', '硬边直角堆砌'],
  ),
  DeckStyle(
    id: 'champagne_gold',
    name: '香槟金宴',
    category: 'light_premium',
    background: DeckColor.raw('FBF7F0'),
    backgroundAccent: DeckColor.raw('F3EADB'),
    cardFill: DeckColor.raw('FFFFFF'),
    cardBorder: DeckColor.raw('E5D8BE'),
    textPrimary: DeckColor.raw('3D3122'),
    textSecondary: DeckColor.raw('8A7A5F'),
    accents: [
      DeckColor.raw('C2A15C'),
      DeckColor.raw('A8843C'),
      DeckColor.raw('D9BE8C'),
      DeckColor.raw('7C6A48'),
    ],
    forbidden: ['荧光色', '科技网格', '拥挤数据图'],
  ),
  // ── 活力鲜明 ──
  DeckStyle(
    id: 'vibrant_rainbow',
    name: '活力彩虹',
    category: 'vibrant',
    background: DeckColor.raw('FFFFFF'),
    backgroundAccent: DeckColor.raw('F4F1FF'),
    cardFill: DeckColor.raw('FAFAFF'),
    cardBorder: DeckColor.raw('E4E0F5'),
    textPrimary: DeckColor.raw('18181B'),
    textSecondary: DeckColor.raw('5B5B66'),
    accents: [
      DeckColor.raw('635BFF'),
      DeckColor.raw('FF5996'),
      DeckColor.raw('00D4FF'),
      DeckColor.raw('FFB300'),
    ],
    forbidden: ['灰暗低饱和', '严肃公文排版', '细弱线条'],
  ),
  DeckStyle(
    id: 'bauhaus_block',
    name: '包豪斯色块',
    category: 'vibrant',
    background: DeckColor.raw('F5F1E8'),
    backgroundAccent: DeckColor.raw('EDE7D8'),
    cardFill: DeckColor.raw('FFFFFF'),
    cardBorder: DeckColor.raw('1C1C1C'),
    cardRadius: 0,
    textPrimary: DeckColor.raw('1C1C1C'),
    textSecondary: DeckColor.raw('55524A'),
    accents: [
      DeckColor.raw('D93025'),
      DeckColor.raw('1A73E8'),
      DeckColor.raw('F9AB00'),
      DeckColor.raw('1C1C1C'),
    ],
    forbidden: ['圆角卡片', '渐变', '阴影'],
  ),
  // ── 东方文化 ──
  DeckStyle(
    id: 'royal_red',
    name: '朱红鎏金',
    category: 'cultural_oriental',
    background: DeckColor.raw('7A1E1E'),
    backgroundAccent: DeckColor.raw('8F2626'),
    cardFill: DeckColor.raw('8A2424'),
    cardBorder: DeckColor.raw('C9A227'),
    textPrimary: DeckColor.raw('FFF6E5'),
    textSecondary: DeckColor.raw('E8C9A0'),
    accents: [
      DeckColor.raw('E8B33C'),
      DeckColor.raw('C9A227'),
      DeckColor.raw('F5DFA8'),
      DeckColor.raw('B03A2E'),
    ],
    forbidden: ['冷色科技感', '荧光色', '西式衬线堆砌'],
  ),
  DeckStyle(
    id: 'ink_jade',
    name: '墨玉国风',
    category: 'cultural_oriental',
    background: DeckColor.raw('F5F1E6'),
    backgroundAccent: DeckColor.raw('EBE5D4'),
    cardFill: DeckColor.raw('FDFBF4'),
    cardBorder: DeckColor.raw('CFC7AE'),
    textPrimary: DeckColor.raw('26261F'),
    textSecondary: DeckColor.raw('6B6A5C'),
    accents: [
      DeckColor.raw('B03A2E'),
      DeckColor.raw('2F5D50'),
      DeckColor.raw('8A8358'),
      DeckColor.raw('43423A'),
    ],
    forbidden: ['科技蓝紫', '塑料质感色', '密集英文粗体'],
  ),
];

/// Summarises the built-in styles（id/名称/板块/强调色）for tool output &
/// skill decision matrices.
List<Map<String, Object?>> builtinDeckStyleCatalog() => [
  for (final s in _builtinStyles)
    {
      'id': s.id,
      'name': s.name,
      'category': s.category,
      'background': s.background.value,
      'accents': [for (final a in s.accents) a.value],
    },
];
