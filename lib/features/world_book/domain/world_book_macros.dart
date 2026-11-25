import 'dart:math';

/// 宏替换的上下文。名字字段对应 SillyTavern 的 `{{user}}` / `{{char}}`：
/// 本应用里 user = 用户资料里的名字（默认「用户」），char = 当前助手名。
class WorldBookMacroContext {
  const WorldBookMacroContext({
    this.user = '用户',
    this.char = '',
    this.model,
    this.now,
    this.random,
    this.pickSeed = '',
  });

  final String user;
  final String char;

  /// `{{model}}`；null 时该宏原样保留（评估世界书时还不知道最终模型）。
  final String? model;

  /// 时间类宏用的「现在」；null = `DateTime.now()`（测试可固定）。
  final DateTime? now;

  /// `{{random}}` / `{{roll}}` 用的随机源；null = 新建 [Random]。
  final Random? random;

  /// `{{pick}}` 的种子（如话题 id）：同一话题、同一位置的 pick 结果稳定，
  /// 与 ST 按聊天固定 pick 结果的行为一致。
  final String pickSeed;
}

const List<String> _kWeekdays = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六'];

String _pad2(int v) => v.toString().padLeft(2, '0');

/// 替换 [text] 里的 SillyTavern 宏（大小写不敏感），未知的宏原样保留。
///
/// 支持：
/// - 名字：`{{user}}`、`{{char}}`、`{{charIfNotGroup}}`、`{{group}}`（本应用
///   没有群聊，后两个都取 char）、`{{model}}`；旧写法 `<USER>` `<BOT>` `<CHAR>`
///   `<CHARIFNOTGROUP>` `<GROUP>`；
/// - 时间：`{{time}}`（HH:mm）、`{{date}}`（2026年11月26日）、`{{weekday}}`、
///   `{{isotime}}`、`{{isodate}}`；
/// - 文本：`{{newline}}`、`{{trim}}`（连同前后换行一起去掉）、`{{noop}}`、
///   `{{// 注释}}`、`{{reverse:文本}}`；
/// - 随机：`{{random::a::b}}` / `{{random:a,b}}`、`{{pick::a::b}}`（同一话题
///   同一位置结果稳定）、`{{roll:1d6}}` / `{{roll 2d6+1}}` / `{{roll:20}}`。
///
/// 替换顺序与 ST `substituteParams` 一致：先注释 / 空操作 / 换行 / trim，再随机，
/// 最后名字与时间。不处理嵌套宏。
String substituteWorldBookMacros(String text, WorldBookMacroContext ctx) {
  if (text.isEmpty || (!text.contains('{{') && !text.contains('<'))) {
    return text;
  }
  var out = text;

  out = out
      .replaceAll(RegExp(r'\{\{//[\s\S]*?\}\}'), '')
      .replaceAll(RegExp(r'\{\{noop\}\}', caseSensitive: false), '')
      .replaceAll(RegExp(r'\{\{newline\}\}', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'(?:\r?\n)*\{\{trim\}\}(?:\r?\n)*', caseSensitive: false),
        '',
      );

  final rnd = ctx.random ?? Random();
  out = out.replaceAllMapped(
    RegExp(r'\{\{random\s?::?([^}]*)\}\}', caseSensitive: false),
    (m) {
      final options = _options(m.group(1)!);
      return options.isEmpty ? '' : options[rnd.nextInt(options.length)];
    },
  );
  out = out.replaceAllMapped(
    RegExp(r'\{\{pick\s?::?([^}]*)\}\}', caseSensitive: false),
    (m) {
      final options = _options(m.group(1)!);
      if (options.isEmpty) return '';
      final seed = _fnv1a('${ctx.pickSeed}|${m.start}|${m.group(0)}');
      return options[Random(seed).nextInt(options.length)];
    },
  );
  out = out.replaceAllMapped(
    RegExp(r'\{\{roll[\s:]([^}]+)\}\}', caseSensitive: false),
    (m) => _roll(m.group(1)!.trim(), rnd) ?? m.group(0)!,
  );
  out = out.replaceAllMapped(
    RegExp(r'\{\{reverse:([\s\S]*?)\}\}', caseSensitive: false),
    (m) => String.fromCharCodes(m.group(1)!.runes.toList().reversed),
  );

  final now = ctx.now ?? DateTime.now();
  out = out.replaceAllMapped(
    RegExp(
      r'\{\{(user|char|charifnotgroup|group|model|time|date|weekday|isotime|isodate)\}\}',
      caseSensitive: false,
    ),
    (m) => switch (m.group(1)!.toLowerCase()) {
      'user' => ctx.user,
      'char' || 'charifnotgroup' || 'group' => ctx.char,
      'model' => ctx.model ?? m.group(0)!,
      'time' => '${_pad2(now.hour)}:${_pad2(now.minute)}',
      'date' => '${now.year}年${now.month}月${now.day}日',
      'weekday' => _kWeekdays[now.weekday % 7],
      'isotime' => '${_pad2(now.hour)}:${_pad2(now.minute)}',
      'isodate' =>
        '${now.year.toString().padLeft(4, '0')}-${_pad2(now.month)}-${_pad2(now.day)}',
      _ => m.group(0)!,
    },
  );
  out = out.replaceAllMapped(
    RegExp(r'<(USER|BOT|CHAR|CHARIFNOTGROUP|GROUP)>', caseSensitive: false),
    (m) => m.group(1)!.toUpperCase() == 'USER' ? ctx.user : ctx.char,
  );
  return out;
}

/// `a::b::c` 按 `::` 拆；否则按逗号拆（`\,` 表示字面逗号）。
List<String> _options(String raw) {
  if (raw.contains('::')) {
    return [for (final o in raw.split('::')) o.trim()];
  }
  const placeholder = '\u0000';
  return [
    for (final o in raw.replaceAll(r'\,', placeholder).split(','))
      o.replaceAll(placeholder, ',').trim(),
  ]..removeWhere((o) => o.isEmpty);
}

/// `XdY[+-Z]` 或纯数字 `Y`（= 1dY）。无法解析时返回 null（宏原样保留）。
String? _roll(String formula, Random rnd) {
  final f = RegExp(r'^\d+$').hasMatch(formula) ? '1d$formula' : formula;
  final m = RegExp(r'^(\d*)d(\d+)\s*([+-]\s*\d+)?$', caseSensitive: false)
      .firstMatch(f);
  if (m == null) return null;
  final count = int.tryParse(m.group(1)!) ?? 1;
  final sides = int.parse(m.group(2)!);
  if (count < 1 || count > 1000 || sides < 1) return null;
  var total = 0;
  for (var i = 0; i < count; i++) {
    total += rnd.nextInt(sides) + 1;
  }
  final mod = m.group(3);
  if (mod != null) total += int.parse(mod.replaceAll(' ', ''));
  return '$total';
}

/// 32 位 FNV-1a：跨平台稳定的字符串哈希（Dart 的 `hashCode` 不保证稳定）。
int _fnv1a(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// 扫描文本的一行：开启「包含名字」时加 `名字: ` 前缀（ST `world_info_include_names`）。
String worldBookScanLine(
  String text, {
  String? name,
  bool includeNames = true,
}) => includeNames && name != null && name.trim().isNotEmpty
    ? '${name.trim()}: $text'
    : text;
