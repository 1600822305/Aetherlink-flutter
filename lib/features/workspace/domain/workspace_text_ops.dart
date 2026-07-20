// Backend-neutral file-text intelligence — **pure functions, zero IO**.
//
// SAF performs `applyDiff` / `replaceInFile` / `insertContent` /
// `readFileRange` / `rangeHash` inside its native plugin (see
// docs/本地SAF工作区插件-方法规格.md §3.3, §P1/P2). Non-plugin backends (SSH,
// and any future remote backend) have no such native helper, so the same
// "read → transform text → write" smarts must live in Dart. This file is that
// shared layer: every function takes the *current text* plus parameters and
// returns the *new text* / a result — it never touches the filesystem or a
// transport. The owning backend reads the file (SFTP, …), calls in here, then
// writes the result back and emits its change event.
//
// **Self-consistency over byte-parity with SAF.** A given backend uses these
// functions for *both* sides of an optimistic-lock round-trip ([rangeHash] on
// read, re-check on [applyDiff]), so the only contract that matters is that
// they agree with *each other*. SAF's native hashing is a separate island that
// never meets these results, so we don't try to reproduce its exact bytes —
// we just keep the semantics described in the plugin spec (§3.3): 1-based
// closed line ranges, raw bytes with LF/CRLF preserved (no normalization),
// sha256 → lowercase hex.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'workspace_backend.dart'
    show WorkspaceDiffFormat, WorkspaceFileRange;

/// Outcome of [replaceInFile].
class TextReplaceOutcome {
  const TextReplaceOutcome({
    required this.newContent,
    required this.replacements,
  });

  final String newContent;
  final int replacements;
}

/// Outcome of [applyDiff]. [newContent] is null when the diff did not apply
/// ([success] false), whether because the optimistic-lock check failed
/// ([conflict] true) or a SEARCH block / hunk could not be located.
class TextDiffOutcome {
  const TextDiffOutcome({
    required this.success,
    required this.newContent,
    this.conflict = false,
    this.linesChanged = 0,
    this.linesAdded = 0,
    this.linesDeleted = 0,
  });

  const TextDiffOutcome.conflict()
      : success = false,
        conflict = true,
        newContent = null,
        linesChanged = 0,
        linesAdded = 0,
        linesDeleted = 0;

  const TextDiffOutcome.failure()
      : success = false,
        conflict = false,
        newContent = null,
        linesChanged = 0,
        linesAdded = 0,
        linesDeleted = 0;

  final bool success;

  /// True only when the failure was an optimistic-lock mismatch (the backend
  /// maps this to the plugin's `E_RANGE_CONFLICT`); a plain
  /// could-not-locate-SEARCH failure leaves this false.
  final bool conflict;

  final String? newContent;
  final int linesChanged;
  final int linesAdded;
  final int linesDeleted;
}

/// Splits [content] into lines, each **retaining its trailing terminator**
/// (`\n` or `\r\n`). The last line keeps no terminator unless [content] ends
/// with one (in which case there is no extra trailing empty element). Empty
/// input yields an empty list. This preserves raw bytes so [rangeHash] can
/// hash a range without normalizing line endings.
List<String> _splitKeepingEol(String content) {
  final lines = <String>[];
  final length = content.length;
  var start = 0;
  for (var i = 0; i < length; i++) {
    if (content.codeUnitAt(i) == 0x0A) {
      lines.add(content.substring(start, i + 1));
      start = i + 1;
    }
  }
  if (start < length) lines.add(content.substring(start));
  return lines;
}

/// The number of text lines in [content] (editor-style: a trailing newline
/// does not add a phantom empty line). Empty input is 0 lines.
int countLines(String content) => _splitKeepingEol(content).length;

/// sha256 (lowercase hex) of the raw bytes of [content], used as a whole-file
/// optimistic-lock token (mirrors the plugin's `getFileHash`).
String fileHash(String content) =>
    sha256.convert(utf8.encode(content)).toString();

