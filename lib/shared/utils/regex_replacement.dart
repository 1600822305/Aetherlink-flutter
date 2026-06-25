import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';

/// 正则替换工具函数 — 在消息发送 / 显示时应用助手的正则规则。
///
/// `regexUtils.ts` 的迁移（`applyRegexRule` / `applyRegexRules` /
/// `applyRegexRulesForSending` / `applyRegexRulesForDisplay` /
/// `hasApplicableRules`）。Web 版用 JavaScript 的 `String.replace`，捕获组以
/// `$1`、整段匹配以 `$&` 引用；Dart 的 `String.replaceAll` 不解释这些占位符，
/// 因此 [_expandReplacement] 手动展开模板以保持一致语义。

/// 应用单个正则规则到 [text]，返回替换后的文本。规则未启用、文本为空或
/// 表达式无效时原样返回（无效正则吞掉异常，避免影响其余规则）。
String applyRegexRule(String text, AssistantRegex rule) {
  if (text.isEmpty || !rule.enabled || rule.pattern.isEmpty) {
    return text;
  }
  try {
    final regex = RegExp(rule.pattern);
    return text.replaceAllMapped(
      regex,
      (match) => _expandReplacement(rule.replacement, match),
    );
  } catch (_) {
    return text;
  }
}

/// 按顺序应用 [rules] 中适用于 [scope] 的启用规则。[visualOnly] 为 null 时
/// 应用全部；为 true/false 时只应用对应 `visualOnly` 的规则。
String applyRegexRules(
  String text,
  List<AssistantRegex>? rules,
  AssistantRegexScope scope, {
  bool? visualOnly,
}) {
  if (text.isEmpty || rules == null || rules.isEmpty) {
    return text;
  }
  var result = text;
  for (final rule in rules) {
    if (!rule.enabled) continue;
    if (!rule.scopes.contains(scope)) continue;
    if (visualOnly != null && rule.visualOnly != visualOnly) continue;
    result = applyRegexRule(result, rule);
  }
  return result;
}

/// 发送前处理：只应用非 `visualOnly` 的规则（迁移
/// `applyRegexRulesForSending`）。
String applyRegexRulesForSending(
  String content,
  List<AssistantRegex>? rules,
  AssistantRegexScope scope,
) => applyRegexRules(content, rules, scope, visualOnly: false);

/// 显示处理：应用全部规则（含 `visualOnly`，迁移
/// `applyRegexRulesForDisplay`）。
String applyRegexRulesForDisplay(
  String content,
  List<AssistantRegex>? rules,
  AssistantRegexScope scope,
) => applyRegexRules(content, rules, scope);

/// 是否存在适用于 [scope] 的启用规则（迁移 `hasApplicableRules`）。
bool hasApplicableRules(
  List<AssistantRegex>? rules,
  AssistantRegexScope scope, {
  bool? visualOnly,
}) {
  if (rules == null || rules.isEmpty) return false;
  return rules.any((rule) {
    if (!rule.enabled) return false;
    if (!rule.scopes.contains(scope)) return false;
    if (visualOnly != null && rule.visualOnly != visualOnly) return false;
    return true;
  });
}

/// 展开 JavaScript 风格的替换模板，支持 `$$`(字面 `$`)、`$&`(整段匹配)、
/// `` $` ``(匹配前文本)、`$'`(匹配后文本) 与 `$1`..`$99` / `${name}` 捕获组。
/// 未知引用原样保留，与 JS `String.prototype.replace` 行为一致。
String _expandReplacement(String template, Match match) {
  if (!template.contains(r'$')) return template;
  final buffer = StringBuffer();
  for (var i = 0; i < template.length; i++) {
    final char = template[i];
    if (char != r'$' || i == template.length - 1) {
      buffer.write(char);
      continue;
    }
    final next = template[i + 1];
    if (next == r'$') {
      buffer.write(r'$');
      i++;
    } else if (next == '&') {
      buffer.write(match[0] ?? '');
      i++;
    } else if (next == '`') {
      buffer.write(match.input.substring(0, match.start));
      i++;
    } else if (next == "'") {
      buffer.write(match.input.substring(match.end));
      i++;
    } else if (next == '{') {
      final close = template.indexOf('}', i + 2);
      final name = close > i + 2 ? template.substring(i + 2, close) : '';
      final value = _namedGroup(match, name);
      if (close != -1 && value != null) {
        buffer.write(value);
        i = close;
      } else {
        buffer.write(char);
      }
    } else if (_isDigit(next)) {
      // 优先匹配两位组号，回退到一位（与 JS 一致）。
      final hasTwo = i + 2 < template.length && _isDigit(template[i + 2]);
      final twoDigit = hasTwo
          ? int.parse(template.substring(i + 1, i + 3))
          : -1;
      final oneDigit = int.parse(next);
      if (twoDigit != -1 && twoDigit <= match.groupCount) {
        buffer.write(match[twoDigit] ?? '');
        i += 2;
      } else if (oneDigit >= 1 && oneDigit <= match.groupCount) {
        buffer.write(match[oneDigit] ?? '');
        i++;
      } else {
        buffer.write(char);
      }
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

String? _namedGroup(Match match, String name) {
  if (name.isEmpty || match is! RegExpMatch) return null;
  try {
    return match.namedGroup(name) ?? '';
  } catch (_) {
    return null;
  }
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}
