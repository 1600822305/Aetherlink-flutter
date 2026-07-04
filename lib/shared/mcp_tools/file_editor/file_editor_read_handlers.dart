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
/// to a `start_line`..`end_line` range (1-based, inclusive). Content lines are
/// prefixed `N | ` by default (`line_numbers=false` for raw text) so the model
/// can reference exact lines in insert_content / apply_diff without counting.
Future<McpToolResult> readFile(Ref ref, Map<String, Object?> args) async {
  final withLineNumbers = optionalBool(args, 'line_numbers', fallback: true);
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
            ref, path, optionalInt(m, 'start_line'), optionalInt(m, 'end_line'),
            withLineNumbers: withLineNumbers);
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
      ref, path, optionalInt(args, 'start_line'), optionalInt(args, 'end_line'),
      withLineNumbers: withLineNumbers);
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

  final useRegex = optionalBool(args, 'use_regex');
  final results = await backend.searchFiles(
    directory,
    query,
    searchType: searchType,
    fileTypes: fileTypes,
    useRegex: useRegex,
  );

  // 内容搜索时把命中行（行号 + 内容）一并带回，模型不用再整读文件定位。
  final withMatches = searchType != WorkspaceSearchType.name;
  final files = <Map<String, Object?>>[];
  var totalMatches = 0;
  for (final e in results) {
    final json = entryJson(e);
    if (withMatches && !e.isDirectory && totalMatches < _kMaxTotalMatches) {
      final matches = await _matchingLines(backend, e.path, query, useRegex);
      if (matches != null) {
        totalMatches += matches.length;
        json['matches'] = matches;
      }
    }
    files.add(json);
  }
  return fileEditorOk({
    'directory': directory,
    'query': query,
    'searchType': searchType.name,
    if (useRegex) 'useRegex': true,
    'count': results.length,
    'files': files,
  });
}

/// Caps for [_matchingLines]: per-file / overall hit counts and per-line
/// snippet length, so a hot query can't flood the model context.
const int _kMaxMatchesPerFile = 5;
const int _kMaxTotalMatches = 100;
const int _kMaxMatchLineChars = 200;

/// The matching lines of [path] as `{line, text}` maps（1-based 行号，行内容
/// 截到 [_kMaxMatchLineChars] 字符）。Matching mirrors the backends' content
/// search: case-insensitive, regex or literal contains. Returns null when the
/// file can't be read as text (binary / too large / permission) — the entry
/// still rides in the results, just without `matches`.
Future<List<Map<String, Object?>>?> _matchingLines(
  WorkspaceBackend backend,
  String path,
  String query,
  bool useRegex,
) async {
  final String content;
  try {
    content = await backend.readFile(path);
  } catch (_) {
    return null;
  }
  final RegExp? pattern;
  try {
    pattern = useRegex ? RegExp(query, caseSensitive: false) : null;
  } catch (_) {
    return null;
  }
  final lowerQuery = query.toLowerCase();
  final matches = <Map<String, Object?>>[];
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final hit = pattern != null
        ? pattern.hasMatch(line)
        : line.toLowerCase().contains(lowerQuery);
    if (!hit) continue;
    final text = line.length > _kMaxMatchLineChars
        ? '${line.substring(0, _kMaxMatchLineChars)}…'
        : line;
    matches.add({'line': i + 1, 'text': text});
    if (matches.length >= _kMaxMatchesPerFile) break;
  }
  return matches;
}

// ===== internals =====

int _dirsFirst(WorkspaceEntry a, WorkspaceEntry b) {
  if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
  return a.name.compareTo(b.name);
}

/// 行号输出时附在 payload 里的提醒：行号前缀仅供定位，不是文件内容。
const String _kLineNumbersNote =
    '每行前的「N | 」是行号前缀，不属于文件内容；写入/SEARCH 块/替换时请用不含行号的原始文本。';

Future<Map<String, Object?>> _readOne(
  Ref ref,
  String path,
  int? startLine,
  int? endLine, {
  bool withLineNumbers = true,
}) async {
  final backend = await backendForPath(ref, path);
  // A range read kicks in when *either* bound is given: a missing start means
  // "from line 1", a missing end means "to the last line". (Previously both
  // had to be present or the whole file was returned silently.)
  if (startLine != null || endLine != null) {
    final start = startLine ?? 1;
    final end = endLine ?? await backend.getLineCount(path);
    if (start < 1) {
      throw FileEditorError('无效的 start_line: $start（必须 ≥ 1）');
    }
    if (end < start) {
      throw FileEditorError('无效的行范围: start_line=$start 大于 end_line=$end');
    }
    final range = await backend.readFileRange(path, start, end);
    return {
      'path': path,
      'startLine': start,
      'endLine': end,
      'totalLines': range.totalLines,
      'content': withLineNumbers
          ? numberLines(range.content, startAt: start)
          : range.content,
      'rangeHash': range.rangeHash,
      if (withLineNumbers) 'note': _kLineNumbersNote,
    };
  }
  final content = await backend.readFile(path);
  return {
    'path': path,
    'content': withLineNumbers ? numberLines(content) : content,
    if (withLineNumbers) 'note': _kLineNumbersNote,
  };
}