/// sha256 (lowercase hex) of just the raw bytes of lines
/// `[startLine, endLine]` (1-based, inclusive), line terminators preserved.
/// Out-of-range bounds are clamped to the file. This is the token returned by
/// [readFileRange] and re-checked by [applyDiff]'s optimistic lock.
String rangeHash(String content, int startLine, int endLine) {
  final lines = _splitKeepingEol(content);
  final from = (startLine - 1).clamp(0, lines.length);
  final to = endLine.clamp(0, lines.length);
  final slice = from >= to ? '' : lines.sublist(from, to).join();
  return sha256.convert(utf8.encode(slice)).toString();
}

/// Reads lines `[startLine, endLine]` (1-based, inclusive) of [content] as a
/// [WorkspaceFileRange], with a [rangeHash] over exactly that slice. Throws
/// [ArgumentError] when `startLine < 1` or `startLine > endLine`.
WorkspaceFileRange readFileRange(String content, int startLine, int endLine) {
  if (startLine < 1 || startLine > endLine) {
    throw ArgumentError('invalid range: startLine=$startLine endLine=$endLine');
  }
  final lines = _splitKeepingEol(content);
  final total = lines.length;
  final from = (startLine - 1).clamp(0, total);
  final to = endLine.clamp(0, total);
  final slice = from >= to ? '' : lines.sublist(from, to).join();
  return WorkspaceFileRange(
    content: slice,
    totalLines: total,
    startLine: startLine,
    endLine: endLine,
    rangeHash: sha256.convert(utf8.encode(slice)).toString(),
  );
}

/// Inserts [insert] before 1-based [line] in [content], returning the new
/// text. A [line] past the end appends. Throws [ArgumentError] for `line < 1`.
/// [insert] is taken verbatim; pass a trailing `\n` if you want it on its own
/// line.
String insertContent(String content, int line, String insert) {
  if (line < 1) throw ArgumentError('line must be >= 1, got $line');
  final lines = _splitKeepingEol(content);
  final index = (line - 1).clamp(0, lines.length);
  // Inserting before a line that currently has no trailing newline (the last
  // line) would glue the inserted text onto it; give that line a terminator
  // first so the insertion lands on its own line.
  if (index == lines.length && lines.isNotEmpty && !lines.last.endsWith('\n')) {
    lines[lines.length - 1] = '${lines.last}\n';
  }
  lines.insert(index, insert);
  return lines.join();
}

/// Replaces occurrences of [search] with [replace] in [content]. When
/// [isRegex], [search] is a regular expression (with [caseSensitive] honored);
/// otherwise it is a literal. [replaceAll] replaces every match, else just the
/// first. Returns the new text plus the number of replacements made.
TextReplaceOutcome replaceInFile(
  String content,
  String search,
  String replace, {
  bool isRegex = false,
  bool replaceAll = true,
  bool caseSensitive = true,
}) {
  if (search.isEmpty) {
    return TextReplaceOutcome(newContent: content, replacements: 0);
  }
  final pattern = isRegex
      ? RegExp(search, caseSensitive: caseSensitive)
      : RegExp(RegExp.escape(search), caseSensitive: caseSensitive);
  var count = 0;
  final buffer = StringBuffer();
  var last = 0;
  for (final match in pattern.allMatches(content)) {
    if (!replaceAll && count >= 1) break;
    buffer
      ..write(content.substring(last, match.start))
      ..write(_expandGroups(replace, match, isRegex));
    last = match.end;
    count++;
  }
  buffer.write(content.substring(last));
  return TextReplaceOutcome(
    newContent: count == 0 ? content : buffer.toString(),
    replacements: count,
  );
}

/// Expands `$1` / `${1}` backreferences in a regex replacement; literal
/// replacements are returned unchanged.
String _expandGroups(String replace, Match match, bool isRegex) {
  if (!isRegex) return replace;
  return replace.replaceAllMapped(RegExp(r'\$(\d+)|\$\{(\d+)\}'), (m) {
    final group = int.parse(m.group(1) ?? m.group(2)!);
    if (group > match.groupCount) return m.group(0)!;
    return match.group(group) ?? '';
  });
}

