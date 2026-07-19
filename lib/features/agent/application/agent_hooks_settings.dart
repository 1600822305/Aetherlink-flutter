// Hooks 系统的 App 级设置（当前只有 disableAllHooks 全局开关）。
//
// 对标 Claude Code settings 的 `disableAllHooks`：开关打开时所有事件的
// hooks 执行全部短路（应急/调试/信任存疑时一键停用，不必逐条删除）。
// 只停「执行」，不改配置与信任状态；设置页的「试跑」是显式用户操作，
// 不受开关限制。短路点在执行层（app/di/agent_hooks_access.dart）。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

/// Settings-store key for the disable-all-hooks switch.
const String kAgentDisableAllHooksKey = 'agent_disable_all_hooks';

/// 编码：布尔 → 存储字符串。
String encodeAgentDisableAllHooks(bool value) => value ? 'true' : 'false';

/// 解码：只有明确的 'true' 视为开；缺失/坏数据一律回退 false
/// （默认不改变现有行为）。
bool decodeAgentDisableAllHooks(String? raw) => raw == 'true';

final agentDisableAllHooksProvider =
    NotifierProvider<AgentDisableAllHooksNotifier, bool>(
  AgentDisableAllHooksNotifier.new,
);

class AgentDisableAllHooksNotifier extends Notifier<bool> {
  /// 异步加载完成前不写库，避免加载期间的写入覆盖存量（同手动 hooks 存储）。
  bool _loaded = false;
  bool? _pendingWrite;

  @override
  bool build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kAgentDisableAllHooksKey)
        .then((raw) {
      final pending = _pendingWrite;
      _loaded = true;
      if (pending != null) {
        state = pending;
        _persist();
      } else {
        state = decodeAgentDisableAllHooks(raw);
      }
    });
    return false;
  }

  void set(bool value) {
    if (!_loaded) {
      _pendingWrite = value;
      state = value;
      return;
    }
    state = value;
    _persist();
  }

  void _persist() {
    ref.read(appSettingsStoreProvider).saveSetting(
        kAgentDisableAllHooksKey, encodeAgentDisableAllHooks(state));
  }
}
