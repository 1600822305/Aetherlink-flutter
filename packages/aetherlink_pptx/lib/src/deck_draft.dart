/// 大纲 → deck.json 初稿的确定性展开引擎。
///
/// 模型只写结构化大纲（每页：页型 + 标题 + 要点），引擎按固定规则展开成
/// 完整 deck.json（页级 layout 声明，坐标由布局引擎保证）——不再让 LLM
/// 逐字写几十 KB 的 deck。叙事节奏内置：内容页布局按密度交替
/// （split/asymmetric、columns/hierarchy 轮换），section 序号自动递进，
/// toc 条目缺省时从各章节标题自动生成。初稿之后用 pptx_edit 增量精修。
library;

import 'deck_document.dart' show DeckParseException;

/// outline.json 顶层 JSON Schema（`pptx_schema` 一并返回）。
const Map<String, Object?> kOutlineJsonSchema = {
  r'$schema': 'http://json-schema.org/draft-07/schema#',
  'title': 'outline.json',
  'description':
      'PPT 结构化大纲：pptx_draft 的输入，引擎确定性展开为完整 deck.json 初稿。'
      '每页只写页型与内容要点，布局/坐标/配色/节奏全部引擎推导。',
  'type': 'object',
  'required': ['slides'],
  'properties': {
    'title': {'type': 'string', 'description': '文档标题'},
    'style': {
      'description': '风格 id（内置或工作区，调 pptx_styles）或内联风格对象',
      'oneOf': [
        {'type': 'string'},
        {'type': 'object'},
      ],
    },
    'layout': {
      'enum': ['16x9', '16:9', '4x3', '4:3'],
      'description': '画布比例，默认 16x9',
    },
    'slides': {
      'type': 'array',
      'minItems': 1,
      'items': {r'$ref': '#/definitions/outlineSlide'},
    },
  },
  'definitions': {
    'outlineSlide': {
      'type': 'object',
      'description': '一页大纲；kind 默认 content',
      'properties': {
        'kind': {
          'enum': ['cover', 'toc', 'section', 'content', 'end'],
        },
        'title': {'type': 'string', 'description': '页标题（toc 可省，其余必填）'},
        'subtitle': {'type': 'string', 'description': 'cover 副标题'},
        'meta': {'type': 'string', 'description': 'cover/end 页脚（日期/署名）'},
        'lead': {'type': 'string', 'description': 'section 导语'},
        'label': {
          'type': 'string',
          'description': 'section 序号标签，省略时自动 01/02/… 递进',
        },
        'items': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'toc/end 条目；toc 省略时自动取各 section 标题',
        },
        'notes': {'type': 'string', 'description': '演讲者备注，原样透传'},
        'layout': {
          'enum': [
            'focus',
            'split',
            'asymmetric',
            'columns',
            'hierarchy',
            'hero',
            'grid',
          ],
          'description': '内容页布局，省略时引擎按要点数 + 密度交替自动选',
        },
        'points': {
          'type': 'array',
          'minItems': 1,
          'maxItems': 6,
          'description':
              '内容页要点（1-6 条），每条映射为一张卡片：字符串→text；'
              '{title,desc}→text；{value,label,desc?}→data；'
              '{title?,items[≥2]}→list；{title?,tags[≥3]}→tags；'
              '{title?,steps[≥3]}→process',
          'items': {
            'oneOf': [
              {'type': 'string'},
              {'type': 'object'},
            ],
          },
        },
      },
    },
  },
};

/// 把结构化大纲确定性展开为完整 deck.json（JSON 对象，可直接交给
/// pptx_check / pptx_render）。大纲非法时抛 [DeckParseException]，
/// 错误消息带 `outline.slides[i]` 定位。
Map<String, Object?> buildDeckDraft(Map<String, Object?> outline) {
  final rawSlides = outline['slides'];
  if (rawSlides is! List || rawSlides.isEmpty) {
    throw DeckParseException('outline 缺少非空数组 "slides"');
  }
  final sectionTitles = <String>[
    for (final s in rawSlides)
      if (s is Map && s['kind'] == 'section' && s['title'] is String)
        s['title']! as String,
  ];
  final slides = <Map<String, Object?>>[];
  final errors = <String>[];
  var contentIndex = 0;
  var sectionIndex = 0;
  for (final (i, raw) in rawSlides.indexed) {
    final where = 'outline.slides[$i]';
    if (raw is! Map) {
      errors.add('$where 必须是 JSON 对象');
      continue;
    }
    final s = raw.cast<String, Object?>();
    try {
      final kind = (s['kind'] as String?) ?? 'content';
      final layout = switch (kind) {
        'cover' => _passThrough(
          s,
          'cover',
          const ['title', 'subtitle', 'meta'],
          required: 'title',
          where: where,
        ),
        'toc' => _toc(s, sectionTitles, where),
        'section' => _section(s, ++sectionIndex, where),
        'end' => _passThrough(
          s,
          'end',
          const ['title', 'items', 'meta'],
          required: 'title',
          where: where,
        ),
        'content' => _content(s, contentIndex++, where),
        _ => throw DeckParseException(
          '$where 未知 kind "$kind"（支持 cover/toc/section/content/end）',
        ),
      };
      slides.add({
        'layout': layout,
        if (s['notes'] is String) 'notes': s['notes'],
      });
    } on DeckParseException catch (e) {
      errors.addAll(e.messages);
    }
  }
  if (errors.isNotEmpty) throw DeckParseException.all(errors);
  return {
    if (outline['title'] is String) 'title': outline['title'],
    if (outline['style'] != null) 'style': outline['style'],
    if (outline['layout'] is String) 'layout': outline['layout'],
    'slides': slides,
  };
}