/// Applies [diff] to [content]. When [expectedRangeHash] is given the write is
/// gated by an optimistic-lock check first: the hash of the current
/// `[rangeStartLine, rangeEndLine]` slice (or the whole file when those are
/// omitted) must equal [expectedRangeHash], otherwise a
/// [TextDiffOutcome.conflict] is returned. [format] selects the diff grammar:
/// SEARCH/REPLACE blocks (primary) or unified hunks.
TextDiffOutcome applyDiff(
  String content,
  String diff, {
  WorkspaceDiffFormat format = WorkspaceDiffFormat.searchReplace,
  String? expectedRangeHash,
  int? rangeStartLine,
  int? rangeEndLine,
}) {
  if (expectedRangeHash != null) {
    final actual = (rangeStartLine != null && rangeEndLine != null)
        ? rangeHash(content, rangeStartLine, rangeEndLine)
        : fileHash(content);
    if (actual != expectedRangeHash) return const TextDiffOutcome.conflict();
  }
  return switch (format) {
    WorkspaceDiffFormat.searchReplace => _applySearchReplace(content, diff),
    WorkspaceDiffFormat.unified => _applyUnified(content, diff),
  };
}

final _searchStart = RegExp(r'^<{3,}\s*SEARCH\s*$');
final _divider = RegExp(r'^={3,}\s*$');
final _replaceEnd = RegExp(r'^>{3,}\s*REPLACE\s*$');

/// Applies one or more `<<<<<<< SEARCH … ======= … >>>>>>> REPLACE` blocks in
/// order. Each block's SEARCH text must be found verbatim in the (running)
/// content; the first occurrence is replaced. A missing SEARCH block fails the
/// whole diff.
TextDiffOutcome _applySearchReplace(String content, String diff) {
  final lines = const LineSplitter().convert(diff);
  var current = content;
  var changed = 0, added = 0, deleted = 0;
  var matchedAny = false;
  var i = 0;
  while (i < lines.length) {
    if (!_searchStart.hasMatch(lines[i])) {
      i++;
      continue;
    }
    i++;
    final searchLines = <String>[];
    while (i < lines.length && !_divider.hasMatch(lines[i])) {
      searchLines.add(lines[i]);
      i++;
    }
    if (i >= lines.length) return const TextDiffOutcome.failure();
    i++; // skip divider
    final replaceLines = <String>[];
    while (i < lines.length && !_replaceEnd.hasMatch(lines[i])) {
      replaceLines.add(lines[i]);
      i++;
    }
    if (i >= lines.length) return const TextDiffOutcome.failure();
    i++; // skip replace end

    final search = searchLines.join('\n');
    final replace = replaceLines.join('\n');
    final at = search.isEmpty ? -1 : current.indexOf(search);
    if (at < 0) return const TextDiffOutcome.failure();
    current = current.replaceRange(at, at + search.length, replace);
    matchedAny = true;
    final s = searchLines.length, r = replaceLines.length;
    changed += s < r ? s : r;
    added += r > s ? r - s : 0;
    deleted += s > r ? s - r : 0;
  }
  if (!matchedAny) return const TextDiffOutcome.failure();
  return TextDiffOutcome(
    success: true,
    newContent: current,
    linesChanged: changed,
    linesAdded: added,
    linesDeleted: deleted,
  );
}

final _hunkHeader = RegExp(r'^@@\s*-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s*@@');

