// 用户在设置页手动添加的智能体 hooks（全局，App 内持久化）。
//
// 对标 LiveAgent 的 HookDef：每条 hook 有名称、事件、启用开关，在页面里
// 直接增删改，不依赖仓库文件；由用户亲手添加，天然可信，不走文件信任
// 门槛。执行时启用中的手动 hooks 与已信任的仓库 `.aetherlink/hooks.json`
// 合并（手动在前），命令跑在任务绑定工作区的终端里。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';

/// Settings-store key for manual hooks.
const String kAgentManualHooksKey = 'agent_manual_hooks';

/// 一条手动 hook：名称 + 启用开关 + hook 本体。
class AgentManualHook {
  const AgentManualHook({
    required this.name,
    this.enabled = true,
    required this.hook,
  });

  final String name;
  final bool enabled;
  final AgentHook hook;

  AgentManualHook copyWith({String? name, bool? enabled, AgentHook? hook}) =>
      AgentManualHook(
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        hook: hook ?? this.hook,
      );
}

/// JSON 编码（list of {name, enabled, event, matcher, pattern, command,
/// timeout}）。
String encodeAgentManualHooks(List<AgentManualHook> hooks) => jsonEncode([
      for (final h in hooks)
        {
          'name': h.name,
          'enabled': h.enabled,
          'event': h.hook.event.name,
          'matcher': h.hook.matcher,
          'pattern': h.hook.pattern,
          'command': h.hook.command,
          'timeout': h.hook.timeoutSeconds,
        },
    ]);

/// 解码；坏数据返回 null，缺 command / 未知事件的条目丢弃。
List<AgentManualHook>? decodeAgentManualHooks(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final list = jsonDecode(raw);
    if (list is! List) return null;
    final hooks = <AgentManualHook>[];
    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;
      final command = item['command'];
      if (command is! String || command.trim().isEmpty) continue;
      final event = AgentHookEvent.values
          .where((e) => e.name == item['event'])
          .firstOrNull;
      if (event == null) continue;
      final name = item['name'];
      final matcher = item['matcher'];
      final pattern = item['pattern'];
      final timeout = item['timeout'];
      hooks.add(AgentManualHook(
        name: name is String && name.isNotEmpty ? name : command,
        enabled: item['enabled'] != false,
        hook: AgentHook(
          event: event,
          matcher: matcher is String && matcher.isNotEmpty ? matcher : '*',
          pattern: pattern is String && pattern.isNotEmpty ? pattern : '*',
          command: command,
          timeoutSeconds: timeout is int && timeout > 0
              ? timeout
              : kAgentHookDefaultTimeoutSeconds,
        ),
      ));
    }
    return hooks;
  } catch (_) {
    return null;
  }
}

final agentManualHooksProvider =
    NotifierProvider<AgentManualHooksNotifier, List<AgentManualHook>>(
  AgentManualHooksNotifier.new,
);

class AgentManualHooksNotifier extends Notifier<List<AgentManualHook>> {
  /// 异步加载完成前不写库，避免加载期间的写入覆盖存量（同权限规则存储）。
  bool _loaded = false;

  @override
  List<AgentManualHook> build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kAgentManualHooksKey)
        .then((raw) {
      final stored = decodeAgentManualHooks(raw) ?? const <AgentManualHook>[];
      final pendingAdds = state;
      _loaded = true;
      if (stored.isNotEmpty) state = [...stored, ...pendingAdds];
      if (pendingAdds.isNotEmpty) _persist();
    });
    return const [];
  }

  void add(AgentManualHook hook) {
    state = [...state, hook];
    _persist();
  }

  void updateAt(int index, AgentManualHook hook) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..[index] = hook;
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
        .saveSetting(kAgentManualHooksKey, encodeAgentManualHooks(state));
  }
}
