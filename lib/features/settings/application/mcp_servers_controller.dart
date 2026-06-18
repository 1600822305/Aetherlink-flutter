import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';

part 'mcp_servers_controller.g.dart';

/// Storage key for the configured MCP server list (port of the web
/// `MCPServerStore`'s Dexie key `mcp_servers`). Persisted as a single JSON list
/// in the Drift key/value store, matching the web shape so configs round-trip.
const String kMcpServersSettingKey = 'mcp_servers';

/// Outcome of a JSON import: how many servers were added plus any per-server
/// `name: error` messages (mirrors the web `handleImportJson` partial result).
typedef McpImportResult = ({int imported, List<String> errors});

/// The configured MCP servers, persisted through the app-level key/value store
/// as a JSON list — the Phase A port of the web `MCPServerStore` + the
/// configuration slice of `MCPService` (add / update / remove / toggle / import
/// / addBuiltin). No connections are opened and no tools run yet; those depend
/// on the request layer (Phase C). The 外部服务器 tab is everything whose name is
/// not a built-in; the 内置工具 / 智能助手 tabs are driven by [kBuiltinMcpServers].
@Riverpod(keepAlive: true)
class McpServers extends _$McpServers {
  @override
  Future<List<McpServer>> build() async {
    final raw = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kMcpServersSettingKey);
    return _decode(raw);
  }

  List<McpServer> get _current => state.asData?.value ?? const <McpServer>[];

  /// Appends a freshly-built server and persists (port of `MCPService.addServer`).
  Future<void> add(McpServer server) async {
    await _commit(<McpServer>[..._current, server]);
  }

  /// Replaces the server sharing [server.id] and persists (port of
  /// `MCPService.updateServer`). Named [edit] to avoid `AsyncNotifier.update`.
  Future<void> edit(McpServer server) async {
    final next = _current.map((s) => s.id == server.id ? server : s).toList();
    await _commit(next);
  }

  /// Removes the server with [id] and persists (port of `MCPService.removeServer`).
  Future<void> remove(String id) async {
    await _commit(_current.where((s) => s.id != id).toList());
  }

  /// Flips a server's `isActive` and persists (port of `MCPService.toggleServer`).
  Future<void> toggleActive(String id, {required bool isActive}) async {
    final next = _current
        .map((s) => s.id == id ? s.copyWith(isActive: isActive) : s)
        .toList();
    await _commit(next);
  }

  /// Adds a built-in server from the catalog, giving it a fresh id and turning
  /// it on (port of `MCPService.addBuiltinServer`, which defaults `isActive`
  /// to `true`). A no-op when a server with the same name is already added.
  Future<void> addBuiltin(McpServer builtin) async {
    if (_current.any((s) => s.name == builtin.name)) return;
    final server = builtin.copyWith(
      id: 'builtin-${DateTime.now().millisecondsSinceEpoch}',
      isActive: true,
    );
    await _commit(<McpServer>[..._current, server]);
  }

  /// Parses a `{ "mcpServers": { name: {...} } }` document (Claude-desktop
  /// shape) and appends every entry, persisting once. Mirrors the web
  /// `handleImportJson`: each server gets a fresh id, type inference and
  /// `isActive: false`; per-server failures are collected rather than aborting.
  Future<McpImportResult> importFromJson(String raw) async {
    final decoded = jsonDecode(raw);
    final servers = decoded is Map<String, dynamic>
        ? decoded['mcpServers']
        : null;
    if (servers is! Map<String, dynamic>) {
      throw const FormatException('JSON 格式错误：缺少 mcpServers 字段');
    }

    final added = <McpServer>[];
    final errors = <String>[];
    servers.forEach((name, config) {
      try {
        if (config is! Map<String, dynamic>) {
          throw const FormatException('配置必须是对象');
        }
        added.add(_serverFromImport(name, config));
      } catch (error) {
        errors.add('$name: $error');
      }
    });

    if (added.isNotEmpty) {
      await _commit(<McpServer>[..._current, ...added]);
    }
    return (imported: added.length, errors: errors);
  }

  McpServer _serverFromImport(String name, Map<String, dynamic> config) {
    return McpServer(
      id: generateId('mcp'),
      name: name,
      type: _normalizeType(config['type'] as String?, config),
      description: '从 JSON 导入：$name',
      baseUrl: (config['url'] ?? config['baseUrl']) as String?,
      command: config['command'] as String?,
      headers: _stringMap(config['headers']),
      env: _stringMap(config['env']),
      args: _stringList(config['args']),
    );
  }

  /// Port of `mcpServerUtils.normalizeType`: tolerant alias matching plus
  /// inference from `command` (→ stdio) or `url` (→ sse).
  static McpServerType _normalizeType(String? type, Map<String, dynamic> cfg) {
    if (type != null) {
      final t = type.toLowerCase().replaceAll(RegExp('[-_]'), '');
      if (t == 'streamablehttp' || t == 'streamable') {
        return McpServerType.streamableHttp;
      }
      if (t == 'httpstream') return McpServerType.httpStream;
      if (t == 'inmemory' || t == 'memory') return McpServerType.inMemory;
      if (t == 'sse' || t == 'serversent' || t == 'serversentevents') {
        return McpServerType.sse;
      }
      if (t == 'stdio' || t == 'standardio') return McpServerType.stdio;
    }
    if (cfg['command'] != null) return McpServerType.stdio;
    if (cfg['url'] != null || cfg['baseUrl'] != null) return McpServerType.sse;
    return McpServerType.sse;
  }

  static Map<String, String>? _stringMap(Object? value) {
    if (value is! Map) return null;
    return value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }

  static List<String>? _stringList(Object? value) {
    if (value is! List) return null;
    return value.map((e) => e.toString()).toList();
  }

  Future<void> _commit(List<McpServer> next) async {
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(kMcpServersSettingKey, _encode(next));
    state = AsyncData<List<McpServer>>(next);
  }

  static String _encode(List<McpServer> servers) =>
      jsonEncode(servers.map((s) => s.toJson()).toList());

  static List<McpServer> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const <McpServer>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <McpServer>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(McpServer.fromJson)
        .toList();
  }
}
