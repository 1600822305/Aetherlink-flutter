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
import 'package:aetherlink_flutter/shared/utils/line_diff.dart';

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
  throw FileEditorError('找不到工作区: "$raw"。可用编号/ID/名称见系统提示的 [工作区上下文]。');
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

/// 路径是否已是“绝对”定位：POSIX 绝对路径，或带 scheme 的不透明 URI
/// （如 SAF 的 `content://`）。相对路径（`README.md`、`lib/main.dart`）
/// 需要经 [resolvePathArg] 锚定到工作区 root 再交给后端。
bool isAbsoluteOrOpaque(String path) =>
    path.startsWith('/') || path.contains('://');

/// 是否是 `~` / `~/...` 形式的 home 相对路径。
bool isTildePath(String path) => path == '~' || path.startsWith('~/');

/// 把 `~` / `~/...` 按 [home] 展开为绝对 posix 路径。
String expandTildeWithHome(String home, String path) =>
    path == '~' ? home : joinPosixPath(home, path.substring(2));

/// 解析 `~` 路径：取 `workspace` 参数指定（缺省最近打开）工作区后端的
/// home 目录展开。后端无 home 概念（SAF）时报可行动错误。
Future<({WorkspaceBackend backend, String path})> resolveTildePath(
  Ref ref,
  Map<String, Object?> args,
  String path,
) async {
  final resolved = await _workspaceForArgs(ref, args);
  final home = await resolved.backend.homePath();
  if (home == null) {
    throw const FileEditorError(
      '当前工作区后端无法解析 ~（home 目录）。'
      '请改用相对路径（按工作区根解析）或绝对路径。',
    );
  }
  return (backend: resolved.backend, path: expandTildeWithHome(home, path));
}

/// `workspace` 参数指定的工作区，缺省取最近打开的一个。
Future<ResolvedWorkspace> _workspaceForArgs(
  Ref ref,
  Map<String, Object?> args,
) async {
  if (optionalString(args, 'workspace') != null) {
    return resolveWorkspace(ref, args);
  }
  final workspaces = await loadWorkspaces(ref);
  if (workspaces.isEmpty) {
    throw const FileEditorError(
      '当前没有任何工作区，请先在工作区页面「打开文件夹」后再试。',
    );
  }
  return _resolve(ref, workspaces.first);
}

/// 把相对 [subPath] 逐段规整（去 `.`、消 `..`）后拼到 POSIX [root] 下。
/// `..` 超出 root 时保留越界语义（返回 root 之外的祖先路径），
/// 是否放行交给审批层决定，这里不做拒绝。
String joinPosixPath(String root, String subPath) {
  final base = root.endsWith('/') && root.length > 1
      ? root.substring(0, root.length - 1)
      : root;
  final stack = base.split('/');
  for (final seg in subPath.split('/')) {
    final s = seg.trim();
    if (s.isEmpty || s == '.') continue;
    if (s == '..') {
      if (stack.length > 1) stack.removeLast();
      continue;
    }
    stack.add(s);
  }
  final joined = stack.join('/');
  return joined.isEmpty ? '/' : joined;
}

/// 统一路径解析入口（所有 file-editor 工具共用）：
/// - `~` / `~/...`：按工作区后端的 home 目录展开；
/// - 绝对路径 / 不透明 URI：原样使用，按最长前缀匹配选后端；
/// - 相对路径：锚定到 `workspace` 参数指定的工作区（智能体绑定任务会
///   自动注入；缺省时取最近打开的工作区）的 root —— POSIX root 直接
///   拼接，SAF 的 `content://` root 逐级列目录导航（目标必须已存在）。
/// 越界路径不在这里拒绝，放行与否由审批层决定。
Future<({WorkspaceBackend backend, String path})> resolvePathArg(
  Ref ref,
  Map<String, Object?> args,
  String path,
) async {
  if (isTildePath(path)) return resolveTildePath(ref, args, path);
  if (isAbsoluteOrOpaque(path)) {
    return (backend: await backendForPath(ref, path), path: path);
  }
  final resolved = await _workspaceForArgs(ref, args);
  final root = resolved.workspace.root;
  if (!root.contains('://')) {
    return (backend: resolved.backend, path: joinPosixPath(root, path));
  }
  final target = await navigateSubPath(resolved.backend, root, path);
  return (backend: resolved.backend, path: target);
}

