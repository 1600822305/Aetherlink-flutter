// Read-only handlers for the `@aether/file-editor` built-in MCP server.
//
// Each handler maps a tool call to the workspace `WorkspaceBackend` (SAF on
// Android) and returns a JSON envelope via the helpers in
// `file_editor_support.dart`. Names/params mirror the original AetherLink
// `@aether/file-editor` server 1:1.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace_backend.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_diagnostics.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_read_state.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_search.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';

/// `list_files` — list a directory, addressed either by workspace (+
/// optional `sub_path`) or by an opaque `path`; optionally recursive up to
/// `max_depth` levels.
Future<McpToolResult> listFiles(Ref ref, Map<String, Object?> args) async {
  final String dir;
  final WorkspaceBackend backend;
  String? workspaceName;
  final rawPath = optionalString(args, 'path');
  if (rawPath != null) {
    final resolved = await resolvePathArg(ref, args, rawPath);
    dir = resolved.path;
    backend = resolved.backend;
  } else if (args['workspace'] != null) {
    final resolved = await resolveWorkspace(ref, args);
    backend = resolved.backend;
    workspaceName = resolved.workspace.name;
    dir = await navigateSubPath(
      backend,
      resolved.workspace.root,
      optionalString(args, 'sub_path'),
    );
  } else {
    throw const FileEditorError('缺少参数：workspace 与 path 二选一。');
  }

  if (optionalBool(args, 'recursive')) {
    final maxDepth = (optionalInt(args, 'max_depth') ?? 3).clamp(1, 10);
    final listing = await listRecursive(backend, dir, maxDepth);
    return fileEditorOk({
      if (workspaceName != null) 'workspace': workspaceName,
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
  final truncated = entries.length > kMaxRecursiveEntries;
  final shown =
      truncated ? entries.sublist(0, kMaxRecursiveEntries) : entries;
  return fileEditorOk({
    if (workspaceName != null) 'workspace': workspaceName,
    'path': dir,
    'count': entries.length,
    if (truncated) 'truncated': true,
    if (truncated) 'shown': shown.length,
    'files': [for (final e in shown) entryJson(e)],
  });
}

/// `read_file` — read one (`path`) or many (`files`) files, optionally limited
/// to a `start_line`..`end_line` range (1-based, inclusive). Content lines are
/// prefixed `N | ` by default (`line_numbers=false` for raw text) so the model
/// can reference exact line ranges without counting.
///
/// 会话内重复读取（同路径、同范围、文件未变化）返回「文件未变化」存根而非
/// 全文；整文件读取前先 stat，超过 [kMaxWholeReadBytes] 直接要求行范围读取。
Future<McpToolResult> readFile(
  Ref ref,
  Map<String, Object?> args, {
  String sessionKey = '',
}) async {
  final withLineNumbers = optionalBool(args, 'line_numbers', fallback: true);
  final files = args['files'];
  if (files is List && files.isNotEmpty) {
    final results = <Map<String, Object?>>[];
    var errors = 0;
    var skipped = 0;
    var totalChars = 0;
    for (final item in files) {
      if (item is! Map) continue;
      final m = item.map((k, v) => MapEntry(k.toString(), v as Object?));
      final path = optionalString(m, 'path');
      if (path == null) {
        errors++;
        results.add({'status': 'error', 'error': '缺少必需参数: path'});
        continue;
      }
      // 批量总量封顶：单文件上限之外再给整次调用一个总预算，
      // 避免一次传十几个大文件把上下文撑爆；超出后剩余文件标记
      // skipped，提示分批读。
      if (totalChars >= kMaxBatchReadChars) {
        skipped++;
        results.add({
          'path': path,
          'status': 'skipped',
          'error': '本次批量读取已达总量上限（$kMaxBatchReadChars 字符），'
              '该文件未读取；请分批调用或指定行范围。',
        });
        continue;
      }
      try {
        final one = await _readOne(
            ref, args, path,
            optionalInt(m, 'start_line'), optionalInt(m, 'end_line'),
            withLineNumbers: withLineNumbers, sessionKey: sessionKey);
        totalChars += (one['content'] as String? ?? '').length;
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
      'successCount': results.length - errors - skipped,
      'errorCount': errors,
      if (skipped > 0) 'skippedCount': skipped,
      'files': results,
    });
  }
  final path = requireString(args, 'path');
  final one = await _readOne(
      ref, args, path,
      optionalInt(args, 'start_line'), optionalInt(args, 'end_line'),
      withLineNumbers: withLineNumbers, sessionKey: sessionKey);
  return fileEditorOk(one);
}

/// `get_file_info` — metadata (size / mtime / type) plus line count for files.
Future<McpToolResult> getFileInfo(Ref ref, Map<String, Object?> args) async {
  final rawPath = requireString(args, 'path');
  final resolved = await resolvePathArg(ref, args, rawPath);
  final backend = resolved.backend;
  final path = resolved.path;
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
/// ripgrep 级参数：`glob` 路径过滤、`case_sensitive`、`context_lines` 上下文、
/// `output_mode`（content / files_with_matches / count）。
Future<McpToolResult> searchFiles(Ref ref, Map<String, Object?> args) async {
  final rawDirectory = requireString(args, 'directory');
  final query = requireString(args, 'query');
  final resolvedDir = await resolvePathArg(ref, args, rawDirectory);
  final directory = resolvedDir.path;
  final backend = resolvedDir.backend;

  final searchType = switch (optionalString(args, 'search_type')?.toLowerCase()) {
    'content' => WorkspaceSearchType.content,
    'both' => WorkspaceSearchType.both,
    _ => WorkspaceSearchType.name,
  };
  final fileTypes = optionalStringList(args, 'file_types');
  final useRegex = optionalBool(args, 'use_regex');
  final caseSensitive = optionalBool(args, 'case_sensitive');
  final contextLines = (optionalInt(args, 'context_lines') ?? 0).clamp(0, 10);
  final maxResults = (optionalInt(args, 'max_results') ?? 200).clamp(1, 1000);
  final outputMode = optionalString(args, 'output_mode') ?? 'content';
  if (!const {'content', 'files_with_matches', 'count'}.contains(outputMode)) {
    throw FileEditorError(
      '无效的 output_mode: $outputMode（可选 content / files_with_matches / count）',
    );
  }

  final glob = optionalString(args, 'glob');
  final RegExp? globPattern;
  if (glob != null) {
    globPattern = globToRegExp(glob);
    if (globPattern == null) throw FileEditorError('无效的 glob 模式: $glob');
  } else {
    globPattern = null;
  }

  final matcher = SearchLineMatcher.tryCreate(
    query,
    useRegex: useRegex,
    caseSensitive: caseSensitive,
  );
  if (useRegex && matcher == null) {
    throw FileEditorError('无效的正则表达式: $query');
  }

  // 后端搜索是大小写不敏感的，其结果是 case_sensitive 命中的超集；
  // 大小写过滤在下面按行匹配时收紧。
  var results = await backend.searchFiles(
    directory,
    query,
    searchType: searchType,
    fileTypes: fileTypes,
    useRegex: useRegex,
  );
  if (globPattern != null) {
    results = [
      for (final e in results)
        if (globHits(
          globPattern,
          glob!,
          name: e.name,
          relPath: relativePathOf(directory, e.path, e.name),
        ))
          e,
    ];
  }

  // 内容搜索时把命中行（行号 + 内容 + 可选上下文）一并带回，模型不用再
  // 整读文件定位；count 模式给每文件命中行数；files_with_matches 只回文件。
  final contentSearch = searchType != WorkspaceSearchType.name;
  final needLines = contentSearch &&
      matcher != null &&
      (outputMode != 'files_with_matches' || caseSensitive);
  final files = <Map<String, Object?>>[];
  var totalMatches = 0;
  for (final e in results) {
    if (files.length >= maxResults) break;
    final json = entryJson(e);
    if (needLines && !e.isDirectory) {
      final String? content = await _tryRead(backend, e.path);
      if (content != null) {
        if (outputMode == 'count') {
          final count = countMatchingLines(content, matcher);
          if (count == 0 &&
              caseSensitive &&
              searchType == WorkspaceSearchType.content) {
            continue; // 大小写不敏感的候选，在敏感模式下实际没命中
          }
          totalMatches += count;
          json['matchCount'] = count;
        } else {
          final matches = totalMatches < kMaxTotalMatches
              ? findMatchingLines(content, matcher, contextLines: contextLines)
              : const <LineMatch>[];
          if (matches.isEmpty &&
              caseSensitive &&
              searchType == WorkspaceSearchType.content) {
            continue;
          }
          totalMatches += matches.length;
          if (outputMode == 'content') {
            json['matches'] = [for (final m in matches) m.toJson()];
          }
        }
      }
    }
    files.add(json);
  }
  return fileEditorOk({
    'directory': directory,
    'query': query,
    'searchType': searchType.name,
    'outputMode': outputMode,
    if (useRegex) 'useRegex': true,
    if (caseSensitive) 'caseSensitive': true,
    if (glob != null) 'glob': glob,
    if (outputMode == 'count') 'totalMatches': totalMatches,
    'count': files.length,
    'files': files,
  });
}

/// Best-effort text read for match extraction — null when the file can't be
/// read as text (binary / too large / permission); the entry still rides in
/// the results, just without `matches`.
Future<String?> _tryRead(WorkspaceBackend backend, String path) async {
  try {
    return await backend.readFile(path);
  } catch (_) {
    return null;
  }
}

// ===== internals =====

int _dirsFirst(WorkspaceEntry a, WorkspaceEntry b) {
  if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
  return a.name.compareTo(b.name);
}

/// 行号输出时附在 payload 里的提醒：行号前缀仅供定位，不是文件内容。
const String _kLineNumbersNote =
    '每行前的「N | 」是行号前缀，不属于文件内容；写入/edit 的 search 块请用不含行号的原始文本。';

/// 单行超过此长度会被截断（防压缩文件/长 JSON 单行炸上下文）。
const int _kMaxLineChars = 2000;

/// 单次读取的内容字符上限；超出时截断并提示改用行范围分段读。
const int _kMaxReadChars = 60000;

/// 批量读取时整次调用的内容总量上限；达到后剩余文件被跳过。
const int kMaxBatchReadChars = 120000;

/// 整文件读取的字节上限（读前 stat 判定）。远超 [_kMaxReadChars]，只为拦住
/// 「把几 MB 的文件整个读进内存再截断到 6 万字符」的浪费——SAF/SSH 后端
/// 全量读一遍大文件的 IO 成本不小。超限时要求改用行范围分段读取。
const int kMaxWholeReadBytes = 512 * 1024;

/// 重复读取命中时返回的存根提示。
const String _kFileUnchangedNote =
    '文件自上次读取后未发生变化；本会话早前 read_file 返回的内容仍然有效，'
    '请直接引用该结果，无需重读。';

/// 对读到的内容做保护：超长行截断 + 总量封顶。返回处理后的文本与提示。
({String content, String? note}) _guardContent(String content) {
  var truncatedLines = 0;
  var lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].length > _kMaxLineChars) {
      lines[i] = '${lines[i].substring(0, _kMaxLineChars)}…[该行过长已截断]';
      truncatedLines++;
    }
  }
  var text = truncatedLines > 0 ? lines.join('\n') : content;
  String? note;
  if (text.length > _kMaxReadChars) {
    // 按行对齐到上限内，告知模型用行范围继续读。
    var kept = 0;
    var chars = 0;
    lines = text.split('\n');
    for (; kept < lines.length; kept++) {
      final next = chars + lines[kept].length + 1;
      if (next > _kMaxReadChars) break;
      chars = next;
    }
    text = lines.take(kept).join('\n');
    note = '内容过大，仅返回前 $kept 行（共 ${lines.length} 行）；'
        '请用 start_line=${kept + 1} 继续分段读取。';
  } else if (truncatedLines > 0) {
    note = '有 $truncatedLines 行超过 $_kMaxLineChars 字符已被截断。';
  }
  return (content: text, note: note);
}

Future<Map<String, Object?>> _readOne(
  Ref ref,
  Map<String, Object?> args,
  String rawPath,
  int? startLine,
  int? endLine, {
  bool withLineNumbers = true,
  String sessionKey = '',
}) async {
  final resolved = await resolvePathArg(ref, args, rawPath);
  final backend = resolved.backend;
  final path = resolved.path;

  // 读前 stat（best-effort：后端不支持 getFileInfo 时跳过守卫与去重）。
  WorkspaceEntry? info;
  try {
    info = await backend.getFileInfo(path);
  } catch (_) {
    info = null;
  }
  final store = ref.read(fileReadStateProvider);
  if (info != null && !info.isDirectory) {
    if (startLine == null && endLine == null && info.size > kMaxWholeReadBytes) {
      throw FileEditorError(
        '文件过大（${info.size} 字节，整文件读取上限 $kMaxWholeReadBytes 字节），'
        '未读取。请用 start_line/end_line 分段读取；'
        '可先 get_file_info 查看总行数。',
      );
    }
    if (isDuplicateRead(
      store.lookup(sessionKey, path),
      mtime: info.mtime,
      size: info.size,
      startLine: startLine,
      endLine: endLine,
      withLineNumbers: withLineNumbers,
    )) {
      return {
        'path': path,
        'unchanged': true,
        'note': _kFileUnchangedNote,
      };
    }
  }

  void recordRead() {
    if (info == null || info.isDirectory) return;
    store.record(
      sessionKey,
      path,
      FileReadRecord(
        mtime: info.mtime,
        size: info.size,
        startLine: startLine,
        endLine: endLine,
        withLineNumbers: withLineNumbers,
      ),
    );
  }
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
    final guarded = _guardContent(range.content);
    recordRead();
    return {
      'path': path,
      'startLine': start,
      'endLine': end,
      'totalLines': range.totalLines,
      'content': withLineNumbers
          ? numberLines(guarded.content, startAt: start)
          : guarded.content,
      'rangeHash': range.rangeHash,
      if (guarded.note != null) 'truncation': guarded.note,
      if (withLineNumbers) 'note': _kLineNumbersNote,
    };
  }
  final content = await backend.readFile(path);
  final guarded = _guardContent(content);
  recordRead();
  return {
    'path': path,
    'content': withLineNumbers ? numberLines(guarded.content) : guarded.content,
    if (guarded.note != null) 'truncation': guarded.note,
    if (withLineNumbers) 'note': _kLineNumbersNote,
  };
}

