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

/// Where a `write` by `path` will land: an existing file to overwrite
/// ([existing] non-null), or a creation target — the deepest existing
/// directory [parentPath], the [missingDirs] to create under it (in order),
/// and the [fileName].
class WriteTarget {
  const WriteTarget({
    required this.backend,
    this.existing,
    this.parentPath,
    this.missingDirs = const [],
    this.fileName,
  });

  final WorkspaceBackend backend;
  final WorkspaceEntry? existing;
  final String? parentPath;
  final List<String> missingDirs;
  final String? fileName;
}

/// Locates the write target for posix [absPath]: the existing file, or the
/// creation spec with any missing ancestor directories collected (mkdir -p
/// semantics). An intermediate segment that exists as a *file* is an error.
Future<WriteTarget> locatePosixWriteTarget(
  WorkspaceBackend backend,
  String absPath,
) async {
  WorkspaceEntry? info;
  try {
    info = await backend.getFileInfo(absPath);
  } catch (_) {
    info = null;
  }
  if (info != null) {
    if (info.isDirectory) {
      throw const FileEditorError('目标是目录，无法作为文件写入。');
    }
    return WriteTarget(backend: backend, existing: info);
  }
  final name = posixBasename(absPath);
  if (name.isEmpty || name == '..' || name == '.') {
    throw FileEditorError('无效的文件路径: $absPath');
  }
  var dir = posixDirname(absPath);
  final missing = <String>[];
  while (dir.isNotEmpty && dir != '/') {
    WorkspaceEntry? e;
    try {
      e = await backend.getFileInfo(dir);
    } catch (_) {
      e = null;
    }
    if (e != null) {
      if (!e.isDirectory) {
        throw FileEditorError('路径中的「${e.name}」是文件，无法在其下创建文件。');
      }
      break;
    }
    missing.insert(0, posixBasename(dir));
    dir = posixDirname(dir);
  }
  return WriteTarget(
    backend: backend,
    parentPath: dir.isEmpty ? '/' : dir,
    missingDirs: missing,
    fileName: name,
  );
}

/// [locatePosixWriteTarget] 的不透明根（SAF `content://`）变体：从 [rootPath]
/// 逐级 listDir 导航 [subPath]，缺失的中间目录收集进 missingDirs 而不报错。
Future<WriteTarget> locateOpaqueWriteTarget(
  WorkspaceBackend backend,
  String rootPath,
  String subPath,
) async {
  final segments = subPath
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && s != '.')
      .toList();
  if (segments.isEmpty || segments.contains('..')) {
    throw FileEditorError('无效的文件路径: $subPath');
  }
  var current = rootPath;
  for (var i = 0; i < segments.length; i++) {
    final match = await findChildByName(backend, current, segments[i]);
    final isLast = i == segments.length - 1;
    if (match == null) {
      return WriteTarget(
        backend: backend,
        parentPath: current,
        missingDirs: segments.sublist(i, segments.length - 1),
        fileName: segments.last,
      );
    }
    if (isLast) {
      if (match.isDirectory) {
        throw const FileEditorError('目标是目录，无法作为文件写入。');
      }
      return WriteTarget(backend: backend, existing: match);
    }
    if (!match.isDirectory) {
      throw FileEditorError('路径中的「${segments[i]}」是文件，无法在其下创建文件。');
    }
    current = match.path;
  }
  throw StateError('unreachable');
}

/// Creates [target]'s missing directories then the file itself with
/// [content], returning the new file's (opaque) path.
Future<String> materializeWriteTarget(WriteTarget target, String content) async {
  var parent = target.parentPath!;
  for (final dir in target.missingDirs) {
    parent = await target.backend.createDirectory(parent, dir);
  }
  return target.backend.createFile(parent, target.fileName!, content: content);
}

