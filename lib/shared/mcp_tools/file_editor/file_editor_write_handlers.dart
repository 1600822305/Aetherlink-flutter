// Write/edit handlers for the `@aether/file-editor` built-in MCP server.
//
// Each handler maps a write tool call to the workspace `WorkspaceBackend`
// (SAF on Android), mirroring the original AetherLink file-editor tool set
// (write_to_file / create_file / rename_file / move_file / copy_file /
// delete_file / insert_content / apply_diff / replace_in_file).
//
// SAF caveat: a workspace entry's `path` is an **opaque** `content://` URI —
// never split or build it by string. New files are addressed by an opaque
// parent directory + a name, and moves/copies target an opaque parent dir.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// `write_to_file` — overwrite the full content of an existing file.
///
/// On SAF a brand-new file can't be addressed by an arbitrary path, so this
/// tool only overwrites an existing file; use `create_file` to make a new one.
Future<McpToolResult> writeToFile(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final raw = args['content'];
  if (raw == null) throw const FileEditorError('缺少必需参数: content');
  final text = raw is String ? raw : raw.toString();

  // Line-count guard — catch silently truncated content (e.g. a model that
  // replaced the body with "// rest of code unchanged").
  final expected = optionalInt(args, 'line_count');
  final actual = '\n'.allMatches(text).length + 1;
  if (expected != null && expected > 0 && actual < expected * 0.8) {
    if (_detectCodeOmission(text)) {
      throw FileEditorError(
        '内容可能被截断（实际 $actual 行，预期 $expected 行），并检测到代码省略标记'
        '（如 "// rest of code unchanged"）。请提供完整内容，或改用 apply_diff 增量修改。',
      );
    }
  }

  final processed = _removeCodeBlockMarkers(_unescapeHtmlEntities(text));
  final backend = await backendForPath(ref, path);

  WorkspaceEntry info;
  try {
    info = await backend.getFileInfo(path);
  } catch (_) {
    throw const FileEditorError(
      '目标文件不存在或无法访问。新建文件请用 create_file（传 parent_path + name）。',
    );
  }
  if (info.isDirectory) {
    throw const FileEditorError('目标是目录，无法作为文件写入。');
  }

  await backend.writeFile(path, processed);
  return fileEditorOk({
    'message': '文件更新成功',
    'path': path,
    'totalLines': '\n'.allMatches(processed).length + 1,
  });
}

/// `create_file` — create a new file under an opaque [parent_path] directory.
Future<McpToolResult> createFile(Ref ref, Map<String, Object?> args) async {
  final parentPath = requireString(args, 'parent_path');
  final name = requireString(args, 'name');
  final content = optionalString(args, 'content') ?? '';
  final overwrite = optionalBool(args, 'overwrite');

  final backend = await backendForPath(ref, parentPath);
  final existing = await findChildByName(backend, parentPath, name);
  if (existing != null) {
    if (!overwrite) {
      throw FileEditorError('「$name」已存在；如需覆盖请传 overwrite=true。');
    }
    if (existing.isDirectory) {
      throw FileEditorError('「$name」是一个目录，无法以文件覆盖。');
    }
    await backend.writeFile(existing.path, content);
    return fileEditorOk({
      'message': '文件已覆盖',
      'path': existing.path,
      'overwritten': true,
    });
  }

  final created = await backend.createFile(parentPath, name, content: content);
  return fileEditorOk({
    'message': '文件创建成功',
    'path': created,
    'overwritten': false,
  });
}

/// `rename_file` — rename a file or directory in place.
Future<McpToolResult> renameFile(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final newName = requireString(args, 'new_name');
  final backend = await backendForPath(ref, path);
  final newPath = await backend.rename(path, newName);
  return fileEditorOk({'message': '重命名成功', 'path': newPath, 'newName': newName});
}

