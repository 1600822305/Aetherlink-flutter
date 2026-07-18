// 工作区 hooks 信任存储（Hooks H2）。
//
// hook 是任意 shell 命令，随仓库带的 `.aetherlink/hooks.json` 不能默认
// 执行（否则克隆一个恶意仓库就拿到执行权）。用户在设置页审阅并信任
// 某工作区当前的 hooks 内容后才生效；文件内容一变，信任自动失效，
// 需重新审阅。存储：workspaceId → 已信任的 hooks.json 原文。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

/// Settings-store key for trusted hooks contents.
const String kAgentTrustedHooksKey = 'agent_trusted_hooks';

/// JSON 编码（`{workspaceId: 原文}`）。
String encodeAgentTrustedHooks(Map<String, String> trusted) =>
    jsonEncode(trusted);

/// 解码；坏数据返回 null，非字符串条目丢弃。
Map<String, String>? decodeAgentTrustedHooks(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return {
      for (final entry in decoded.entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
  } catch (_) {
    return null;
  }
}

final agentHooksTrustProvider =
    NotifierProvider<AgentHooksTrustNotifier, Map<String, String>>(
  AgentHooksTrustNotifier.new,
);

class AgentHooksTrustNotifier extends Notifier<Map<String, String>> {
  /// 异步加载完成前不写库，避免加载期间的写入覆盖存量（同权限规则存储）。
  bool _loaded = false;

  @override
  Map<String, String> build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kAgentTrustedHooksKey)
        .then((raw) {
      final stored = decodeAgentTrustedHooks(raw) ?? const <String, String>{};
      final pendingWrites = state;
      _loaded = true;
      if (stored.isNotEmpty) state = {...stored, ...pendingWrites};
      if (pendingWrites.isNotEmpty) _persist();
    });
    return const {};
  }

  /// 信任 [workspaceId] 当前的 hooks.json 内容 [content]。
  void trust(String workspaceId, String content) {
    state = {...state, workspaceId: content};
    _persist();
  }

  /// 撤销对 [workspaceId] 的信任。
  void revoke(String workspaceId) {
    if (!state.containsKey(workspaceId)) return;
    state = {...state}..remove(workspaceId);
    _persist();
  }

  void _persist() {
    if (!_loaded) return;
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kAgentTrustedHooksKey, encodeAgentTrustedHooks(state));
  }
}
