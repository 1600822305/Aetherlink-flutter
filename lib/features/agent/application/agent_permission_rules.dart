// 用户全局权限规则存储（审批重构 PR2）：持久化的 userGlobal 规则层。
//
// 审批门把它与「旧工具授权白名单换算层」「会话临时规则层」拼接后交给
// 规则引擎判定（低→高优先级，最后命中者胜）。写入方：审批卡的
// pattern 级永久授权（PR3）与权限设置页（PR4）。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';

/// Settings-store key for the persisted rules.
const String kAgentPermissionRulesKey = 'agent_permission_rules';

/// JSON 编码（list of {permission, pattern, action}；layer 恒为 userGlobal，
/// 不落库）。
String encodeAgentPermissionRules(List<PermissionRule> rules) => jsonEncode([
      for (final rule in rules)
        {
          'permission': rule.permission,
          'pattern': rule.pattern,
          'action': rule.action.name,
        },
    ]);

/// 解码规则 JSON（用户全局存储与工作区 `.aetherlink/permissions.json`
/// 共用同一格式，[layer] 区分规则层）；坏数据返回 null，未知 action
/// 的条目丢弃。
List<PermissionRule>? decodeAgentPermissionRules(
  String? raw, {
  PermissionRuleLayer layer = PermissionRuleLayer.userGlobal,
}) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final list = jsonDecode(raw);
    if (list is! List) return null;
    final rules = <PermissionRule>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final permission = item['permission'];
      final pattern = item['pattern'];
      final action = PermissionAction.values
          .where((a) => a.name == item['action'])
          .firstOrNull;
      if (permission is! String || permission.isEmpty) continue;
      if (pattern is! String || pattern.isEmpty) continue;
      if (action == null) continue;
      rules.add(PermissionRule(
        permission: permission,
        pattern: pattern,
        action: action,
        layer: layer,
      ));
    }
    return rules;
  } catch (_) {
    return null;
  }
}

final agentPermissionRulesProvider =
    NotifierProvider<AgentPermissionRulesNotifier, List<PermissionRule>>(
  AgentPermissionRulesNotifier.new,
);

class AgentPermissionRulesNotifier extends Notifier<List<PermissionRule>> {
  /// 异步加载完成前不写库，避免加载期间 [add] 的规则把存量规则覆盖掉。
  bool _loaded = false;
  late Future<void> _ready;

  /// 持久规则加载完成的信号：审批门判定前 await，否则重启后紧接的
  /// 首次审批会拿到空规则层，「总是允许/永久白名单」看似失效。
  Future<void> ensureLoaded() => _ready;

  @override
  List<PermissionRule> build() {
    _ready = ref
        .read(appSettingsStoreProvider)
        .getSetting(kAgentPermissionRulesKey)
        .then((raw) {
      final stored = decodeAgentPermissionRules(raw) ?? const <PermissionRule>[];
      final pendingAdds = state;
      _loaded = true;
      if (stored.isNotEmpty) state = [...stored, ...pendingAdds];
      if (pendingAdds.isNotEmpty) _persist();
    }).catchError((_) {
      // 读库失败也要解除写保护，否则本次会话的新授权永远不落库。
      _loaded = true;
    });
    return const [];
  }

  void add(PermissionRule rule) {
    state = [...state, rule];
    _persist();
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
    _persist();
  }

  void _persist() {
    if (!_loaded) return;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentPermissionRulesKey, encodeAgentPermissionRules(state));
  }
}
