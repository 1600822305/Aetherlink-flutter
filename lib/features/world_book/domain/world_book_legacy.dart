import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// 读取 kelivo / RikkaHub 的旧版条目（`entries` 为数组、字段名不同的那种），
/// 转成 ST 原生结构。只用于导入这两家导出的文件。
///
/// 旧字段 → ST：
/// - `priority`（越大越先）→ `order = -priority`（越大越靠后），先后方向一致；
/// - `position` 字符串 → 数字：系统提示词之前 / 之后 → 0 / 1；指定深度 → 4；
///   聊天底部 → 4 @深度 1（旧引擎把它插在最后一个用户段之前）；聊天顶部 ST
///   没有对应，转成 1（系统提示词之后）；
/// - `useRegex` 为真时每个关键词改写成 `/pattern/flags`（不区分大小写带 `i`）；
/// - `constantActive` → `constant`；计时器 0 → null（ST 的「未设置」）。
WorldBookEntry worldBookEntryFromLegacyJson(Map<String, dynamic> json) {
  String str(Object? v) => v is String ? v : '';
  bool flag(Object? v, bool fallback) => v is bool ? v : fallback;
  int? number(Object? v) => v is num ? v.toInt() : null;
  int? timer(Object? v) {
    final n = number(v);
    return n == null || n <= 0 ? null : n;
  }

  final caseSensitive = flag(json['caseSensitive'], false);
  final useRegex = flag(json['useRegex'], false);
  final rawKeywords = json['keywords'];
  final keywords = rawKeywords is List<dynamic>
      ? [
          for (final k in rawKeywords)
            if (k is String && k.trim().isNotEmpty)
              useRegex ? _toStRegex(k.trim(), caseSensitive) : k.trim(),
        ]
      : const <String>[];

  final wire = str(json['position']).trim().toUpperCase();
  final legacyDepth = number(json['injectDepth']) ?? 4;
  final (position, depth) = switch (wire) {
    'BEFORE_SYSTEM_PROMPT' => (
      WorldBookInjectionPosition.beforeSystemPrompt,
      legacyDepth,
    ),
    'AT_DEPTH' => (WorldBookInjectionPosition.atDepth, legacyDepth),
    'BOTTOM_OF_CHAT' => (WorldBookInjectionPosition.atDepth, 1),
    _ => (WorldBookInjectionPosition.afterSystemPrompt, legacyDepth),
  };

  return WorldBookEntry(
    id: str(json['id']),
    name: str(json['name']),
    enabled: flag(json['enabled'], true),
    content: str(json['content']),
    keywords: keywords,
    constant: flag(json['constantActive'], false),
    order: -(number(json['priority']) ?? 0),
    position: position,
    depth: depth.clamp(0, WorldBookEntry.kMaxNumber),
    role: str(json['role']).trim().toUpperCase() == 'ASSISTANT'
        ? WorldBookInjectionRole.assistant
        : WorldBookInjectionRole.user,
    caseSensitive: caseSensitive,
    scanDepth: number(json['scanDepth']),
    sticky: timer(json['sticky']),
    cooldown: timer(json['cooldown']),
    delay: timer(json['delay']),
  );
}

/// 裸正则 → ST 的 `/pattern/flags`，转义未转义的 `/`。
String _toStRegex(String pattern, bool caseSensitive) {
  final buf = StringBuffer();
  var escaping = false;
  for (final ch in pattern.split('')) {
    buf.write(!escaping && ch == '/' ? r'\/' : ch);
    escaping = !escaping && ch == r'\';
  }
  return '/$buf/${caseSensitive ? '' : 'i'}';
}