Map<String, Object?> _passThrough(
  Map<String, Object?> s,
  String type,
  List<String> keys, {
  required String required,
  required String where,
}) {
  if (s[required] is! String || (s[required]! as String).isEmpty) {
    throw DeckParseException('$where($type) 缺少非空字符串 "$required"');
  }
  return {
    'type': type,
    for (final k in keys)
      if (s[k] != null) k: s[k],
  };
}

Map<String, Object?> _toc(
  Map<String, Object?> s,
  List<String> sectionTitles,
  String where,
) {
  final items = s['items'] is List ? s['items']! as List : sectionTitles;
  if (items.length < 2 || items.length > 6) {
    throw DeckParseException(
      '$where(toc) 需要 2-6 条目录条目（自动取 section 标题时也需 2-6 个章节），'
      '收到 ${items.length}',
    );
  }
  return {
    'type': 'toc',
    if (s['title'] != null) 'title': s['title'],
    'items': items,
  };
}

Map<String, Object?> _section(
  Map<String, Object?> s,
  int ordinal,
  String where,
) {
  final layout = _passThrough(
    s,
    'section',
    const ['title', 'label', 'lead'],
    required: 'title',
    where: where,
  );
  layout.putIfAbsent('label', () => ordinal.toString().padLeft(2, '0'));
  return layout;
}

Map<String, Object?> _content(
  Map<String, Object?> s,
  int contentIndex,
  String where,
) {
  if (s['title'] is! String || (s['title']! as String).isEmpty) {
    throw DeckParseException('$where(content) 缺少非空字符串 "title"');
  }
  final rawPoints = s['points'];
  if (rawPoints is! List || rawPoints.isEmpty) {
    throw DeckParseException('$where(content) 缺少非空数组 "points"（1-6 条要点）');
  }
  if (rawPoints.length > 6) {
    throw DeckParseException(
      '$where(content) 的 points 最多 6 条（收到 ${rawPoints.length}）：'
      '拆成两页或合并要点',
    );
  }
  final cards = <Map<String, Object?>>[
    for (final (j, p) in rawPoints.indexed)
      _pointToCard(p, '$where.points[$j]'),
  ];
  final layout = (s['layout'] as String?) ?? _autoLayout(cards, contentIndex);
  return {'type': layout, 'title': s['title'], 'cards': cards};
}

/// 一条要点 → 一张卡片，按字段确定性分派。
Map<String, Object?> _pointToCard(Object? point, String where) {
  if (point is String) {
    if (point.isEmpty) throw DeckParseException('$where 不能是空字符串');
    return {
      'type': 'text',
      'body': [point],
    };
  }
  if (point is! Map) {
    throw DeckParseException('$where 必须是字符串或对象');
  }
  final p = point.cast<String, Object?>();
  if (p['value'] != null) {
    return {
      'type': 'data',
      'value': p['value'].toString(),
      if (p['label'] != null) 'label': p['label'],
      if (p['desc'] != null) 'desc': p['desc'],
    };
  }
  if (p['steps'] is List) {
    return {
      'type': 'process',
      if (p['title'] != null) 'title': p['title'],
      'steps': p['steps'],
    };
  }
  if (p['tags'] is List) {
    return {
      'type': 'tags',
      if (p['title'] != null) 'title': p['title'],
      'tags': p['tags'],
    };
  }
  if (p['items'] is List) {
    return {
      'type': 'list',
      if (p['title'] != null) 'title': p['title'],
      'items': p['items'],
    };
  }
  final body = switch (p['desc'] ?? p['body']) {
    final String d when d.isNotEmpty => [d],
    final List l when l.isNotEmpty => l,
    _ => null,
  };
  if (body == null) {
    throw DeckParseException(
      '$where 至少要有 desc/body（正文）、value（数据）、items（列表）、'
      'tags（标签）或 steps（流程）之一',
    );
  }
  return {
    'type': 'text',
    if (p['title'] != null) 'title': p['title'],
    'body': body,
  };
}

/// 按卡片数选布局，同数量的布局在内容页序列上交替（密度节奏）。
String _autoLayout(List<Map<String, Object?>> cards, int contentIndex) =>
    switch (cards.length) {
      1 => 'focus',
      2 => contentIndex.isEven ? 'split' : 'asymmetric',
      3 => contentIndex.isEven ? 'columns' : 'hierarchy',
      _ => 'grid',
    };