/// Whether opaque [path] sits inside (or is) the workspace rooted at [root].
///
/// Uses a boundary-aware prefix test (`root` itself, or `root/…`) so a sibling
/// like `…/Download` can't be mistaken for a child of `…/Down`. Works for SAF
/// `content://` URIs (a child URI is `<root>/document/…`) and posix roots alike.
bool pathUnderRoot(String path, String root) =>
    path == root || path.startsWith('$root/');

/// auto 模式免审判定：file-editor 写调用携带的所有路径参数是否都落在
/// 工作区 [root] 内。未携带任何路径参数时按越界处理（保守兜底）。
bool fileEditorPathsWithinRoot(
  Map<String, Object?> args, {
  required String root,
}) {
  const pathKeys = ['path', 'parent_path', 'source_path', 'destination_path'];
  var sawPath = false;
  for (final key in pathKeys) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty) continue;
    sawPath = true;
    // `~` 路径展开后通常在工作区外，保守按越界处理。
    if (isTildePath(value)) return false;
    if (!isAbsoluteOrOpaque(value)) {
      // 相对路径锚定工作区 root 解析；不含 `..` 时必然落在 root 内。
      if (value.split('/').any((s) => s.trim() == '..')) return false;
      continue;
    }
    if (!pathUnderRoot(value, root)) return false;
  }
  return sawPath;
}

/// Resolves the backend for an opaque [path] by matching it to the workspace
/// whose `root` contains [path] (longest match wins). When no root contains
/// [path], a workspace with the same path style (posix vs 不透明 URI) is
/// chosen — an exec-capable posix backend can address arbitrary posix paths
/// (越不越界交给审批层决定). With no style-compatible workspace at all the
/// call fails with an actionable error instead of blindly picking a backend
/// that can't interpret the path. Shared by the read and write handlers so
/// path→backend routing stays in one place.
Future<WorkspaceBackend> backendForPath(Ref ref, String path) async {
  final workspaces = await loadWorkspaces(ref);
  if (workspaces.isEmpty) {
    throw const FileEditorError(
      '当前没有任何工作区，请先在工作区页面「打开文件夹」后再试。',
    );
  }
  Workspace? best;
  for (final w in workspaces) {
    if (pathUnderRoot(path, w.root)) {
      if (best == null || w.root.length > best.root.length) best = w;
    }
  }
  if (best == null) {
    final wantsOpaque = path.contains('://');
    for (final w in workspaces) {
      if (w.root.contains('://') == wantsOpaque) {
        best = w;
        break;
      }
    }
  }
  if (best == null) {
    final roots = workspaces.map((w) => '「${w.name}」${w.root}').join('；');
    throw FileEditorError(
      '路径不在任何工作区内，且当前工作区后端无法访问该路径：$path。'
      '已打开的工作区根：$roots。'
      '工作区内文件请用相对路径；工作区外的路径请改用终端工具'
      '（run_command / terminal_execute）操作。',
    );
  }
  return resolveWorkspaceById(ref, best.id);
}

/// Last path segment of a posix [path] (no trailing-slash handling needed —
/// tool paths never carry one except the bare root, which yields '').
String posixBasename(String path) {
  final i = path.lastIndexOf('/');
  return i < 0 ? path : path.substring(i + 1);
}

/// Parent directory of a posix [path]; '/' at the top.
String posixDirname(String path) {
  final i = path.lastIndexOf('/');
  if (i < 0) return '';
  return i == 0 ? '/' : path.substring(0, i);
}

