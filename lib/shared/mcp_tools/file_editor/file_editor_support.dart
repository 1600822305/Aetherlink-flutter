// Shared helpers for the `@aether/file-editor` built-in MCP server.
//
// Workspace resolution + path navigation + JSON envelope helpers, kept apart
// from the individual tool handlers so each file stays small (企业级 模块化).
//
// SAF caveat: a workspace entry's `path` is an **opaque** `content://` URI —
// never split or build it by string. To navigate a relative `sub_path` we walk
// the directory tree by listing each level and matching child entries by name.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_backend_provider.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';

/// A resolved workspace plus its backend, ready for a read handler to use.
class ResolvedWorkspace {
  const ResolvedWorkspace(this.workspace, this.backend);

  final Workspace workspace;
  final WorkspaceBackend backend;
}

/// Thrown by the helpers below to short-circuit a handler with a clean,
/// model-facing error message (turned into an error [McpToolResult]).
class FileEditorError implements Exception {
  const FileEditorError(this.message);
  final String message;
}

const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

/// A successful tool result: `{ success: true, data: ... }`.
McpToolResult fileEditorOk(Object? data) =>
    McpToolResult(_prettyJson.convert({'success': true, 'data': data}));

/// A failed tool result: `{ success: false, error: ... }`, flagged as error.
McpToolResult fileEditorError(String message) => McpToolResult(
      _prettyJson.convert({'success': false, 'error': message}),
      isError: true,
    );

/// Reads a required string [key] from [args]; throws [FileEditorError] when
/// missing or blank.
String requireString(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FileEditorError('缺少必需参数: $key');
}

/// Reads an optional string [key] from [args]; returns null when absent or
/// blank, and tolerates non-string values by stringifying them (so a model
/// passing the wrong JSON type doesn't blow up with a `CastError`).
String? optionalString(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value == null) return null;
  final s = value is String ? value : value.toString();
  return s.trim().isEmpty ? null : s;
}

/// Reads an optional list-of-strings [key] from [args]. Accepts a JSON array
/// (each element stringified) or a single comma-separated string; returns an
/// empty list when absent. Never throws on a wrong-typed value.
List<String> optionalStringList(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value == null) return const [];
  final Iterable<Object?> raw = value is List ? value : value.toString().split(',');
  return raw
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();
}

/// Reads an optional int [key] from [args] (accepts num or numeric string).
int? optionalInt(Map<String, Object?> args, String key) {
  final value = args[key];
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Reads an optional bool [key], defaulting to [fallback].
bool optionalBool(Map<String, Object?> args, String key, {bool fallback = false}) {
  final value = args[key];
  if (value is bool) return value;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return fallback;
}

/// All workspaces the user has opened (最近打开 list, newest first).
Future<List<Workspace>> loadWorkspaces(Ref ref) =>
    ref.read(workspaceStoreProvider.future);

/// Resolves the `workspace` argument — accepts a 1-based index (e.g. "1"), a
/// workspace ID, or a workspace name — to a [ResolvedWorkspace]. Throws
/// [FileEditorError] when the list is empty or nothing matches.
Future<ResolvedWorkspace> resolveWorkspace(
  Ref ref,
  Map<String, Object?> args,
) async {
  final workspaces = await loadWorkspaces(ref);
  if (workspaces.isEmpty) {
    throw const FileEditorError(
      '当前没有任何工作区，请先在工作区页面「打开文件夹」后再试。',
    );
  }
  final raw = requireString(args, 'workspace').trim();

  final index = int.tryParse(raw);
  if (index != null && index >= 1 && index <= workspaces.length) {
    return _resolve(ref, workspaces[index - 1]);
  }
  for (final w in workspaces) {
    if (w.id == raw) return _resolve(ref, w);
  }
  for (final w in workspaces) {
    if (w.name == raw) return _resolve(ref, w);
  }
  throw FileEditorError('找不到工作区: "$raw"。可用 list_workspaces 查看编号/ID/名称。');
}

ResolvedWorkspace _resolve(Ref ref, Workspace workspace) =>
    ResolvedWorkspace(workspace, ref.read(workspaceBackendProvider(workspace)));

/// Resolves the backend for a workspace by its [id]. Throws when not found.
Future<WorkspaceBackend> resolveWorkspaceById(Ref ref, String id) async {
  final workspaces = await loadWorkspaces(ref);
  for (final w in workspaces) {
    if (w.id == id) return ref.read(workspaceBackendProvider(w));
  }
  throw FileEditorError('找不到工作区: $id');
}

/// Walks [rootPath] down a slash-separated [subPath] by listing each level and
/// matching children by name (since opaque SAF URIs can't be built by hand).
/// Returns the opaque path of the target directory/file. An empty/blank
/// [subPath] returns [rootPath] unchanged.
Future<String> navigateSubPath(
  WorkspaceBackend backend,
  String rootPath,
  String? subPath,
) async {
  final segments = (subPath ?? '')
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s != '.')
      .toList();
  var current = rootPath;
  for (final segment in segments) {
    final entries = await backend.listDir(current);
    WorkspaceEntry? match;
    for (final e in entries) {
      if (e.name == segment) {
        match = e;
        break;
      }
    }
    if (match == null) {
      throw FileEditorError('路径不存在: $subPath（在 "$segment" 处找不到）');
    }
    current = match.path;
  }
  return current;
}

/// Serialises a [WorkspaceEntry] for a tool result.
Map<String, Object?> entryJson(WorkspaceEntry e) => {
      'name': e.name,
      'path': e.path,
      'type': e.isDirectory ? 'directory' : 'file',
      'size': e.size,
      'mtime': e.mtime,
      if (e.isHidden) 'isHidden': true,
    };

/// Hard cap on entries returned by [listRecursive], so a deep/huge workspace
/// tree can't produce a giant payload that bloats the model context or stalls
/// the UI. When hit, the walk stops early and the caller reports it truncated.
const int kMaxRecursiveEntries = 2000;

/// Result of [listRecursive]: the flattened entries plus whether the
/// [kMaxRecursiveEntries] cap cut the walk short.
class RecursiveListing {
  const RecursiveListing(this.entries, {required this.truncated});
  final List<Map<String, Object?>> entries;
  final bool truncated;
}

/// Recursively lists [path] up to [maxDepth] levels deep, flattening into a
/// list of entry JSON maps (directories first within each level). [maxDepth]
/// of 1 means the immediate children only. Stops once [kMaxRecursiveEntries]
/// entries are collected (`truncated == true`).
Future<RecursiveListing> listRecursive(
  WorkspaceBackend backend,
  String path,
  int maxDepth,
) async {
  final out = <Map<String, Object?>>[];
  var truncated = false;
  Future<void> walk(String dir, int depth) async {
    if (truncated) return;
    final entries = await backend.listDir(dir);
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    for (final e in entries) {
      if (out.length >= kMaxRecursiveEntries) {
        truncated = true;
        return;
      }
      out.add(entryJson(e));
      if (e.isDirectory && depth < maxDepth) {
        await walk(e.path, depth + 1);
      }
    }
  }

  await walk(path, 1);
  return RecursiveListing(out, truncated: truncated);
}
