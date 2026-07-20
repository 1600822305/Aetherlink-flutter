// Write/edit handlers for the `@aether/file-editor` built-in MCP server.
//
// Each handler maps a write tool call to the workspace `WorkspaceBackend`
// (SAF on Android): write / edit / move / copy_file / delete_file /
// create_directory.
//
// SAF caveat: a workspace entry's `path` is an **opaque** `content://` URI —
// never split or build it by string. New files are addressed by an opaque
// parent directory + a name, and moves/copies target an opaque parent dir.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_file_history.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/features/workspace/domain/workspace_text_ops.dart'
    as text_ops;
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_read_state.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// `write` — overwrite an existing file (`path`) or create a new one
/// (`parent_path` + `name`). On SAF a brand-new file can't be addressed by an
/// arbitrary path, so creation always goes through an opaque parent dir.
Future<McpToolResult> writeFile(
  Ref ref,
  Map<String, Object?> args, {
  String sessionKey = '',
}) async {
  final rawPath = optionalString(args, 'path');
  if (rawPath == null) return _createFile(ref, args, sessionKey: sessionKey);
  final raw = args['content'];
  if (raw == null) throw const FileEditorError('缺少必需参数: content');
  final processed = processIncomingContent(raw is String ? raw : raw.toString());

  // Truncation guard — catch a silently shortened body. Fires when the content
  // is well under the model's own declared `line_count`, OR when it carries a
  // "// rest of code unchanged"-style omission marker (which is suspicious at
  // any length). Either way the model is told to send full content or use
  // `edit` instead of overwriting with a partial file.
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
      '请提供完整文件内容，或改用 edit 做增量修改。'
      '${!omitted && wayShort ? '如确认内容完整、只是 line_count 估计有误，可去掉 line_count 重试。' : ''}',
    );
  }

  final resolved = await resolvePathArg(ref, args, rawPath);
  final backend = resolved.backend;
  final path = resolved.path;

  WorkspaceEntry info;
  try {
    info = await backend.getFileInfo(path);
  } catch (_) {
    throw const FileEditorError(
      '目标文件不存在或无法访问。新建文件请改传 parent_path + name。',
    );
  }
  if (info.isDirectory) {
    throw const FileEditorError('目标是目录，无法作为文件写入。');
  }
  _ensureNotStale(ref, sessionKey, path, currentMtime: info.mtime);

  await _snapshotBeforeOverwrite(ref, backend, path);
  await backend.writeFile(path, processed);
  await _refreshReadState(ref, backend, sessionKey, path);
  return fileEditorOk({
    'message': '文件更新成功',
    'path': path,
    'totalLines': countLines(processed),
  });
}