/// `get_diagnostics` — 运行项目静态分析并回读诊断（改完代码自检）。
/// 按根目录内容自动探测项目类型（见 [diagnosticsCommandFor]，命令固定
/// 白名单、只读），经工作区后端 exec 执行；SAF 等不可执行后端直接报错。
Future<McpToolResult> getDiagnostics(Ref ref, Map<String, Object?> args) async {
  final resolved = await resolveWorkspace(ref, args);
  final backend = resolved.backend;
  if (!backend.capabilities.canExec) {
    return fileEditorError(
      '当前工作区后端不支持执行命令，无法运行静态分析；'
      '请改用可执行命令的工作区（如本地容器 / SSH）。',
    );
  }
  final dir = await navigateSubPath(
    backend,
    resolved.workspace.root,
    optionalString(args, 'sub_path'),
  );
  final entries = await backend.listDir(dir);
  final detected = diagnosticsCommandFor({for (final e in entries) e.name});
  if (detected == null) {
    return fileEditorError(
      '未识别的项目类型：目录下没有 pubspec.yaml / tsconfig.json / '
      'go.mod / Cargo.toml，无法选择分析命令。可传 sub_path 指定项目子目录。',
    );
  }
  final result = await backend.exec(
    detected.command,
    workingDirectory: dir,
    timeout: const Duration(seconds: 180),
  );
  return fileEditorOk({
    'projectType': detected.projectType,
    'command': detected.command,
    'exitCode': result.exitCode,
    'clean': result.exitCode == 0 && !result.timedOut,
    if (result.timedOut) 'timedOut': true,
    'output': combineDiagnosticsOutput(result.stdout, result.stderr),
  });
}