/// Resolves a `write` [path] argument to a [WriteTarget] — the counterpart of
/// [resolvePathArg] that tolerates a not-yet-existing target (create-or-
/// overwrite semantics). Opaque `content://` handles must already exist (a
/// brand-new SAF file can't be addressed by an arbitrary URI).
Future<WriteTarget> resolveWriteTarget(
  Ref ref,
  Map<String, Object?> args,
  String path,
) async {
  if (isTildePath(path)) {
    final expanded = await resolveTildePath(ref, args, path);
    return locatePosixWriteTarget(expanded.backend, expanded.path);
  }
  if (isAbsoluteOrOpaque(path)) {
    final backend = await backendForPath(ref, path);
    if (path.contains('://')) {
      WorkspaceEntry? info;
      try {
        info = await backend.getFileInfo(path);
      } catch (_) {
        info = null;
      }
      if (info == null) {
        throw const FileEditorError(
          '目标不存在：不透明句柄路径无法用于新建文件。'
          '请改用相对路径，或传 parent_path + name。',
        );
      }
      if (info.isDirectory) {
        throw const FileEditorError('目标是目录，无法作为文件写入。');
      }
      return WriteTarget(backend: backend, existing: info);
    }
    return locatePosixWriteTarget(backend, path);
  }
  final ResolvedWorkspace resolved;
  if (optionalString(args, 'workspace') != null) {
    resolved = await resolveWorkspace(ref, args);
  } else {
    final workspaces = await loadWorkspaces(ref);
    if (workspaces.isEmpty) {
      throw const FileEditorError(
        '当前没有任何工作区，请先在工作区页面「打开文件夹」后再试。',
      );
    }
    resolved = ResolvedWorkspace(
      workspaces.first,
      await resolveWorkspaceById(ref, workspaces.first.id),
    );
  }
  final root = resolved.workspace.root;
  if (!root.contains('://')) {
    return locatePosixWriteTarget(
      resolved.backend,
      joinPosixPath(root, path),
    );
  }
  return locateOpaqueWriteTarget(resolved.backend, root, path);
}

/// `write` — create-or-overwrite by `path`（不存在则自动创建，含缺失父目录）,
/// or create by `parent_path` + `name`（兼容旧用法；SAF 不透明句柄只能走这条）.
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

  final target = await resolveWriteTarget(ref, args, rawPath);
  final backend = target.backend;

  if (target.existing == null) {
    final created = await materializeWriteTarget(target, processed);
    await _refreshReadState(ref, backend, sessionKey, created,
        writtenContent: processed);
    return fileEditorOk({
      'message': '文件创建成功',
      'path': created,
      'totalLines': countLines(processed),
      if (target.missingDirs.isNotEmpty)
        'createdDirs': target.missingDirs.join('/'),
    });
  }

  final path = target.existing!.path;
  await _ensureReadAndFresh(
    ref,
    backend,
    sessionKey,
    path,
    currentMtime: target.existing!.mtime,
    requireFullRead: true,
  );

  final old = await _snapshotBeforeOverwrite(ref, backend, path);
  await backend.writeFile(path, processed);
  await _refreshReadState(ref, backend, sessionKey, path,
      writtenContent: processed);
  return fileEditorOk({
    'message': '文件更新成功',
    'path': path,
    'totalLines': countLines(processed),
    if (old != null) ...?diffSummaryJson(old, processed),
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
    await _ensureReadAndFresh(
      ref,
      backend,
      sessionKey,
      existing.path,
      currentMtime: existing.mtime,
      requireFullRead: true,
    );
    await _snapshotBeforeOverwrite(ref, backend, existing.path);
    await backend.writeFile(existing.path, content);
    await _refreshReadState(ref, backend, sessionKey, existing.path,
        writtenContent: content);
    return fileEditorOk({
      'message': '文件已覆盖',
      'path': existing.path,
      'overwritten': true,
      'totalLines': countLines(content),
    });
  }

  final created = await backend.createFile(parentPath, name, content: content);
  // 新建文件记入读取状态：本会话自己写的内容算「已知」，后续 edit/write
  // 不会被写前必读拦下要求冗余重读。
  await _refreshReadState(ref, backend, sessionKey, created,
      writtenContent: content);
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
  await _ensureReadAndFreshByStat(ref, backend, sessionKey, resolvedPath);
  var content = await backend.readFile(resolvedPath);
  final original = content;
  var total = 0;
  var recovered = 0;

  for (var i = 0; i < edits.length; i++) {
    final edit = edits[i];
    final label = edits.length > 1 ? '第 ${i + 1} 个 edit 的 ' : '';
    // 单次全量扫描同时完成计数与替换：命中 1 处时全量替换结果与单处
    // 替换结果相同；命中多处且未开 replace_all 时直接报错，无需重跑。
    var search = edit.search;
    var counted = text_ops.replaceInFile(
      content,
      search,
      edit.replace,
      isRegex: isRegex,
      replaceAll: true,
      caseSensitive: caseSensitive,
    );
    if (counted.replacements == 0 && !isRegex) {
      // 模糊匹配恢复：弯引号/行尾空白导致的精确失配，改用文件里的
      // 实际文本重试（对标 Claude Code 的 findActualString）。
      final actual = text_ops.findFlexibleSearch(content, search);
      if (actual != null && actual != edit.replace) {
        search = actual;
        counted = text_ops.replaceInFile(
          content,
          search,
          edit.replace,
          isRegex: false,
          replaceAll: true,
          caseSensitive: caseSensitive,
        );
        if (counted.replacements > 0) recovered++;
      }
    }
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
    await _refreshReadState(ref, backend, sessionKey, resolvedPath,
        writtenContent: content);
  }
  return fileEditorOk({
    'message': '替换完成（$total 处${edits.length > 1 ? '，${edits.length} 个 edit' : ''}）'
        '${recovered > 0 ? '；其中 $recovered 处通过弯引号/行尾空白模糊匹配恢复，'
            '已按文件实际文本替换' : ''}',
    'path': resolvedPath,
    'replacements': total,
    if (edits.length > 1) 'edits': edits.length,
    ...?diffSummaryJson(original, content),
  });
}

