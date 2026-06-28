// Persistence for the "last editing session" — which workspace was open and
// which file tabs (plus the active one) were showing in the middle page — so
// re-entering the workspace restores it like an IDE.
//
// Stored as a single JSON object in the same Drift-backed KV store as the
// recent-workspace list. Only the last session is kept (switching workspaces
// overwrites it); per-tab transient state (font size, scroll) is not persisted.

import 'dart:convert';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';

/// Setting key for the persisted editing session.
const String kWorkspaceSessionKey = 'workspace_session';

/// Setting key for the "进入工作区时自动恢复上次会话" preference (`'true'` /
/// `'false'`). Absent means enabled (the default, IDE-like behaviour).
const String kWorkspaceAutoRestoreKey = 'workspace_auto_restore';

/// The persisted middle-page session: the open file tabs of [workspaceId] and
/// which one was active.
class WorkspaceSession {
  const WorkspaceSession({
    required this.workspaceId,
    required this.tabs,
    this.activePath,
  });

  final String workspaceId;
  final List<WorkspaceEntry> tabs;
  final String? activePath;

  String encode() => jsonEncode({
    'workspaceId': workspaceId,
    'activePath': activePath,
    'tabs': [for (final t in tabs) t.toJson()],
  });

  static WorkspaceSession? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final id = decoded['workspaceId'];
      if (id is! String) return null;
      final rawTabs = decoded['tabs'];
      final tabs = <WorkspaceEntry>[
        if (rawTabs is List)
          for (final item in rawTabs)
            if (item is Map)
              WorkspaceEntry.fromJson(Map<String, dynamic>.from(item)),
      ];
      return WorkspaceSession(
        workspaceId: id,
        tabs: tabs,
        activePath: decoded['activePath'] as String?,
      );
    } on FormatException {
      return null;
    }
  }
}