/// `write` (creation branch) — new file under an opaque [parent_path] dir.
Future<McpToolResult> _createFile(
  Ref ref,
  Map<String, Object?> args, {
  String sessionKey = '',
}) async {
  final rawParent = requireString(args, 'parent_path');
  final name = requireString(args, 'name');
  final content = processIncomingContent(optionalString(args, 'content') ?? '');
  final overwrite = optionalBool(args, 'overwrite');

  final resolved = await resolvePathArg(ref, args, rawParent);
  final backend = resolved.backend;
  final parentPath = resolved.path;
  final existing = await findChildByName(backend, parentPath, name);
  if (existing != null) {
    if (!overwrite) {
      throw FileEditorError('「$name」已存在；如需覆盖请传 overwrite=true。');
    }
    if (existing.isDirectory) {
      throw FileEditorError('「$name」是一个目录，无法以文件覆盖。');
    }
    _ensureNotStale(ref, sessionKey, existing.path, currentMtime: existing.mtime);
    await _snapshotBeforeOverwrite(ref, backend, existing.path);
    await backend.writeFile(existing.path, content);
    await _refreshReadState(ref, backend, sessionKey, existing.path);
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

/// `move` — rename in place (only [new_name]) or move a file/dir into the
/// opaque [destination_path] directory, optionally renaming in the same call.
///
/// The destination is checked for a collision against the *final* name (the
/// [new_name] when given, otherwise the source's own name); when one exists the
/// move is refused unless `overwrite=true`. With a rename the move is done as
/// copy-as-new-name then delete-source (not atomic — a failed delete keeps the
/// copy and reports both locations); a plain move uses the backend's move.
Future<McpToolResult> moveEntry(Ref ref, Map<String, Object?> args) async {
  final rawSource = optionalString(args, 'path') ??
      requireString(args, 'source_path'); // 兼容旧参数名
  final rawDestParent = optionalString(args, 'destination_path');
  final newName = optionalString(args, 'new_name');
  final overwrite = optionalBool(args, 'overwrite');
  final resolvedSource = await resolvePathArg(ref, args, rawSource);
  final backend = resolvedSource.backend;
  final sourcePath = resolvedSource.path;
  final destParent = rawDestParent == null
      ? null
      : (await resolvePathArg(ref, args, rawDestParent)).path;

  if (destParent == null) {
    if (newName == null) {
      throw const FileEditorError(
        '缺少参数：destination_path（移动）与 new_name（改名）至少传一个。',
      );
    }
    final newPath = await backend.rename(sourcePath, newName);
    return fileEditorOk({'message': '重命名成功', 'path': newPath, 'newName': newName});
  }

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
  final rawSource = requireString(args, 'source_path');
  final rawDestParent = requireString(args, 'destination_path');
  final newName = optionalString(args, 'new_name');
  final overwrite = optionalBool(args, 'overwrite');
  final resolvedSource = await resolvePathArg(ref, args, rawSource);
  final backend = resolvedSource.backend;
  final sourcePath = resolvedSource.path;
  final destParent = (await resolvePathArg(ref, args, rawDestParent)).path;
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
  final rawPath = requireString(args, 'path');
  final recursive = optionalBool(args, 'recursive');
  final resolved = await resolvePathArg(ref, args, rawPath);
  final backend = resolved.backend;
  final path = resolved.path;

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

/// `edit` — search-and-replace literal or regex text, one pair
/// (`search`/`replace`) or a batch (`edits` array). The whole call is atomic:
/// every edit is applied in memory in order and the file is written once —
/// any failure leaves the file untouched.
///
/// Safety semantics (mirrors a uniqueness-guarded editor):
/// - `replace_all` defaults to **false**; a single-replacement edit whose
///   search hits more than once is rejected, so the model can't silently
///   change the wrong occurrence — it must add context or opt into
///   `replace_all=true`. Each `edits` element may carry its own
///   `replace_all`, falling back to the top-level flag.
/// - a search with zero hits is an error (not a silent no-op).
/// - a literal edit whose `replace` equals `search` is rejected up front —
///   it would report "替换完成" while changing nothing.
Future<McpToolResult> editFile(
  Ref ref,
  Map<String, Object?> args, {
  String sessionKey = '',
}) async {
  final path = requireString(args, 'path');
  final isRegex = optionalBool(args, 'is_regex');
  final globalReplaceAll = optionalBool(args, 'replace_all');
  final caseSensitive = optionalBool(args, 'case_sensitive', fallback: true);

  final edits = <({String search, String replace, bool replaceAll})>[];
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
        replaceAll: m.containsKey('replace_all')
            ? optionalBool(m, 'replace_all')
            : globalReplaceAll,
      ));
    }
  } else {
    final search = requireString(args, 'search');
    final raw = args['replace'];
    if (raw == null) throw const FileEditorError('缺少必需参数: replace');
    edits.add((
      search: search,
      replace: raw is String ? raw : raw.toString(),
      replaceAll: globalReplaceAll,
    ));
  }

  for (var i = 0; i < edits.length; i++) {
    if (!isRegex && edits[i].search == edits[i].replace) {
      final label = edits.length > 1 ? '第 ${i + 1} 个 edit 的 ' : '';
      throw FileEditorError(
        '${label}replace 与 search 完全相同，替换不会改变文件，未做任何修改。'
        '请提供与原文不同的 replace 内容。',
      );
    }
  }

  final resolved = await resolvePathArg(ref, args, path);
  final backend = resolved.backend;
  final resolvedPath = resolved.path;
  await _ensureNotStaleByStat(ref, backend, sessionKey, resolvedPath);
  var content = await backend.readFile(resolvedPath);
  final original = content;
  var total = 0;

  for (var i = 0; i < edits.length; i++) {
    final edit = edits[i];
    final label = edits.length > 1 ? '第 ${i + 1} 个 edit 的 ' : '';
    // 单次全量扫描同时完成计数与替换：命中 1 处时全量替换结果与单处
    // 替换结果相同；命中多处且未开 replace_all 时直接报错，无需重跑。
    final counted = text_ops.replaceInFile(
      content,
      edit.search,
      edit.replace,
      isRegex: isRegex,
      replaceAll: true,
      caseSensitive: caseSensitive,
    );
    if (counted.replacements == 0) {
      final hint =
          isRegex ? null : text_ops.searchMissHint(content, edit.search);
      throw FileEditorError(
        '${label}search 内容命中 0 处，未做任何修改。'
        '${hint ?? '请用 read_file 确认最新内容（含缩进/空白，不含行号前缀）后重试。'}',
      );
    }
    if (!edit.replaceAll && counted.replacements > 1) {
      throw FileEditorError(
        '${label}search 内容命中 ${counted.replacements} 处，无法确定要替换哪一处，未做任何修改。'
        '请在 search 里加入更多上下文使其唯一，或明确传 replace_all=true 全部替换。',
      );
    }
    content = counted.newContent;
    total += counted.replacements;
  }

  if (content != original) {
    await recordFileHistory(
      ref.read(workspaceFileHistoryProvider.future),
      resolvedPath,
      original,
      source: '智能体编辑',
    );
    await backend.writeFile(resolvedPath, content);
    await _refreshReadState(ref, backend, sessionKey, resolvedPath);
  }
  return fileEditorOk({
    'message': '替换完成（$total 处${edits.length > 1 ? '，${edits.length} 个 edit' : ''}）',
    'path': resolvedPath,
    'replacements': total,
    if (edits.length > 1) 'edits': edits.length,
  });
}

