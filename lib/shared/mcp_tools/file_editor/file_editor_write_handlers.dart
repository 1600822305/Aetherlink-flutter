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
import 'package:aetherlink_flutter/features/workspace/domain/workspace_text_ops.dart'
    as text_ops;
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
  final processed = processIncomingContent(raw is String ? raw : raw.toString());

  // Truncation guard — catch a silently shortened body. Fires when the content
  // is well under the model's own declared `line_count`, OR when it carries a
  // "// rest of code unchanged"-style omission marker (which is suspicious at
  // any length). Either way the model is told to send full content or use
  // apply_diff instead of overwriting with a partial file.
  final expected = optionalInt(args, 'line_count');
  final actual = countLines(processed);
  final wayShort = expected != null && expected > 0 && actual < expected * 0.8;
  // A strong "rest of code unchanged" marker blocks on its own; a bare `// ...`
  // ellipsis only when the content is also far shorter than declared.
  final omitted = detectStrongCodeOmission(processed) ||
      (wayShort && detectCodeOmission(processed));
  if (wayShort || omitted) {
    final hint = expected != null && expected > 0
        ? '（实际 $actual 行，预期 $expected 行）'
        : '（实际 $actual 行）';
    throw FileEditorError(
      '内容可能被截断$hint：${omitted ? '检测到代码省略标记（如 "// rest of code unchanged"）；' : ''}'
      '请提供完整文件内容，或改用 apply_diff / insert_content 做增量修改。',
    );
  }

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
    'totalLines': countLines(processed),
  });
}

