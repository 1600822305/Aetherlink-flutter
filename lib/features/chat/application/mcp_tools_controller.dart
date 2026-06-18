import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';

part 'mcp_tools_controller.g.dart';

/// Storage key for the MCP 工具 总开关 — the web `mcp-tools-enabled` Dexie key.
const String kMcpToolsEnabledKey = 'mcp-tools-enabled';

/// Storage key for the 工具调用模式 — the web `mcp-mode` Dexie key.
const String kMcpModeKey = 'mcp-mode';

/// 工具调用机制 (port of `useMCPTools`'s `mcpMode`): [function] passes tools via
/// the model's native function-calling API; [prompt] injects them into the
/// system prompt and parses the model's XML `<tool_use>` locally.
enum McpMode {
  function,
  prompt;

  /// The persisted token (the web stores the raw `'function'` / `'prompt'`).
  String get storageValue => name;

  /// The sidebar label (web `函数调用` / `提示词注入`).
  String get label => this == McpMode.function ? '函数调用' : '提示词注入';

  static McpMode fromStorage(String? value) =>
      value == 'prompt' ? McpMode.prompt : McpMode.function;
}

/// The persisted MCP 工具 toggle + 调用模式 (port of `useMCPTools`).
class McpToolsState {
  const McpToolsState({this.enabled = false, this.mode = McpMode.function});

  /// 启用 MCP 工具 总开关 (`toolsEnabled`).
  final bool enabled;

  /// 工具调用模式 (`mcpMode`).
  final McpMode mode;

  McpToolsState copyWith({bool? enabled, McpMode? mode}) =>
      McpToolsState(enabled: enabled ?? this.enabled, mode: mode ?? this.mode);
}

/// Holds the MCP 工具 总开关 + 调用模式, the Flutter port of the web `useMCPTools`
/// hook. Both values persist under their own Drift key/value entries
/// (`mcp-tools-enabled` / `mcp-mode`), exactly like the web Dexie keys, and
/// survive a restart.
///
/// `keepAlive: true`: an app-level preference read by the 设置 tab now and, once
/// the request layer lands (Phase C), by the chat send pipeline to decide
/// whether and how to expose MCP tools to the model.
@Riverpod(keepAlive: true)
class McpToolsController extends _$McpToolsController {
  @override
  McpToolsState build() {
    _hydrate();
    return const McpToolsState();
  }

  Future<void> _hydrate() async {
    final repo = ref.read(chatRepositoryProvider);
    final enabled = await repo.getSetting(kMcpToolsEnabledKey);
    final mode = await repo.getSetting(kMcpModeKey);
    state = McpToolsState(
      enabled: enabled == 'true',
      mode: McpMode.fromStorage(mode),
    );
  }

  /// Toggles 启用 MCP 工具 (`toggleToolsEnabled`).
  void setEnabled({required bool enabled}) {
    state = state.copyWith(enabled: enabled);
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kMcpToolsEnabledKey, enabled.toString());
  }

  /// Sets 工具调用模式 (`handleMCPModeChange`).
  void setMode(McpMode mode) {
    state = state.copyWith(mode: mode);
    ref
        .read(chatRepositoryProvider)
        .saveSetting(kMcpModeKey, mode.storageValue);
  }
}
