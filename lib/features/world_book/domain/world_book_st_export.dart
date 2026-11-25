import 'dart:convert';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

/// 导出为 SillyTavern 原生 World Info 时，无法一比一表达而做了降级的类别。
/// 每类带受影响的条目数，由 UI 汇总成导出后的提示。
enum WorldBookStExportIssue {
  /// 「聊天顶部」在 ST 没有对应位置，改为「角色定义之后」（position 1）。
  topOfChat,

  /// 「聊天底部」改为 @深度 0（ST 等价写法，语义一致，仅提示）。
  bottomOfChat,

  /// 正则关键词改写为 ST 的 `/pattern/flags` 形式；ST 从新到旧逐条扫描消息，
  /// 匹配结果可能略有不同。
  regexKeywords,

  /// sticky / cooldown / delay 原样导出，但 ST 的计时边界略有不同。
  timers,

  /// 存在正优先级：order 已整体平移以保持相对顺序（ST 的 order 不宜为负）。
  priorityShifted,

  /// 同一注入深度混用了用户与助手角色，ST 按固定角色顺序排列。
  mixedDepthRoles,

  /// 内容以 `@@` 开头，ST 会把首行当作装饰器（decorator）解析。
  decoratorContent,

  /// 整本书处于关闭状态；ST 文件没有整本开关，条目按各自开关导出。
  bookDisabled,
}

/// 降级说明文案（UI 展示用）。
String worldBookStExportIssueLabel(WorldBookStExportIssue issue) =>
    switch (issue) {
      WorldBookStExportIssue.topOfChat =>
        '「聊天顶部」在 SillyTavern 中没有对应位置，已改为「角色定义之后」',
      WorldBookStExportIssue.bottomOfChat => '「聊天底部」已转为 @深度 0（效果相同）',
      WorldBookStExportIssue.regexKeywords =>
        '正则关键词已转为 /…/ 形式，匹配结果可能与本应用略有不同',
      WorldBookStExportIssue.timers => '持续 / 冷却 / 延迟已导出，但 SillyTavern 的计时方式略有不同',
      WorldBookStExportIssue.priorityShifted =>
        '有正优先级的条目，order 已整体平移以保持相对顺序',
      WorldBookStExportIssue.mixedDepthRoles =>
        '同一深度混用了用户和助手角色，SillyTavern 会按固定角色顺序排列',
      WorldBookStExportIssue.decoratorContent =>
        '内容以 @@ 开头，SillyTavern 会把首行当作装饰器解析',
      WorldBookStExportIssue.bookDisabled =>
        '这本书已关闭，但 SillyTavern 没有整本开关，条目按各自的开关导出',
    };

class WorldBookStExport {
  const WorldBookStExport({required this.json, required this.issues});

  /// 编码好的 ST World Info JSON（缩进两格）。
  final String json;

  /// 降级类别 → 受影响的条目数（[WorldBookStExportIssue.bookDisabled] 计 1）。
  final Map<WorldBookStExportIssue, int> issues;

  bool get hasIssues => issues.isNotEmpty;
}

/// ST World Info 的 position 编码（world-info.js `world_info_position`）。
const int _stBefore = 0;
const int _stAfter = 1;
const int _stAtDepth = 4;

/// ST 的 role 编码（`extension_prompt_roles`）：0 system、1 user、2 assistant。
int _stRole(WorldBookInjectionRole role) =>
    role == WorldBookInjectionRole.assistant ? 2 : 1;

