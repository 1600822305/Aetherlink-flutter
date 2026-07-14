import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

part 'workspace_store.g.dart';

/// Setting key for the persisted workspace list (a JSON array, newest
/// first), stored in the same Drift-backed KV store as other prefs.
const String kRecentWorkspacesKey = 'workspace_recent';

/// The workspace list, newest first. Hydrated from the KV store on
/// first build and written through on every change so it survives a restart.
@Riverpod(keepAlive: true)
class WorkspaceStore extends _$WorkspaceStore {
  @override
  Future<List<Workspace>> build() async {
    final raw = await ref.read(appSettingsStoreProvider).getSetting(
          kRecentWorkspacesKey,
        );
    return _decode(raw);
  }

  List<Workspace> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            Workspace.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> _persist(List<Workspace> workspaces) async {
    state = AsyncData(workspaces);
    await ref.read(appSettingsStoreProvider).saveSetting(
          kRecentWorkspacesKey,
          jsonEncode([for (final w in workspaces) w.toJson()]),
        );
  }

  /// Records an opened workspace: moves an existing entry (matched by
  /// [backendType] + [connectionId] + [root]) to the front with a fresh
  /// timestamp, or prepends a new one. [connectionId] is set for SSH / Termux
  /// workspaces (设计文档 §5.1) so the same [root] on two different servers
  /// stays distinct; SAF leaves it null. Returns the stored [Workspace].
  Future<Workspace> open({
    required String name,
    required WorkspaceBackendType backendType,
    required String root,
    WorkspaceScope scope = WorkspaceScope.project,
    bool isolatedHome = false,
    String? displayPath,
    String? connectionId,
  }) async {
    final current = state.value ?? const [];
    Workspace? existing;
    for (final w in current) {
      if (w.backendType == backendType &&
          w.connectionId == connectionId &&
          w.root == root) {
        existing = w;
        break;
      }
    }
    final entry = existing?.copyWith(lastOpenedAt: DateTime.now()) ??
        Workspace(
          id: generateId('ws'),
          name: name,
          backendType: backendType,
          scope: scope,
          isolatedHome: isolatedHome,
          root: root,
          displayPath: displayPath,
          connectionId: connectionId,
          lastOpenedAt: DateTime.now(),
        );
    final next = [
      entry,
      for (final w in current)
        if (w.id != entry.id) w,
    ];
    await _persist(next);
    return entry;
  }

  /// Renames the workspace [id] to [name] (a local display name only — the
  /// backend's real directory is untouched). Blank names are ignored.
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? const [];
    await _persist([
      for (final w in current)
        if (w.id == id) w.copyWith(name: trimmed) else w,
    ]);
  }

  /// Rebinds workspace [id] to a freshly-authorized [root] (the user re-picked
  /// a directory during 重新授权). Keeps the entry's id / name / position so
  /// re-authorization can never orphan the old record into a duplicate;
  /// replaces [displayPath] and refreshes the timestamp. Returns the updated
  /// [Workspace], or null when [id] is unknown.
  Future<Workspace?> rebind(
    String id, {
    required String root,
    String? displayPath,
  }) async {
    final current = state.value ?? const [];
    Workspace? updated;
    final next = <Workspace>[
      for (final w in current)
        if (w.id == id)
          updated = Workspace(
            id: w.id,
            name: w.name,
            backendType: w.backendType,
            scope: w.scope,
            isolatedHome: w.isolatedHome,
            root: root,
            displayPath: displayPath,
            // Keep the SshConnection reference across a rebind (设计文档 §5.1).
            connectionId: w.connectionId,
            lastOpenedAt: DateTime.now(),
          )
        else
          w,
    ];
    if (updated == null) return null;
    await _persist(next);
    return updated;
  }

  /// Rewrites workspaces whose [Workspace.connectionId] appears in [idMap]
  /// （旧连接 id → 合并后的存活连接 id），并把因此变得完全相同
  /// （backendType + connectionId + root）的条目去重，保留最新（列表头部）。
  /// SSH 连接档案去重合并时调用，保证工作区不指向已删除的档案。
  Future<void> remapConnections(Map<String, String> idMap) async {
    if (idMap.isEmpty) return;
    final current = state.value ?? const <Workspace>[];
    final seen = <String>{};
    final next = <Workspace>[];
    for (final w in current) {
      final mapped = idMap[w.connectionId];
      final entry =
          mapped == null ? w : w.copyWith(connectionId: mapped);
      final key = '${entry.backendType.name}|${entry.connectionId}|'
          '${entry.root}';
      if (entry.connectionId != null && !seen.add(key)) continue;
      next.add(entry);
    }
    await _persist(next);
  }

  /// Removes a workspace from the list.
  Future<void> remove(String id) async {
    final current = state.value ?? const [];
    await _persist([
      for (final w in current)
        if (w.id != id) w,
    ]);
  }

  /// Clears the entire workspace list.
  Future<void> clear() => _persist(const []);
}
