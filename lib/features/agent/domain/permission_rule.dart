// 智能体权限规则引擎（审批重构 PR1，纯 Dart 可单测）。
//
// 对标 OpenCode permission/index.ts 的最简实现：规则 =
// {permission, pattern, action} 三元组；规则层按低→高优先级拼接，
// 判定取「最后命中者」；无命中默认 ask。Claude Code 式语义：
// deny > ask > allow 不靠桶排序，而是靠层序——高优先级层追加
// 的规则天然覆盖低层。

/// 规则动作三态。
enum PermissionAction { allow, ask, deny }

/// 规则来源层（低→高优先级），用于 UI 展示与持久化归属。
enum PermissionRuleLayer {
  /// 内置默认（随版本迭代，用户不可改）。
  builtin,

  /// 用户全局设置（持久化）。
  userGlobal,

  /// 工作区级（如工作区根 .aetherlink/permissions.json）。
  workspace,

  /// 会话模式派生（Ask/Plan 禁写、Auto 工作区内直通等）。
  mode,

  /// 会话临时授权（审批卡「本任务允许…」，随任务结束丢弃）。
  session,
}

/// 一条权限规则。[permission] 为权限域（terminal / edit / read / fetch /
/// `mcp:<server>/<tool>` …），[pattern] 为通配模式（`npm run *`、
/// `src/**`、`domain:github.com`、`*`），两者均支持 `*` 通配。
class PermissionRule {
  const PermissionRule({
    required this.permission,
    this.pattern = '*',
    required this.action,
    this.layer = PermissionRuleLayer.builtin,
  });

  final String permission;
  final String pattern;
  final PermissionAction action;
  final PermissionRuleLayer layer;

  @override
  String toString() =>
      'PermissionRule($permission, $pattern, ${action.name}, ${layer.name})';
}

/// `*` 通配匹配（大小写不敏感；`*` 匹配任意串含空串）。
/// 其余字符按字面匹配，正则元字符全部转义。
/// 特例：尾部的 ` *`（空格加星）表示「该前缀本身或其后跟任意参数」，
/// 即 `git status *` 同时命中 `git status` 与 `git status --short`。
bool permissionWildcardMatch(String input, String pattern) {
  if (pattern == '*') return true;
  var body = pattern;
  var optionalTail = false;
  if (body.endsWith(' *')) {
    body = body.substring(0, body.length - 2);
    optionalTail = true;
  }
  final buffer = StringBuffer('^');
  for (final rune in body.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '*') {
      buffer.write('.*');
    } else {
      buffer.write(RegExp.escape(ch));
    }
  }
  if (optionalTail) buffer.write('( .*)?');
  buffer.write(r'$');
  return RegExp(buffer.toString(), caseSensitive: false).hasMatch(input);
}

/// 判定单个 (permission, pattern)：按 [layers]（低→高优先级）拼接后
/// 取最后命中的规则；无命中返回默认 ask 规则。
PermissionRule evaluatePermissionRule(
  String permission,
  String pattern,
  List<List<PermissionRule>> layers,
) {
  PermissionRule? matched;
  for (final layer in layers) {
    for (final rule in layer) {
      if (permissionWildcardMatch(permission, rule.permission) &&
          permissionWildcardMatch(pattern, rule.pattern)) {
        matched = rule;
      }
    }
  }
  return matched ??
      PermissionRule(
        permission: permission,
        pattern: '*',
        action: PermissionAction.ask,
      );
}

/// 一次工具调用的整体判定结果。
class PermissionDecision {
  const PermissionDecision({
    required this.action,
    required this.matched,
    this.askPatterns = const [],
  });

  final PermissionAction action;

  /// 决定性命中的规则：deny 时为命中的 deny 规则；allow 时为最后一条
  /// allow 命中；ask 时为首个需要询问的 pattern 的命中结果。
  final PermissionRule matched;

  /// action == ask 时，需要用户裁决的 pattern 子集。
  final List<String> askPatterns;
}

/// 判定一次调用（一个 permission + 多个 patterns）：
/// 任一 pattern 命中 deny → deny（立即返回）；全部 allow → allow；
/// 否则 ask，并给出需询问的 pattern 子集。
PermissionDecision evaluatePermissionRequest(
  String permission,
  List<String> patterns,
  List<List<PermissionRule>> layers,
) {
  final effective = patterns.isEmpty ? const ['*'] : patterns;
  final askPatterns = <String>[];
  PermissionRule? firstAsk;
  PermissionRule? lastAllow;
  for (final pattern in effective) {
    final rule = evaluatePermissionRule(permission, pattern, layers);
    switch (rule.action) {
      case PermissionAction.deny:
        return PermissionDecision(action: PermissionAction.deny, matched: rule);
      case PermissionAction.ask:
        firstAsk ??= rule;
        askPatterns.add(pattern);
      case PermissionAction.allow:
        lastAllow = rule;
    }
  }
  if (askPatterns.isNotEmpty) {
    return PermissionDecision(
      action: PermissionAction.ask,
      matched: firstAsk!,
      askPatterns: askPatterns,
    );
  }
  return PermissionDecision(
    action: PermissionAction.allow,
    matched: lastAllow!,
  );
}
