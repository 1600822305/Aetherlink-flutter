// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_tools_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the MCP 工具 总开关 + 调用模式, the Flutter port of the web `useMCPTools`
/// hook. Both values persist under their own Drift key/value entries
/// (`mcp-tools-enabled` / `mcp-mode`), exactly like the web Dexie keys, and
/// survive a restart.
///
/// `keepAlive: true`: an app-level preference read by the 设置 tab now and, once
/// the request layer lands (Phase C), by the chat send pipeline to decide
/// whether and how to expose MCP tools to the model.

@ProviderFor(McpToolsController)
final mcpToolsControllerProvider = McpToolsControllerProvider._();

/// Holds the MCP 工具 总开关 + 调用模式, the Flutter port of the web `useMCPTools`
/// hook. Both values persist under their own Drift key/value entries
/// (`mcp-tools-enabled` / `mcp-mode`), exactly like the web Dexie keys, and
/// survive a restart.
///
/// `keepAlive: true`: an app-level preference read by the 设置 tab now and, once
/// the request layer lands (Phase C), by the chat send pipeline to decide
/// whether and how to expose MCP tools to the model.
final class McpToolsControllerProvider
    extends $NotifierProvider<McpToolsController, McpToolsState> {
  /// Holds the MCP 工具 总开关 + 调用模式, the Flutter port of the web `useMCPTools`
  /// hook. Both values persist under their own Drift key/value entries
  /// (`mcp-tools-enabled` / `mcp-mode`), exactly like the web Dexie keys, and
  /// survive a restart.
  ///
  /// `keepAlive: true`: an app-level preference read by the 设置 tab now and, once
  /// the request layer lands (Phase C), by the chat send pipeline to decide
  /// whether and how to expose MCP tools to the model.
  McpToolsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpToolsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpToolsControllerHash();

  @$internal
  @override
  McpToolsController create() => McpToolsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(McpToolsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<McpToolsState>(value),
    );
  }
}

String _$mcpToolsControllerHash() =>
    r'8a340138854bca831d4620c2c2483b0883e63076';

/// Holds the MCP 工具 总开关 + 调用模式, the Flutter port of the web `useMCPTools`
/// hook. Both values persist under their own Drift key/value entries
/// (`mcp-tools-enabled` / `mcp-mode`), exactly like the web Dexie keys, and
/// survive a restart.
///
/// `keepAlive: true`: an app-level preference read by the 设置 tab now and, once
/// the request layer lands (Phase C), by the chat send pipeline to decide
/// whether and how to expose MCP tools to the model.

abstract class _$McpToolsController extends $Notifier<McpToolsState> {
  McpToolsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<McpToolsState, McpToolsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<McpToolsState, McpToolsState>,
              McpToolsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