/// `move_file` — move a file/dir into the opaque [destination_path] directory,
/// optionally renaming it to [new_name] in the same call.
///
/// When [new_name] is given the move lands directly under the new name
/// (copy-as-new-name then delete the source), so the destination is checked for
/// a `new_name` collision — not the source's original name. A plain move keeps
/// the source name and is checked accordingly.
Future<McpToolResult> moveFile(Ref ref, Map<String, Object?> args) async {
  final sourcePath = requireString(args, 'source_path');
  final destParent = requireString(args, 'destination_path');
  final newName = optionalString(args, 'new_name');
  final overwrite = optionalBool(args, 'overwrite');
  final backend = await backendForPath(ref, sourcePath);

  if (newName == null) {
    final newPath = await backend.move(sourcePath, destParent);
    return fileEditorOk({'message': '移动成功', 'path': newPath});
  }

  // Copy straight to the target name (collision is detected against new_name),
  // then remove the source. Not atomic: if the delete fails the copy is kept
  // and the error reports both locations.
  final newPath = await backend.copy(
    sourcePath,
    destParent,
    newName: newName,
    overwrite: overwrite,
  );
  try {
    final info = await backend.getFileInfo(sourcePath);
    await backend.delete(
      sourcePath,
      isDirectory: info.isDirectory,
      recursive: info.isDirectory,
    );
  } catch (e) {
    throw FileEditorError(
      '已复制到「$newName」，但删除原文件失败：$e。新文件位于：$newPath，原文件仍在：$sourcePath',
    );
  }
  return fileEditorOk({
    'message': '移动成功',
    'path': newPath,
    'renamedTo': newName,
  });
}

/// `copy_file` — copy a file/dir into the opaque [destination_path] directory.
Future<McpToolResult> copyFile(Ref ref, Map<String, Object?> args) async {
  final sourcePath = requireString(args, 'source_path');
  final destParent = requireString(args, 'destination_path');
  final newName = optionalString(args, 'new_name');
  final overwrite = optionalBool(args, 'overwrite');
  final backend = await backendForPath(ref, sourcePath);
  final newPath = await backend.copy(
    sourcePath,
    destParent,
    newName: newName,
    overwrite: overwrite,
  );
  return fileEditorOk({'message': '复制成功', 'path': newPath});
}

/// `delete_file` — delete a file or directory.
Future<McpToolResult> deleteFile(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final recursive = optionalBool(args, 'recursive', fallback: true);
  final backend = await backendForPath(ref, path);

  bool isDirectory = false;
  try {
    isDirectory = (await backend.getFileInfo(path)).isDirectory;
  } catch (_) {
    // Fall back to file deletion if metadata is unavailable.
  }
  await backend.delete(path, isDirectory: isDirectory, recursive: recursive);
  return fileEditorOk({'message': '删除成功', 'path': path});
}

/// `insert_content` — insert [content] relative to a 1-based [line].
///
/// `position` selects `before` (default) or `after` the line; `at_end=true`
/// appends to the file and needs no [line] at all.
Future<McpToolResult> insertContent(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final raw = args['content'];
  if (raw == null) throw const FileEditorError('缺少必需参数: content');
  final content = raw is String ? raw : raw.toString();
  final backend = await backendForPath(ref, path);
  final linesInserted = '\n'.allMatches(content).length + 1;

  // at_end — append without a line number.
  if (optionalBool(args, 'at_end')) {
    await backend.writeFile(path, content, append: true);
    return fileEditorOk({
      'message': '已在文件末尾追加内容',
      'path': path,
      'appended': true,
      'linesInserted': linesInserted,
    });
  }

  final line = optionalInt(args, 'line');
  if (line == null || line < 1) {
    throw const FileEditorError(
      '缺少或无效参数: line（必须是正整数）；如需追加到文件末尾请传 at_end=true。',
    );
  }
  final position = optionalString(args, 'position')?.toLowerCase() ?? 'before';
  if (position != 'before' && position != 'after') {
    throw FileEditorError('无效的 position: "$position"（应为 before 或 after）');
  }
  // "after line N" == insert before line N+1.
  final target = position == 'after' ? line + 1 : line;

  await backend.insertContent(path, target, content);
  return fileEditorOk({
    'message': position == 'after' ? '已在第 $line 行之后插入内容' : '已在第 $line 行插入内容',
    'path': path,
    'insertedAt': target,
    'position': position,
    'linesInserted': linesInserted,
  });
}