/// 陈旧检测（Claude Code 的 readFileState 机制）：本会话读过的文件若在读取后
/// 被外部修改（mtime 变化），拒绝基于过期内容的改动；未读过的文件不拦。
void _ensureNotStale(
  Ref ref,
  String sessionKey,
  String path, {
  required int currentMtime,
}) {
  final record = ref.read(fileReadStateProvider).lookup(sessionKey, path);
  if (isStaleForEdit(record, mtime: currentMtime)) {
    throw const FileEditorError(
      '文件在上次读取后已被外部修改（mtime 变化），为避免基于过期内容修改，'
      '本次未做任何改动。请先用 read_file 重新读取最新内容后重试。',
    );
  }
}

/// [_ensureNotStale] 的 stat 变体：自行取 mtime（best-effort，后端不支持
/// getFileInfo 时跳过检测）。
Future<void> _ensureNotStaleByStat(
  Ref ref,
  WorkspaceBackend backend,
  String sessionKey,
  String path,
) async {
  final WorkspaceEntry info;
  try {
    info = await backend.getFileInfo(path);
  } catch (_) {
    return;
  }
  _ensureNotStale(ref, sessionKey, path, currentMtime: info.mtime);
}

/// 本会话自己写入后刷新读取记录：新 mtime 让陈旧检测不误拦后续编辑，
/// 同时使旧内容退出读取去重（重读会返回真实新内容）。Best-effort。
Future<void> _refreshReadState(
  Ref ref,
  WorkspaceBackend backend,
  String sessionKey,
  String path,
) async {
  try {
    final info = await backend.getFileInfo(path);
    ref
        .read(fileReadStateProvider)
        .refreshAfterWrite(sessionKey, path, mtime: info.mtime, size: info.size);
  } catch (_) {
    // 后端不支持 getFileInfo 时保持旧记录；下次编辑前的 stat 也会失败，
    // 陈旧检测同样跳过，不会误拦。
  }
}

/// Saves [path]'s current content to the workspace file history before an
/// overwrite. Best-effort: unreadable (binary/oversized) files are skipped.
Future<void> _snapshotBeforeOverwrite(
  Ref ref,
  WorkspaceBackend backend,
  String path,
) async {
  String old;
  try {
    old = await backend.readFile(path);
  } catch (_) {
    return;
  }
  await recordFileHistory(
    ref.read(workspaceFileHistoryProvider.future),
    path,
    old,
    source: '智能体写入',
  );
}

/// `create_directory` — create a directory under an opaque [parent_path]
/// (SAF paths are opaque URIs, so new entries are always parent + name).
Future<McpToolResult> createDirectory(Ref ref, Map<String, Object?> args) async {
  final rawParent = requireString(args, 'parent_path');
  final name = requireString(args, 'name');
  final resolved = await resolvePathArg(ref, args, rawParent);
  final backend = resolved.backend;
  final parentPath = resolved.path;
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
