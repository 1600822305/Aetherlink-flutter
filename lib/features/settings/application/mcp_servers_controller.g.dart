// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_servers_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The configured MCP servers, persisted through the app-level key/value store
/// as a JSON list — the Phase A port of the web `MCPServerStore` + the
/// configuration slice of `MCPService` (add / update / remove / toggle / import
/// / addBuiltin). No connections are opened and no tools run yet; those depend
/// on the request layer (Phase C). The 外部服务器 tab is everything whose name is
/// not a built-in; the 内置工具 / 智能助手 tabs are driven by [kBuiltinMcpServers].

@ProviderFor(McpServers)
final mcpServersProvider = McpServersProvider._();

/// The configured MCP servers, persisted through the app-level key/value store
/// as a JSON list — the Phase A port of the web `MCPServerStore` + the
/// configuration slice of `MCPService` (add / update / remove / toggle / import
/// / addBuiltin). No connections are opened and no tools run yet; those depend
/// on the request layer (Phase C). The 外部服务器 tab is everything whose name is
/// not a built-in; the 内置工具 / 智能助手 tabs are driven by [kBuiltinMcpServers].
final class McpServersProvider
    extends $AsyncNotifierProvider<McpServers, List<McpServer>> {
  /// The configured MCP servers, persisted through the app-level key/value store
  /// as a JSON list — the Phase A port of the web `MCPServerStore` + the
  /// configuration slice of `MCPService` (add / update / remove / toggle / import
  /// / addBuiltin). No connections are opened and no tools run yet; those depend
  /// on the request layer (Phase C). The 外部服务器 tab is everything whose name is
  /// not a built-in; the 内置工具 / 智能助手 tabs are driven by [kBuiltinMcpServers].
  McpServersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpServersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpServersHash();

  @$internal
  @override
  McpServers create() => McpServers();
}

String _$mcpServersHash() => r'c54ac0f1a15fe618f607359f8156d957a698c883';

/// The configured MCP servers, persisted through the app-level key/value store
/// as a JSON list — the Phase A port of the web `MCPServerStore` + the
/// configuration slice of `MCPService` (add / update / remove / toggle / import
/// / addBuiltin). No connections are opened and no tools run yet; those depend
/// on the request layer (Phase C). The 外部服务器 tab is everything whose name is
/// not a built-in; the 内置工具 / 智能助手 tabs are driven by [kBuiltinMcpServers].

abstract class _$McpServers extends $AsyncNotifier<List<McpServer>> {
  FutureOr<List<McpServer>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<McpServer>>, List<McpServer>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<McpServer>>, List<McpServer>>,
              AsyncValue<List<McpServer>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