/// `create_file` — create a new file under an opaque [parent_path] directory.
Future<McpToolResult> createFile(Ref ref, Map<String, Object?> args) async {
  final parentPath = requireString(args, 'parent_path');
  final name = requireString(args, 'name');
  final content = processIncomingContent(optionalString(args, 'content') ?? '');
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
      'totalLines': countLines(content),
    });
  }

  final created = await backend.createFile(parentPath, name, content: content);
  return fileEditorOk({
    'message': '文件创建成功',
    'path': created,
    'overwritten': false,
    'totalLines': countLines(content),
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
/// The destination is checked for a collision against the *final* name (the
/// [new_name] when given, otherwise the source's own name); when one exists the
/// move is refused unless `overwrite=true`. With a rename the move is done as
/// copy-as-new-name then delete-source (not atomic — a failed delete keeps the
/// copy and reports both locations); a plain move uses the backend's move.
Future<McpToolResult> moveFile(Ref ref, Map<String, Object?> args) async {
  final sourcePath = requireString(args, 'source_path');
  final destParent = requireString(args, 'destination_path');
  final newName = optionalString(args, 'new_name');
  final overwrite = optionalBool(args, 'overwrite');
  final backend = await backendForPath(ref, sourcePath);

  if (newName == null) {
    // Resolve the source name so the collision check (and overwrite) targets
    // the actual landing name, mirroring the rename branch below.
    final source = await backend.getFileInfo(sourcePath);
    final clash = await findChildByName(backend, destParent, source.name);
    if (clash != null) {
      if (!overwrite) {
        throw FileEditorError(
          '目标目录已存在「${source.name}」；如需覆盖请传 overwrite=true。',
        );
      }
      await backend.delete(
        clash.path,
        isDirectory: clash.isDirectory,
        recursive: clash.isDirectory,
      );
    }
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
///
/// `recursive` defaults to false: deleting a *non-empty* directory needs an
/// explicit `recursive=true` so a single mistaken call can't wipe a whole tree.
/// Files and already-empty directories delete without it.
Future<McpToolResult> deleteFile(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final recursive = optionalBool(args, 'recursive');
  final backend = await backendForPath(ref, path);

  bool isDirectory = false;
  try {
    isDirectory = (await backend.getFileInfo(path)).isDirectory;
  } catch (_) {
    // Fall back to file deletion if metadata is unavailable.
  }

  if (isDirectory && !recursive) {
    final children = await backend.listDir(path);
    if (children.isNotEmpty) {
      throw FileEditorError(
        '目录非空（含 ${children.length} 项）。如确认删除整个目录及其全部内容，请传 recursive=true。',
      );
    }
  }

  await backend.delete(path, isDirectory: isDirectory, recursive: recursive);
  return fileEditorOk({
    'message': '删除成功',
    'path': path,
    'type': isDirectory ? 'directory' : 'file',
  });
}

/// `insert_content` — insert [content] relative to a 1-based [line].
///
/// `position` selects `before` (default) or `after` the line; `at_end=true`
/// appends to the file and needs no [line] at all.
Future<McpToolResult> insertContent(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final raw = args['content'];
  if (raw == null) throw const FileEditorError('缺少必需参数: content');
  final content = processIncomingContent(raw is String ? raw : raw.toString());
  final backend = await backendForPath(ref, path);
  final linesInserted = countLines(content);

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
  final expectedRangeHash = optionalString(args, 'expected_range_hash');
  final backend = await backendForPath(ref, path);
  final result = await backend.applyDiff(
    path,
    diff,
    format: format,
    createBackup: optionalBool(args, 'create_backup'),
    expectedRangeHash: expectedRangeHash,
    rangeStartLine: optionalInt(args, 'start_line'),
    rangeEndLine: optionalInt(args, 'end_line'),
  );
  if (!result.success) {
    // With a range hash the failure is most likely a concurrent-edit conflict;
    // without one it's a SEARCH block that no longer matches the file. Tailor
    // the guidance so the model knows exactly how to recover.
    throw FileEditorError(
      expectedRangeHash != null
          ? 'Diff 应用失败：范围哈希校验冲突（该范围已被改动）或 SEARCH 内容不匹配。'
            '请用 read_file 重新读取相同行范围，拿到最新 rangeHash 后再带上重试。'
          : 'Diff 应用失败：未能在文件中定位到 SEARCH 内容。请用 read_file 读取最新内容，'
            '确认 SEARCH 块与文件完全一致（含缩进/空白）后重试；大范围改动可携带 '
            'start_line/end_line + expected_range_hash 启用乐观锁。',
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

/// `replace_in_file` — search-and-replace literal or regex text, one pair
/// (`search`/`replace`) or a batch (`edits` array). The whole call is atomic:
/// every edit is applied in memory in order and the file is written once —
/// any failure leaves the file untouched.
///
/// Safety semantics (mirrors a uniqueness-guarded editor):
/// - `replace_all` defaults to **false**; a single-replacement edit whose
///   search hits more than once is rejected, so the model can't silently
///   change the wrong occurrence — it must add context or opt into
///   `replace_all=true`.
/// - a search with zero hits is an error (not a silent no-op).
Future<McpToolResult> replaceInFile(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final isRegex = optionalBool(args, 'is_regex');
  final replaceAll = optionalBool(args, 'replace_all');
  final caseSensitive = optionalBool(args, 'case_sensitive', fallback: true);

  final edits = <({String search, String replace})>[];
  final rawEdits = args['edits'];
  if (rawEdits is List && rawEdits.isNotEmpty) {
    for (final item in rawEdits) {
      if (item is! Map) {
        throw const FileEditorError('edits 数组的元素必须是 {search, replace} 对象');
      }
      final m = item.map((k, v) => MapEntry(k.toString(), v as Object?));
      final search = optionalString(m, 'search');
      final rawReplace = m['replace'];
      if (search == null || search.isEmpty) {
        throw const FileEditorError('edits 元素缺少必需参数: search');
      }
      if (rawReplace == null) {
        throw const FileEditorError('edits 元素缺少必需参数: replace');
      }
      edits.add((
        search: search,
        replace: rawReplace is String ? rawReplace : rawReplace.toString(),
      ));
    }
  } else {
    final search = requireString(args, 'search');
    final raw = args['replace'];
    if (raw == null) throw const FileEditorError('缺少必需参数: replace');
    edits.add((search: search, replace: raw is String ? raw : raw.toString()));
  }

  final backend = await backendForPath(ref, path);
  var content = await backend.readFile(path);
  final original = content;
  var total = 0;

  for (var i = 0; i < edits.length; i++) {
    final edit = edits[i];
    final label = edits.length > 1 ? '第 ${i + 1} 个 edit 的 ' : '';
    final counted = text_ops.replaceInFile(
      content,
      edit.search,
      edit.replace,
      isRegex: isRegex,
      replaceAll: true,
      caseSensitive: caseSensitive,
    );
    if (counted.replacements == 0) {
      throw FileEditorError(
        '${label}search 内容未在文件中命中，未做任何修改。'
        '请用 read_file 确认最新内容（含缩进/空白）后重试。',
      );
    }
    if (!replaceAll && counted.replacements > 1) {
      throw FileEditorError(
        '${label}search 内容命中 ${counted.replacements} 处，无法确定要替换哪一处，未做任何修改。'
        '请在 search 里加入更多上下文使其唯一，或明确传 replace_all=true 全部替换。',
      );
    }
    final applied = replaceAll
        ? counted
        : text_ops.replaceInFile(
            content,
            edit.search,
            edit.replace,
            isRegex: isRegex,
            replaceAll: false,
            caseSensitive: caseSensitive,
          );
    content = applied.newContent;
    total += applied.replacements;
  }

  if (content != original) await backend.writeFile(path, content);
  return fileEditorOk({
    'message': '替换完成（$total 处${edits.length > 1 ? '，${edits.length} 个 edit' : ''}）',
    'path': path,
    'replacements': total,
    if (edits.length > 1) 'edits': edits.length,
  });
}

/// `create_directory` — create a directory under an opaque [parent_path],
/// mirroring `create_file`'s addressing (SAF paths are opaque URIs, so new
/// entries are always parent + name).
Future<McpToolResult> createDirectory(Ref ref, Map<String, Object?> args) async {
  final parentPath = requireString(args, 'parent_path');
  final name = requireString(args, 'name');
  final backend = await backendForPath(ref, parentPath);
  final existing = await findChildByName(backend, parentPath, name);
  if (existing != null) {
    if (existing.isDirectory) {
      return fileEditorOk({
        'message': '目录已存在',
        'path': existing.path,
        'created': false,
      });
    }
    throw FileEditorError('「$name」已存在且是一个文件，无法创建同名目录。');
  }
  final created = await backend.createDirectory(parentPath, name);
  return fileEditorOk({'message': '目录创建成功', 'path': created, 'created': true});
}