/// 把一本世界书编码为 SillyTavern 原生 World Info JSON，
/// 是 [parseWorldBookImport] ST 分支的逆映射：
///
/// - priority → order：导入时 `priority = -order`，导出取 `order = -priority`；
///   有正优先级时整体平移使最小 order 为 0（相对顺序不变）。
/// - 条目顺序：导入按整数键升序读出后**倒序**还原（ST 对同 order 条目倒序拼装），
///   所以导出时最后一个条目放在键 `0`，往上递增；`displayIndex` 保持本应用的
///   列表顺序，在 ST 编辑器里看到的顺序与这里一致。
/// - 位置：系统提示词之前 / 之后 → 0 / 1；指定深度 → 4 + depth + role；
///   聊天底部 → 4 @ depth 0；聊天顶部无对应，降级为 1。
/// - 正则关键词写成 `/pattern/i`（区分大小写时不带 i），未转义的 `/` 会转义。
WorldBookStExport encodeWorldBookStExport(WorldBook book) {
  final issues = <WorldBookStExportIssue, int>{};
  void hit(WorldBookStExportIssue issue) =>
      issues[issue] = (issues[issue] ?? 0) + 1;

  if (!book.enabled) issues[WorldBookStExportIssue.bookDisabled] = 1;

  final entries = book.entries;
  final maxPriority = entries.fold<int>(
    0,
    (m, e) => e.priority > m ? e.priority : m,
  );
  if (maxPriority > 0) {
    issues[WorldBookStExportIssue.priorityShifted] = entries
        .where((e) => e.priority > 0)
        .length;
  }

  // 同一深度的角色集合（只看启用的「指定深度 / 聊天底部」条目）。
  final depthRoles = <int, Set<int>>{};
  for (final e in entries) {
    if (!e.enabled) continue;
    final depth = switch (e.position) {
      WorldBookInjectionPosition.atDepth => e.injectDepth,
      WorldBookInjectionPosition.bottomOfChat => 0,
      _ => null,
    };
    if (depth != null) {
      depthRoles.putIfAbsent(depth, () => <int>{}).add(_stRole(e.role));
    }
  }

  final out = <String, Map<String, dynamic>>{};
  final n = entries.length;
  for (var listIndex = 0; listIndex < n; listIndex++) {
    final e = entries[listIndex];
    final uid = n - 1 - listIndex;

    final (int position, int depth, int? role) = switch (e.position) {
      WorldBookInjectionPosition.beforeSystemPrompt => (
        _stBefore,
        e.injectDepth,
        null,
      ),
      WorldBookInjectionPosition.afterSystemPrompt => (
        _stAfter,
        e.injectDepth,
        null,
      ),
      WorldBookInjectionPosition.atDepth => (
        _stAtDepth,
        e.injectDepth,
        _stRole(e.role),
      ),
      WorldBookInjectionPosition.bottomOfChat => (_stAtDepth, 0, _stRole(e.role)),
      WorldBookInjectionPosition.topOfChat => (_stAfter, e.injectDepth, null),
    };
    if (e.position == WorldBookInjectionPosition.topOfChat) {
      hit(WorldBookStExportIssue.topOfChat);
    }
    if (e.position == WorldBookInjectionPosition.bottomOfChat) {
      hit(WorldBookStExportIssue.bottomOfChat);
    }
    if (e.enabled &&
        position == _stAtDepth &&
        (depthRoles[depth]?.length ?? 0) > 1) {
      hit(WorldBookStExportIssue.mixedDepthRoles);
    }

    final keys = e.useRegex
        ? [for (final k in e.keywords) _toStRegex(k, e.caseSensitive)]
        : List<String>.of(e.keywords);
    if (!e.constantActive && e.useRegex && e.keywords.isNotEmpty) {
      hit(WorldBookStExportIssue.regexKeywords);
    }
    if (e.sticky != 0 || e.cooldown != 0 || e.delay != 0) {
      hit(WorldBookStExportIssue.timers);
    }
    if (e.content.startsWith('@@')) {
      hit(WorldBookStExportIssue.decoratorContent);
    }

    out['$uid'] = <String, dynamic>{
      'uid': uid,
      'key': keys,
      'keysecondary': const <String>[],
      'comment': e.name,
      'content': e.content,
      'constant': e.constantActive,
      'vectorized': false,
      'selective': true,
      'selectiveLogic': 0,
      'addMemo': true,
      'order': maxPriority - e.priority,
      'position': position,
      'disable': !e.enabled,
      'excludeRecursion': false,
      'preventRecursion': false,
      'delayUntilRecursion': false,
      'probability': 100,
      'useProbability': true,
      'depth': depth,
      'group': '',
      'groupOverride': false,
      'groupWeight': 100,
      'scanDepth': e.scanDepth,
      'caseSensitive': e.caseSensitive,
      'matchWholeWords': null,
      'useGroupScoring': null,
      'automationId': '',
      'role': role,
      'sticky': e.sticky,
      'cooldown': e.cooldown,
      'delay': e.delay,
      'displayIndex': listIndex,
    };
  }

  // 键按数值升序写出，便于人工审阅（ST 读取时也按整数键排序）。
  final ordered = <String, Map<String, dynamic>>{
    for (var i = 0; i < n; i++) '$i': out['$i']!,
  };
  final json = const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
    'name': book.name,
    if (book.description.isNotEmpty) 'description': book.description,
    'entries': ordered,
  });
  return WorldBookStExport(json: json, issues: issues);
}

/// 本应用的正则关键词（裸 pattern）→ ST 的 `/pattern/flags`。
String _toStRegex(String pattern, bool caseSensitive) {
  // 转义未被反斜杠转义的 `/`，否则 ST 会在第一个 `/` 处截断。
  final buf = StringBuffer();
  var escaping = false;
  for (final ch in pattern.split('')) {
    if (!escaping && ch == '/') {
      buf.write(r'\/');
    } else {
      buf.write(ch);
    }
    escaping = !escaping && ch == r'\';
  }
  return '/$buf/${caseSensitive ? '' : 'i'}';
}

/// ST 导出的文件名：在普通导出名上加 `_sillytavern` 后缀，避免与无损导出混淆。
String worldBookStExportFileName(String baseFileName) =>
    baseFileName.replaceFirst(
      RegExp(r'\.json$', caseSensitive: false),
      '_sillytavern.json',
    );
