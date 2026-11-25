import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';

/// 计时器状态在持久层（user 消息 metadata）里的键。
const String kWorldBookActivationMetadataKey = 'worldBook.activation';

/// ST `KNOWN_DECORATORS`。
const List<String> kWorldBookDecorators = ['@@activate', '@@dont_activate'];

/// 解析内容开头的装饰器行（ST `parseDecorators`）：
/// - 只有内容以 `@@` 开头时才解析；从第一行起连续的 `@@` 行都是装饰器行，
///   遇到第一行普通文本为止，剩下的才是内容；
/// - 已知装饰器（[kWorldBookDecorators]，按前缀匹配）收进列表；
/// - `@@@xxx` 是后备写法：只有上一行是**未知**装饰器时才生效（去掉一个 `@`），
///   否则忽略；
/// - 全部都是装饰器行时，内容保持原样（与 ST 一致）。
({List<String> decorators, String content}) parseWorldBookDecorators(
  String content,
) {
  if (!content.startsWith('@@')) return (decorators: const [], content: content);
  bool known(String line) {
    final data = line.startsWith('@@@') ? line.substring(1) : line;
    return kWorldBookDecorators.any(data.startsWith);
  }

  final lines = content.split('\n');
  final decorators = <String>[];
  var fallback = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.startsWith('@@')) {
      return (decorators: decorators, content: lines.sublist(i).join('\n'));
    }
    if (line.startsWith('@@@') && !fallback) continue;
    if (known(line)) {
      decorators.add(line.startsWith('@@@') ? line.substring(1) : line);
      fallback = false;
    } else {
      fallback = true;
    }
  }
  return (decorators: decorators, content: content);
}

/// 关键词匹配，语义对齐 SillyTavern `WorldInfoBuffer.matchKeys` 与
/// `checkWorldInfo` 里的次级关键词判定：
///
/// - 写成 `/pattern/flags` 的关键词按正则匹配原文，大小写由 flags 决定，
///   不受条目「区分大小写」影响；写法不合法时当普通文本；
/// - 普通关键词按 [WorldBookEntry.caseSensitive]（null 跟随全局）决定是否转小写；
/// - 全词匹配（null 跟随全局）只对单个词生效：`(?:^|\W)词(?:$|\W)`；
///   含空格的关键词仍是子串匹配；
/// - 主关键词任一命中后，启用了次级关键词且列表非空时再按四种逻辑判定。
abstract final class WorldBookActivation {
  /// [entry] 在扫描文本 [context] 上是否激活（不含计时器 / 概率 / 组）。
  /// 常驻条目总是激活；关闭或没有主关键词的非常驻条目不激活。
  static bool matches(
    WorldBookEntry entry,
    String context, {
    WorldBookSettings settings = WorldBookSettings.defaults,
  }) {
    if (!entry.enabled) return false;
    if (entry.constant) return true;
    bool hit(String key) => matchKey(context, key, entry, settings: settings);
    final primary = [
      for (final k in entry.keywords)
        if (k.trim().isNotEmpty) k,
    ];
    if (primary.isEmpty || !primary.any(hit)) return false;
    final secondary = [
      for (final k in entry.secondaryKeywords)
        if (k.trim().isNotEmpty) k,
    ];
    if (!entry.selective || secondary.isEmpty) return true;
    return switch (entry.secondaryLogic) {
      WorldBookSecondaryLogic.andAny => secondary.any(hit),
      WorldBookSecondaryLogic.andAll => secondary.every(hit),
      WorldBookSecondaryLogic.notAny => !secondary.any(hit),
      WorldBookSecondaryLogic.notAll => !secondary.every(hit),
    };
  }

  /// 包含组评分用的命中数（ST `WorldInfoBuffer.getScore`）：主关键词命中个数；
  /// 有次级关键词时，「且含任一」加上次级命中数，「且含全部」在全部命中时加上，
  /// 其余逻辑只算主关键词。没有主关键词时为 0。
  static int score(
    WorldBookEntry entry,
    String context, {
    WorldBookSettings settings = WorldBookSettings.defaults,
  }) {
    if (entry.keywords.isEmpty) return 0;
    bool hit(String key) => matchKey(context, key, entry, settings: settings);
    final primary = entry.keywords.where(hit).length;
    final secondary = entry.secondaryKeywords;
    if (secondary.isEmpty) return primary;
    final hits = secondary.where(hit).length;
    return switch (entry.secondaryLogic) {
      WorldBookSecondaryLogic.andAny => primary + hits,
      WorldBookSecondaryLogic.andAll =>
        hits == secondary.length ? primary + hits : primary,
      _ => primary,
    };
  }

  /// 单个关键词是否在 [haystack] 中命中（ST `matchKeys`）。
  static bool matchKey(
    String haystack,
    String key,
    WorldBookEntry entry, {
    WorldBookSettings settings = WorldBookSettings.defaults,
  }) {
    final regex = parseRegex(key);
    if (regex != null) return regex.hasMatch(haystack);
    final caseSensitive = entry.caseSensitive ?? settings.caseSensitive;
    final text = caseSensitive ? haystack : haystack.toLowerCase();
    final needle = (caseSensitive ? key : key.toLowerCase()).trim();
    if (needle.isEmpty) return false;
    final whole = entry.matchWholeWords ?? settings.matchWholeWords;
    if (!whole || needle.split(RegExp(r'\s+')).length > 1) {
      return text.contains(needle);
    }
    return RegExp(
      '(?:^|\\W)(${RegExp.escape(needle)})(?:\$|\\W)',
    ).hasMatch(text);
  }

  /// 把 ST 的 `/pattern/flags` 写法解析成正则；不是这种写法或表达式不合法
  /// 时返回 null（按普通关键词处理，与 ST `parseRegexFromString` 一致）。
  ///
  /// flags：`i` 忽略大小写、`m` 多行、`s` dotAll、`u` Unicode；`g` / `y` 对
  /// 「是否命中」没有影响，接受但忽略。重复的 flag 视为不合法。
  static RegExp? parseRegex(String raw) {
    final m = RegExp(r'^/([\s\S]+?)/([gimsuy]*)$').firstMatch(raw.trim());
    if (m == null) return null;
    final pattern = m.group(1)!;
    final flags = m.group(2)!;
    // ST：模式里出现未转义的 `/` 时不当正则。
    if (RegExp(r'(^|[^\\])/').hasMatch(pattern)) return null;
    if (flags.split('').toSet().length != flags.length) return null;
    try {
      return RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u'),
      );
    } on FormatException {
      return null;
    }
  }

  /// [raw] 是否写成了正则形式（`/.../flags`），不论表达式是否合法；
  /// 编辑器用它给「看起来是正则但无效」的关键词标红。
  static bool looksLikeRegex(String raw) =>
      RegExp(r'^/[\s\S]+/[a-z]*$').hasMatch(raw.trim());
}