/// Finds the immediate child named [name] inside the opaque directory [dir],
/// or null when no such child exists. Used by write handlers to detect
/// name clashes (opaque SAF URIs can't be probed by string).
Future<WorkspaceEntry?> findChildByName(
  WorkspaceBackend backend,
  String dir,
  String name,
) async {
  final entries = await backend.listDir(dir);
  for (final e in entries) {
    if (e.name == name) return e;
  }
  return null;
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

/// Directories skipped during recursive listing: dependency/build/cache
/// trees that are huge and almost never what the model wants. The entry
/// itself is still listed (so the model knows it exists) but its contents
/// are not walked; list it explicitly by path to inspect inside.
const Set<String> kListIgnoredDirs = {
  'node_modules',
  '.git',
  '.svn',
  '.hg',
  'dist',
  'build',
  'out',
  'target',
  '.dart_tool',
  '.gradle',
  '.idea',
  '.vscode',
  '__pycache__',
  '.venv',
  'venv',
  '.next',
  '.nuxt',
  'coverage',
  'Pods',
};

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
///
/// [fileNamePattern] 非空时只收集文件名匹配的文件条目（目录仍照常
/// 下探但不进结果）；[sortByMtime] 时最终结果按 mtime 降序。
Future<RecursiveListing> listRecursive(
  WorkspaceBackend backend,
  String path,
  int maxDepth, {
  RegExp? fileNamePattern,
  bool sortByMtime = false,
}) async {
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
      final include = fileNamePattern == null
          ? true
          : !e.isDirectory && fileNamePattern.hasMatch(e.name);
      if (include) out.add(entryJson(e));
      if (e.isDirectory &&
          depth < maxDepth &&
          !kListIgnoredDirs.contains(e.name)) {
        await walk(e.path, depth + 1);
      }
    }
  }

  await walk(path, 1);
  if (sortByMtime) {
    out.sort((a, b) => (b['mtime'] as int).compareTo(a['mtime'] as int));
  }
  return RecursiveListing(out, truncated: truncated);
}

/// Prefixes each line of [content] with its 1-based line number（`N | 内容`，
/// 行号右对齐），starting at [startAt]. Read-tool output only — write tools
/// always take raw content.
String numberLines(String content, {int startAt = 1}) {
  if (content.isEmpty) return content;
  final hasTrailingNewline = content.endsWith('\n');
  final lines =
      (hasTrailingNewline ? content.substring(0, content.length - 1) : content)
          .split('\n');
  final width = '${startAt + lines.length - 1}'.length;
  final buf = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    buf.write('${'${startAt + i}'.padLeft(width)} | ${lines[i]}');
    if (i < lines.length - 1 || hasTrailingNewline) buf.write('\n');
  }
  return buf.toString();
}

// ===== content processing (shared by all write handlers) =====
//
// Models occasionally wrap whole-file content in a Markdown code fence, or send
// HTML-escaped text instead of the literal characters. The helpers below undo
// those two artefacts — but **only** when they're unambiguous, so legitimate
// file content (a Markdown doc, an HTML/XML source containing real `&lt;`) is
// never silently corrupted. The same processing runs for every write tool so a
// given input always produces the same bytes regardless of which tool wrote it.

/// Normalises model-supplied file [content] for any write tool: strips a single
/// fence that wraps the *entire* payload, then un-escapes HTML entities only
/// when the text looks fully-escaped (no raw angle brackets present).
String processIncomingContent(String content) =>
    _unescapeIfFullyEscaped(_stripWrappingCodeFence(content));

final RegExp _fenceOpener = RegExp(r'^```[A-Za-z0-9_+\-.]*\s*$');

/// Removes a Markdown code fence only when it wraps the whole content — i.e.
/// the first line is a bare fence opener (optionally with a language tag) and
/// the last non-blank line is a closing ```` ``` ````. A document that merely
/// *contains* fenced blocks is left untouched (it won't have an opener on line
/// 1 paired with a closer on the final line for the whole file).
String _stripWrappingCodeFence(String content) {
  final lines = content.split('\n');
  if (lines.length < 2) return content;
  if (!_fenceOpener.hasMatch(lines.first)) return content;

  var last = lines.length - 1;
  while (last > 0 && lines[last].trim().isEmpty) {
    last--;
  }
  if (last == 0 || lines[last].trim() != '```') return content;

  final trailingBlanks = lines.sublist(last + 1);
  final body = lines.sublist(1, last);
  return [...body, ...trailingBlanks].join('\n');
}

