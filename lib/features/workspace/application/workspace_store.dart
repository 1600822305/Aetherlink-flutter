import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

part 'workspace_store.g.dart';

/// Setting key for the persisted "最近打开" workspace list (a JSON array,
/// newest first), stored in the same Drift-backed KV store as other prefs.
const String kRecentWorkspacesKey = 'workspace_recent';

/// Cap on the remembered workspace count — older entries drop off the tail.
const int kMaxRecentWorkspaces = 20;

/// The "最近打开" workspace list, newest first. Hydrated from the KV store on
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
  /// [backendType] + [root]) to the front with a fresh timestamp, or prepends a
  /// new one. Returns the stored [Workspace].
  Future<Workspace> open({
    required String name,
    required WorkspaceBackendType backendType,
    required String root,
    String? displayPath,
  }) async {
    final current = state.value ?? const [];
    Workspace? existing;
    for (final w in current) {
      if (w.backendType == backendType && w.root == root) {
        existing = w;
        break;
      }
    }
    final entry = existing?.copyWith(lastOpenedAt: DateTime.now()) ??
        Workspace(
          id: generateId('ws'),
          name: name,
          backendType: backendType,
          root: root,
          displayPath: displayPath,
          lastOpenedAt: DateTime.now(),
        );
    final next = [
      entry,
      for (final w in current)
        if (w.id != entry.id) w,
    ];
    if (next.length > kMaxRecentWorkspaces) {
      next.removeRange(kMaxRecentWorkspaces, next.length);
    }
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
            root: root,
            displayPath: displayPath,
            lastOpenedAt: DateTime.now(),
          )
        else
          w,
    ];
    if (updated == null) return null;
    await _persist(next);
    return updated;
  }

  /// Removes a workspace from the "最近打开" list.
  Future<void> remove(String id) async {
    final current = state.value ?? const [];
    await _persist([
      for (final w in current)
        if (w.id != id) w,
    ]);
  }

  /// Clears the entire "最近打开" list.
  Future<void> clear() => _persist(const []);
}