/// Applies a standard unified diff. Each `@@ -l,s +l,s @@` hunk is located by
/// its old start line; context (` `) and removed (`-`) lines must match the
/// file there, then the hunk's new side replaces that span. File headers
/// (`---` / `+++`) are ignored.
TextDiffOutcome _applyUnified(String content, String diff) {
  final fileLines = content.isEmpty ? <String>[] : content.split('\n');
  final diffLines = const LineSplitter().convert(diff);
  var changed = 0, added = 0, deleted = 0;
  var applied = false;
  // Cumulative offset between original line numbers and the mutated buffer.
  var offset = 0;
  var i = 0;
  while (i < diffLines.length) {
    final header = _hunkHeader.firstMatch(diffLines[i]);
    if (header == null) {
      i++;
      continue;
    }
    final oldStart = int.parse(header.group(1)!);
    i++;
    final oldSlice = <String>[];
    final newSlice = <String>[];
    while (i < diffLines.length && !diffLines[i].startsWith('@@')) {
      final line = diffLines[i];
      if (line.isEmpty) {
        // A bare empty line in a hunk is a context line for an empty source row.
        oldSlice.add('');
        newSlice.add('');
      } else {
        switch (line[0]) {
          case ' ':
            oldSlice.add(line.substring(1));
            newSlice.add(line.substring(1));
          case '-':
            oldSlice.add(line.substring(1));
          case '+':
            newSlice.add(line.substring(1));
          case r'\': // "\ No newline at end of file"
            break;
          default:
            break;
        }
      }
      i++;
    }
    final at = oldStart - 1 + offset;
    if (at < 0 || at + oldSlice.length > fileLines.length) {
      return const TextDiffOutcome.failure();
    }
    for (var k = 0; k < oldSlice.length; k++) {
      if (fileLines[at + k] != oldSlice[k]) return const TextDiffOutcome.failure();
    }
    fileLines.replaceRange(at, at + oldSlice.length, newSlice);
    offset += newSlice.length - oldSlice.length;
    applied = true;
    final s = oldSlice.length, r = newSlice.length;
    changed += s < r ? s : r;
    added += r > s ? r - s : 0;
    deleted += s > r ? s - r : 0;
  }
  if (!applied) return const TextDiffOutcome.failure();
  return TextDiffOutcome(
    success: true,
    newContent: fileLines.join('\n'),
    linesChanged: changed,
    linesAdded: added,
    linesDeleted: deleted,
  );
}

/// `edit` search 未命中时的智能提示（对标 Claude Code FileEditTool 的
/// 失败体验）：空白归一化后能命中 → 提示是空白/缩进差异并给出候选行号；
/// 否则按 search 首个非空行找 trimmed 相等/前缀相似的候选行。都找不到
/// 返回 null（调用方回退到通用错误文案）。仅用于字面量搜索。
String? searchMissHint(String content, String search) {
  String norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final normSearch = norm(search);
  if (normSearch.isEmpty) return null;

  final contentLines = content.split('\n');
  final firstLine = search
      .split('\n')
      .map((l) => l.trim())
      .firstWhere((l) => l.isNotEmpty, orElse: () => '');
  if (firstLine.isEmpty) return null;

  // 1. 空白归一化后全文命中：内容一致但空白/缩进不同。
  if (norm(content).contains(normSearch)) {
    final hits = <int>[];
    for (var i = 0; i < contentLines.length && hits.length < 3; i++) {
      if (norm(contentLines[i]) == firstLine.replaceAll(RegExp(r'\s+'), ' ')) {
        hits.add(i + 1);
      }
    }
    final loc = hits.isEmpty ? '' : '（首行在第 ${hits.join('、')} 行附近）';
    return '文件中存在内容相同但空白/缩进不同的相似段落$loc，'
        '请用 read_file 核对该处的精确缩进与空白后重试。';
  }

  // 2. 按首个非空行找 trimmed 相等 / 前缀相似的候选行。
  final exact = <int>[];
  final prefix = <int>[];
  final probe = firstLine.length > 24 ? firstLine.substring(0, 24) : firstLine;
  for (var i = 0; i < contentLines.length && exact.length < 3; i++) {
    final t = contentLines[i].trim();
    if (t == firstLine) {
      exact.add(i + 1);
    } else if (prefix.length < 3 && t.startsWith(probe)) {
      prefix.add(i + 1);
    }
  }
  final candidates = exact.isNotEmpty ? exact : prefix;
  if (candidates.isEmpty) return null;
  return 'search 的首行在第 ${candidates.join('、')} 行有相似内容，'
      '但整段未能完全匹配，请用 read_file 读取该处最新内容后重试。';
}
