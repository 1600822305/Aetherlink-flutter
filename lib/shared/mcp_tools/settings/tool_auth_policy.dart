// 工作区 MCP 工具授权策略：让用户按工具把 HITL 审批设为「免授权」（白名单）。
//
// 覆盖两个内置 server：`@aether/file-editor` 的写工具、`@aether/terminal` 的
// 命令执行工具。读类工具本来就不审批，不在此列。策略叠加在
// `toolNeedsConfirmation` 之上：命中白名单的工具跳过确认弹窗直接执行；
// 越出项目工作区 root 的终端命令不受白名单覆盖，仍强制审批
// （双作用域设计稿 §4.1 硬要求）。
//
// 持久化走 appSettingsStoreProvider（JSON 字符串列表，key = server::tool）。

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';

/// Settings-store key for the persisted policy.
const String kToolAuthPolicyKey = 'workspace_tool_auth_policy';

/// Risk badge shown next to a controllable tool in the settings UI.
enum ToolAuthRisk { medium, high }

/// One user-controllable (normally HITL-gated) tool of a built-in server.
class ToolAuthMeta {
  const ToolAuthMeta({
    required this.server,
    required this.name,
    required this.label,
    required this.description,
    required this.risk,
  });

  final String server;
  final String name;
  final String label;
  final String description;
  final ToolAuthRisk risk;

  String get key => '$server::$name';
}

/// All tools whose authorization the user may control, grouped by server.
/// Order matches the settings page layout (file-editor 中危 → 高危 → 终端).
const List<ToolAuthMeta> kToolAuthCatalog = [
  // ── @aether/file-editor 写工具 ──
  ToolAuthMeta(
    server: kFileEditorServerName,
    name: 'create_directory',
    label: '新建目录',
    description: '在指定目录下创建子目录',
    risk: ToolAuthRisk.medium,
  ),
  ToolAuthMeta(
    server: kFileEditorServerName,
    name: 'move',
    label: '移动/重命名',
    description: '把文件或目录移动到其他位置或改名',
    risk: ToolAuthRisk.medium,
  ),
  ToolAuthMeta(
    server: kFileEditorServerName,
    name: 'copy_file',
    label: '复制',
    description: '把文件或目录复制到其他位置',
    risk: ToolAuthRisk.medium,
  ),
  ToolAuthMeta(
    server: kFileEditorServerName,
    name: 'edit',
    label: '查找替换',
    description: '在文件中按查找串精确替换内容',
    risk: ToolAuthRisk.medium,
  ),
  ToolAuthMeta(
    server: kFileEditorServerName,
    name: 'write',
    label: '写入文件',
    description: '新建文件或用新内容覆盖整个文件',
    risk: ToolAuthRisk.high,
  ),
  ToolAuthMeta(
    server: kFileEditorServerName,
    name: 'delete_file',
    label: '删除',
    description: '删除文件或目录（不可恢复）',
    risk: ToolAuthRisk.high,
  ),
  // ── @aether/terminal 命令执行 ──
  ToolAuthMeta(
    server: kTerminalServerName,
    name: 'terminal_execute',
    label: '执行命令',
    description: '在终端执行一次性命令（越出项目工作区 root 的命令仍会审批）',
    risk: ToolAuthRisk.high,
  ),
  ToolAuthMeta(
    server: kTerminalServerName,
    name: 'terminal_session',
    label: '会话输入',
    description: '向长驻终端会话的进程写入输入（等同执行命令）',
    risk: ToolAuthRisk.high,
  ),
];

/// The user's tool authorization whitelist: tools in [autoApproved]
/// (keyed `server::tool`) skip the HITL confirmation prompt.
class ToolAuthPolicy {
  const ToolAuthPolicy({this.autoApproved = const {}});

  final Set<String> autoApproved;

  bool isAutoApproved(String server, String toolName) =>
      autoApproved.contains('$server::$toolName');

  ToolAuthPolicy withTool(String server, String toolName,
      {required bool autoApprove}) {
    final key = '$server::$toolName';
    final next = Set<String>.of(autoApproved);
    if (autoApprove) {
      next.add(key);
    } else {
      next.remove(key);
    }
    return ToolAuthPolicy(autoApproved: next);
  }

  String encode() => jsonEncode(autoApproved.toList()..sort());

  /// Decodes a persisted policy; unknown keys are dropped so stale entries
  /// (renamed/removed tools) never linger. Returns `null` on bad input.
  static ToolAuthPolicy? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return null;
      final known = {for (final m in kToolAuthCatalog) m.key};
      return ToolAuthPolicy(
        autoApproved: {
          for (final item in list)
            if (item is String && known.contains(item)) item,
        },
      );
    } catch (_) {
      return null;
    }
  }
}

final toolAuthPolicyProvider =
    NotifierProvider<ToolAuthPolicyNotifier, ToolAuthPolicy>(
  ToolAuthPolicyNotifier.new,
);

class ToolAuthPolicyNotifier extends Notifier<ToolAuthPolicy> {
  @override
  ToolAuthPolicy build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kToolAuthPolicyKey)
        .then((raw) {
      final policy = ToolAuthPolicy.decode(raw);
      if (policy != null) state = policy;
    });
    return const ToolAuthPolicy();
  }

  void setTool(String server, String toolName, {required bool autoApprove}) {
    state = state.withTool(server, toolName, autoApprove: autoApprove);
    ref
        .read(appSettingsStoreProvider)
        .saveSetting(kToolAuthPolicyKey, state.encode());
  }
}
