// Read-only handlers for the `@aether/file-editor` built-in MCP server.
//
// Each handler maps a tool call to the workspace `WorkspaceBackend` (SAF on
// Android) and returns a JSON envelope via the helpers in
// `file_editor_support.dart`. Names/params mirror the original AetherLink
// `@aether/file-editor` server 1:1.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// `list_workspaces` — all opened workspaces, numbered (1-based) for use as the
/// `workspace` argument of the other tools.
Future<McpToolResult> listWorkspaces(Ref ref) async {
  final workspaces = await loadWorkspaces(ref);
  final items = <Map<String, Object?>>[];
  for (var i = 0; i < workspaces.length; i++) {
    final Workspace w = workspaces[i];
    items.add({
      'index': i + 1,
      'id': w.id,
      'name': w.name,
      'backend': w.backendType.name,
      'path': w.displayPath ?? w.name,
    });
  }
  return fileEditorOk({'count': items.length, 'workspaces': items});
}

/// `get_workspace_files` — list a workspace's files, resolving `sub_path` by
/// name and optionally recursing up to `max_depth` levels.
Future<McpToolResult> getWorkspaceFiles(
  Ref ref,
  Map<String, Object?> args,
) async {
  final resolved = await resolveWorkspace(ref, args);
  final backend = resolved.backend;
  final subPath = optionalString(args, 'sub_path');
  final dir = await navigateSubPath(backend, resolved.workspace.root, subPath);

  final recursive = optionalBool(args, 'recursive');
  if (recursive) {
    final maxDepth = (optionalInt(args, 'max_depth') ?? 3).clamp(1, 10);
    final listing = await listRecursive(backend, dir, maxDepth);
    return fileEditorOk({
      'workspace': resolved.workspace.name,
      'path': dir,
      'recursive': true,
      'maxDepth': maxDepth,
      'count': listing.entries.length,
      if (listing.truncated) 'truncated': true,
      'files': listing.entries,
    });
  }

  final entries = await backend.listDir(dir);
  entries.sort(_dirsFirst);
  return fileEditorOk({
    'workspace': resolved.workspace.name,
    'path': dir,
    'recursive': false,
    'count': entries.length,
    'files': [for (final e in entries) entryJson(e)],
  });
}

/// `list_files` — list the directory at an opaque `path`, optionally recursive.
Future<McpToolResult> listFiles(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final backend = await backendForPath(ref, path);
  if (optionalBool(args, 'recursive')) {
    final maxDepth = (optionalInt(args, 'max_depth') ?? 5).clamp(1, 10);
    final listing = await listRecursive(backend, path, maxDepth);
    return fileEditorOk({
      'path': path,
      'maxDepth': maxDepth,
      'count': listing.entries.length,
      if (listing.truncated) 'truncated': true,
      'files': listing.entries,
    });
  }
  final entries = await backend.listDir(path);
  entries.sort(_dirsFirst);
  return fileEditorOk({
    'path': path,
    'count': entries.length,
    'files': [for (final e in entries) entryJson(e)],
  });
}

/// `read_file` — read one (`path`) or many (`files`) files, optionally limited
/// to a `start_line`..`end_line` range (1-based, inclusive).
Future<McpToolResult> readFile(Ref ref, Map<String, Object?> args) async {
  final files = args['files'];
  if (files is List && files.isNotEmpty) {
    final results = <Map<String, Object?>>[];
    var errors = 0;
    for (final item in files) {
      if (item is! Map) continue;
      final m = item.map((k, v) => MapEntry(k.toString(), v as Object?));
      final path = optionalString(m, 'path');
      if (path == null) {
        errors++;
        results.add({'status': 'error', 'error': '缺少必需参数: path'});
        continue;
      }
      try {
        final one = await _readOne(
            ref, path, optionalInt(m, 'start_line'), optionalInt(m, 'end_line'));
        results.add({'status': 'success', ...one});
      } on FileEditorError catch (e) {
        errors++;
        results.add({'path': path, 'status': 'error', 'error': e.message});
      } catch (e) {
        errors++;
        results.add({'path': path, 'status': 'error', 'error': '读取失败: $e'});
      }
    }
    return fileEditorOk({
      'count': results.length,
      'successCount': results.length - errors,
      'errorCount': errors,
      'files': results,
    });
  }
  final path = requireString(args, 'path');
  final one = await _readOne(
      ref, path, optionalInt(args, 'start_line'), optionalInt(args, 'end_line'));
  return fileEditorOk(one);
}

/// `get_file_info` — metadata (size / mtime / type) plus line count for files.
Future<McpToolResult> getFileInfo(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final backend = await backendForPath(ref, path);
  final info = await backend.getFileInfo(path);
  final json = entryJson(info);
  if (!info.isDirectory) {
    try {
      json['lines'] = await backend.getLineCount(path);
    } catch (_) {
      // Line count is best-effort (e.g. binary files); omit on failure.
    }
  }
  return fileEditorOk(json);
}

/// `search_files` — search by file name and/or content under `directory`.
Future<McpToolResult> searchFiles(Ref ref, Map<String, Object?> args) async {
  final directory = requireString(args, 'directory');
  final query = requireString(args, 'query');
  final backend = await backendForPath(ref, directory);

  final searchType = switch (optionalString(args, 'search_type')?.toLowerCase()) {
    'content' => WorkspaceSearchType.content,
    'both' => WorkspaceSearchType.both,
    _ => WorkspaceSearchType.name,
  };
  final fileTypes = optionalStringList(args, 'file_types');

  final results = await backend.searchFiles(
    directory,
    query,
    searchType: searchType,
    fileTypes: fileTypes,
  );
  return fileEditorOk({
    'directory': directory,
    'query': query,
    'searchType': searchType.name,
    'count': results.length,
    'files': [for (final e in results) entryJson(e)],
  });
}

// ===== internals =====

int _dirsFirst(WorkspaceEntry a, WorkspaceEntry b) {
  if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
  return a.name.compareTo(b.name);
}

Future<Map<String, Object?>> _readOne(
  Ref ref,
  String path,
  int? startLine,
  int? endLine,
) async {
  final backend = await backendForPath(ref, path);
  if (startLine != null && endLine != null) {
    final range = await backend.readFileRange(path, startLine, endLine);
    return {
      'path': path,
      'startLine': startLine,
      'endLine': endLine,
      'content': range.content,
      'rangeHash': range.rangeHash,
    };
  }
  final content = await backend.readFile(path);
  return {'path': path, 'content': content};
}