/// 写前守卫（Claude Code 的 readFileState 机制），两道检查：
///
/// 1. **写前必读**：已存在的文件本会话没读过（也没写过）直接拒绝，
///    防止盲写覆盖模型从没看过的文件。[requireFullRead] 时（write 整文件
///    覆盖）还要求读的是全文而非行范围——只看过片段就整文件覆盖同样危险；
///    edit 不要求全文（大文件只能范围读，search 匹配本身已是一道校验）。
/// 2. **陈旧检测**：读取后被外部修改（mtime 变化）拒绝改动；mtime 变了时
///    先读当前内容比对 hash 兜底，内容未变（云同步/杀软只碰 mtime）不误拦。
///
/// mtime 为 0（后端不提供）时陈旧检测跳过，但写前必读仍生效。
Future<void> _ensureReadAndFresh(
  Ref ref,
  WorkspaceBackend backend,
  String sessionKey,
  String path, {
  required int currentMtime,
  bool requireFullRead = false,
}) async {
  final record = ref.read(fileReadStateProvider).lookup(sessionKey, path);
  if (record == null) {
    throw const FileEditorError(
      '文件已存在但本会话尚未读取过它，为避免盲写覆盖，本次未做任何改动。'
      '请先用 read_file 读取它的内容后再修改。',
    );
  }
  if (requireFullRead && record.isPartialView) {
    throw const FileEditorError(
      '本会话只读过这个文件的部分行范围，整文件覆盖写入会丢失未读到的内容，'
      '本次未做任何改动。请先用 read_file 读取全文，或改用 edit 做局部修改。',
    );
  }
  if (!isStaleForEdit(record, mtime: currentMtime)) return;
  // mtime 变了：读当前内容比对 hash 兜底（best-effort，读失败则按陈旧处理）。
  String? currentHash;
  try {
    currentHash = text_ops.fileHash(await backend.readFile(path));
  } catch (_) {
    currentHash = null;
  }
  if (!isStaleForEdit(record, mtime: currentMtime,
      currentContentHash: currentHash)) {
    return;
  }
  throw const FileEditorError(
    '文件在上次读取后已被外部修改，为避免基于过期内容修改，'
    '本次未做任何改动。请先用 read_file 重新读取最新内容后重试。',
  );
}

/// [_ensureReadAndFresh] 的 stat 变体（edit 用）：自行取 mtime。后端不支持
/// getFileInfo 时陈旧检测降级跳过，但写前必读仍生效。
Future<void> _ensureReadAndFreshByStat(
  Ref ref,
  WorkspaceBackend backend,
  String sessionKey,
  String path,
) async {
  int mtime;
  try {
    mtime = (await backend.getFileInfo(path)).mtime;
  } catch (_) {
    mtime = 0;
  }
  await _ensureReadAndFresh(ref, backend, sessionKey, path,
      currentMtime: mtime);
}

/// 本会话自己写入后刷新读取记录：新 mtime + 内容 hash 让陈旧检测不误拦
/// 后续编辑，同时使旧内容退出读取去重（重读会返回真实新内容）。新建/
/// 未读过的文件也会记入，让写前必读把本会话自己写的文件算作已知。
/// Best-effort。
Future<void> _refreshReadState(
  Ref ref,
  WorkspaceBackend backend,
  String sessionKey,
  String path, {
  String? writtenContent,
}) async {
  try {
    final info = await backend.getFileInfo(path);
    ref.read(fileReadStateProvider).refreshAfterWrite(
          sessionKey,
          path,
          mtime: info.mtime,
          size: info.size,
          contentHash:
              writtenContent == null ? null : text_ops.fileHash(writtenContent),
        );
  } catch (_) {
    // 后端不支持 getFileInfo 时保持旧记录；下次编辑前的 stat 也会失败，
    // 陈旧检测同样跳过，不会误拦。
  }
}

/// Saves [path]'s current content to the workspace file history before an
/// overwrite, returning that content (for the result diff). Best-effort:
/// unreadable (binary/oversized) files are skipped and yield null.
Future<String?> _snapshotBeforeOverwrite(
  Ref ref,
  WorkspaceBackend backend,
  String path,
) async {
  String old;
  try {
    old = await backend.readFile(path);
  } catch (_) {
    return null;
  }
  await recordFileHistory(
    ref.read(workspaceFileHistoryProvider.future),
    path,
    old,
    source: '智能体写入',
  );
  return old;
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