/// `apply_diff` — apply a SEARCH/REPLACE (or unified) diff with optimistic
/// locking. When [start_line]/[end_line] + [expected_range_hash] are supplied
/// (from a prior read_file range), the backend re-hashes that range to detect
/// concurrent edits before applying.
Future<McpToolResult> applyDiff(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final diff = requireString(args, 'diff');
  final strategy = optionalString(args, 'strategy')?.toLowerCase();
  final format = switch (strategy) {
    'unified' => WorkspaceDiffFormat.unified,
    _ => WorkspaceDiffFormat.searchReplace,
  };
  final backend = await backendForPath(ref, path);
  final result = await backend.applyDiff(
    path,
    diff,
    format: format,
    createBackup: optionalBool(args, 'create_backup'),
    expectedRangeHash: optionalString(args, 'expected_range_hash'),
    rangeStartLine: optionalInt(args, 'start_line'),
    rangeEndLine: optionalInt(args, 'end_line'),
  );
  if (!result.success) {
    throw const FileEditorError(
      'Diff 应用失败：未能在文件中定位到 SEARCH 内容（或范围哈希校验冲突）。'
      '请用 read_file 读取最新内容后重试。',
    );
  }
  return fileEditorOk({
    'message': 'Diff 应用成功',
    'path': path,
    'strategy': format == WorkspaceDiffFormat.unified ? 'unified' : 'search-replace',
    'diffStats': {
      'added': result.linesAdded,
      'removed': result.linesDeleted,
      'changed': result.linesChanged,
    },
    if (result.backupPath != null) 'backupPath': result.backupPath,
  });
}

/// `replace_in_file` — search-and-replace literal or regex text.
Future<McpToolResult> replaceInFile(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final search = requireString(args, 'search');
  final raw = args['replace'];
  if (raw == null) throw const FileEditorError('缺少必需参数: replace');
  final replace = raw is String ? raw : raw.toString();

  final backend = await backendForPath(ref, path);
  final count = await backend.replaceInFile(
    path,
    search,
    replace,
    isRegex: optionalBool(args, 'is_regex'),
    replaceAll: optionalBool(args, 'replace_all', fallback: true),
    caseSensitive: optionalBool(args, 'case_sensitive', fallback: true),
  );
  return fileEditorOk({
    'message': '替换完成（$count 处）',
    'path': path,
    'replacements': count,
  });
}

// --- text processing (mirrors original AetherLink text-processing.ts) -------

String _unescapeHtmlEntities(String text) {
  if (text.isEmpty) return text;
  return text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&#91;', '[')
      .replaceAll('&#93;', ']')
      .replaceAll('&lsqb;', '[')
      .replaceAll('&rsqb;', ']')
      .replaceAll('&amp;', '&');
}

String _removeCodeBlockMarkers(String content) {
  var result = content;
  if (result.startsWith('```')) {
    final lines = result.split('\n');
    result = lines.sublist(1).join('\n');
  }
  if (result.endsWith('```')) {
    final lines = result.split('\n');
    result = lines.sublist(0, lines.length - 1).join('\n');
  }
  return result;
}

final List<RegExp> _omissionPatterns = [
  RegExp(r'//\s*rest\s+of\s+code', caseSensitive: false),
  RegExp(r'//\s*\.{3}'),
  RegExp(r'/\*\s*previous\s+code', caseSensitive: false),
  RegExp(r'/\*\s*rest\s+of', caseSensitive: false),
  RegExp(r'//\s*unchanged', caseSensitive: false),
  RegExp(r'//\s*same\s+as\s+before', caseSensitive: false),
  RegExp(r'//\s*\.{3}\s*remaining', caseSensitive: false),
  RegExp(r'#\s*rest\s+of\s+code', caseSensitive: false),
  RegExp(r'#\s*\.{3}'),
];

bool _detectCodeOmission(String content) =>
    _omissionPatterns.any((p) => p.hasMatch(content));