/// Un-escapes HTML entities only when the text appears to be *fully* escaped
/// (contains entity-encoded angle brackets but no raw `<`/`>`), which is the
/// signature of a model that escaped its whole output. Mixed content keeps its
/// literal `&lt;` / `&amp;` so HTML/XML/Markdown source survives intact.
String _unescapeIfFullyEscaped(String text) {
  if (text.isEmpty) return text;
  final hasRawAngles = text.contains('<') || text.contains('>');
  final hasEntityAngles = text.contains('&lt;') || text.contains('&gt;');
  if (hasRawAngles || !hasEntityAngles) return text;
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

/// Counts the lines in [text] the way an editor would: empty string → 0, and a
/// single trailing newline does **not** add a phantom extra line. Used for the
/// `totalLines` / `linesInserted` fields and the truncation guard so reported
/// counts match what the model sent.
int countLines(String text) {
  if (text.isEmpty) return 0;
  final newlines = '\n'.allMatches(text).length;
  return text.endsWith('\n') ? newlines : newlines + 1;
}

// Phrases that almost always mean the model elided real code ("// rest of code
// unchanged"). These are specific enough to block a write on their own.
final List<RegExp> _strongOmissionPatterns = [
  RegExp(r'(//|#|/\*)\s*rest\s+of\s+(the\s+)?code', caseSensitive: false),
  RegExp(r'(//|#|/\*)\s*rest\s+of\s+(the\s+)?(file|function|method|class)',
      caseSensitive: false),
  RegExp(r'(//|#|/\*)\s*previous\s+code', caseSensitive: false),
  RegExp(r'(//|#|/\*)\s*(code\s+)?unchanged', caseSensitive: false),
  RegExp(r'(//|#|/\*)\s*same\s+as\s+before', caseSensitive: false),
  RegExp(r'(//|#|/\*)\s*\.{3}\s*remaining', caseSensitive: false),
  RegExp(r'(//|#|/\*)\s*existing\s+code', caseSensitive: false),
];

// A bare "// ..." / "# ..." ellipsis. Common in real code/docs, so it only
// counts as suspicious when the content is also far shorter than declared.
final List<RegExp> _weakOmissionPatterns = [
  RegExp(r'(//|#)\s*\.{3}'),
];

/// Whether [content] contains a strong "rest of code unchanged"-style omission
/// marker — specific enough to reject a whole-file overwrite on its own.
bool detectStrongCodeOmission(String content) =>
    _strongOmissionPatterns.any((p) => p.hasMatch(content));

/// Whether [content] contains any omission marker (strong phrases or a bare
/// `// ...` ellipsis). Use together with a length check to avoid false alarms.
bool detectCodeOmission(String content) =>
    detectStrongCodeOmission(content) ||
    _weakOmissionPatterns.any((p) => p.hasMatch(content));

// ===== structured diff (returned by write/edit on modification) =====

/// Max diff lines included in a tool result before truncation.
const int kDiffSummaryMaxLines = 120;

/// Context lines kept around each changed run in the rendered diff.
const int kDiffSummaryContext = 2;

/// Structured summary of the change [oldText] → [newText]: `linesAdded` /
/// `linesRemoved` counts plus a unified-style `diff` text (±[kDiffSummaryContext]
/// lines of context per hunk, capped at [kDiffSummaryMaxLines] lines).
/// Returns null when the contents are identical.
Map<String, Object?>? diffSummaryJson(String oldText, String newText) {
  if (oldText == newText) return null;
  final diff = computeLineDiff(oldText, newText);
  return {
    'linesAdded': diff.added,
    'linesRemoved': diff.removed,
    'diff': renderCompactDiff(diff),
  };
}

/// Renders [diff] as unified-style text: changed lines prefixed `+`/`-`,
/// [context] lines of surrounding context, hunks separated by `…`, truncated
/// at [maxLines] with a trailing marker.
String renderCompactDiff(
  LineDiff diff, {
  int context = kDiffSummaryContext,
  int maxLines = kDiffSummaryMaxLines,
}) {
  final lines = diff.lines;
  // Mark which indices to keep: changed lines and ±context around them.
  final keep = List<bool>.filled(lines.length, false);
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].type == DiffLineType.context) continue;
    final lo = i - context < 0 ? 0 : i - context;
    final hi = i + context >= lines.length ? lines.length - 1 : i + context;
    for (var j = lo; j <= hi; j++) {
      keep[j] = true;
    }
  }
  final out = <String>[];
  var inGap = false;
  for (var i = 0; i < lines.length; i++) {
    if (!keep[i]) {
      if (!inGap && out.isNotEmpty) {
        out.add('…');
        inGap = true;
      }
      continue;
    }
    inGap = false;
    if (out.length >= maxLines) {
      out.add('…（diff 过长，已截断）');
      break;
    }
    final l = lines[i];
    final prefix = switch (l.type) {
      DiffLineType.added => '+',
      DiffLineType.removed => '-',
      DiffLineType.context => ' ',
    };
    out.add('$prefix${l.text}');
  }
  return out.join('\n');
}
