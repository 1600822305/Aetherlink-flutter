// Line-level diff used to render Cursor/Windsurf-style diffs for
// `@aether/file-editor` tool calls.
//
// The vendored `diff_match_patch` package only exposes a character-level diff,
// so this wraps it with the classic "lines→chars" encoding: every unique line
// is mapped to a single UTF-16 code unit, the two encoded strings are diffed
// with Myers (checklines disabled, since each token is already one char), and
// the result is decoded back into whole-line additions/removals/context.

import 'package:diff_match_patch/diff_match_patch.dart';

/// Whether a diff line was added, removed, or is unchanged context.
enum DiffLineType { context, added, removed }

/// A single line in a rendered diff. [text] never contains the trailing
/// newline, and is free of any `+`/`-` prefix (the type drives the gutter).
class DiffLine {
  const DiffLine(this.type, this.text);

  final DiffLineType type;
  final String text;
}

/// A computed line diff plus its `+added / -removed` line counts.
class LineDiff {
  const LineDiff({
    required this.lines,
    required this.added,
    required this.removed,
  });

  final List<DiffLine> lines;
  final int added;
  final int removed;

  bool get isEmpty => lines.isEmpty;
}

/// Computes a whole-line diff between [oldText] and [newText].
///
/// A changed line surfaces as a removed line immediately followed by an added
/// line, matching the unified-diff convention used by IDEs.
LineDiff computeLineDiff(String oldText, String newText) {
  final encoder = _LineEncoder();
  final chars1 = encoder.encode(oldText);
  final chars2 = encoder.encode(newText);

  final dmp = DiffMatchPatch();
  // checklines:false — tokens are already single chars, so the line-mode
  // pre-pass would be redundant work.
  final diffs = dmp.diff(chars1, chars2, false);

  final lines = <DiffLine>[];
  var added = 0;
  var removed = 0;
  for (final diff in diffs) {
    final type = switch (diff.operation) {
      DIFF_INSERT => DiffLineType.added,
      DIFF_DELETE => DiffLineType.removed,
      _ => DiffLineType.context,
    };
    for (final code in diff.text.codeUnits) {
      final line = encoder.decode(code);
      lines.add(DiffLine(type, _stripNewline(line)));
      if (type == DiffLineType.added) added++;
      if (type == DiffLineType.removed) removed++;
    }
  }
  return LineDiff(lines: lines, added: added, removed: removed);
}

String _stripNewline(String line) {
  if (line.endsWith('\n')) {
    return line.substring(0, line.length - (line.endsWith('\r\n') ? 2 : 1));
  }
  return line;
}

/// Maps unique whole lines (newline included) to single UTF-16 code units so a
/// character diff behaves as a line diff.
class _LineEncoder {
  final Map<String, int> _lineToCode = {};
  final List<String> _codeToLine = [];

  String encode(String text) {
    final buf = StringBuffer();
    for (final line in _splitKeepingNewlines(text)) {
      var code = _lineToCode[line];
      if (code == null) {
        // Code unit 0 (NUL) is avoided; start at 1 so encoded strings stay
        // printable-ish and never embed a NUL terminator.
        code = _codeToLine.length + 1;
        _lineToCode[line] = code;
        _codeToLine.add(line);
      }
      buf.writeCharCode(code);
    }
    return buf.toString();
  }

  String decode(int code) {
    final index = code - 1;
    if (index < 0 || index >= _codeToLine.length) return '';
    return _codeToLine[index];
  }

  static List<String> _splitKeepingNewlines(String text) {
    if (text.isEmpty) return const [];
    final result = <String>[];
    var start = 0;
    while (true) {
      final nl = text.indexOf('\n', start);
      if (nl == -1) {
        if (start < text.length) result.add(text.substring(start));
        break;
      }
      result.add(text.substring(start, nl + 1));
      start = nl + 1;
    }
    return result;
  }
}

/// Best-effort source language for [fileName], by extension, as a highlight.js
/// language id (or `null` for plain text / unknown). Mirrors the alias set used
/// by the chat code blocks.
String? languageForFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return null;
  final ext = fileName.substring(dot + 1).toLowerCase();
  return switch (ext) {
    'dart' => 'dart',
    'js' || 'mjs' || 'cjs' || 'jsx' => 'javascript',
    'ts' || 'tsx' => 'typescript',
    'py' || 'pyi' => 'python',
    'rb' => 'ruby',
    'go' => 'go',
    'rs' => 'rust',
    'java' => 'java',
    'kt' || 'kts' => 'kotlin',
    'swift' => 'swift',
    'c' || 'h' => 'c',
    'cc' || 'cpp' || 'cxx' || 'hpp' || 'hxx' => 'cpp',
    'cs' => 'csharp',
    'm' || 'mm' => 'objectivec',
    'php' => 'php',
    'sh' || 'bash' || 'zsh' => 'bash',
    'json' => 'json',
    'yaml' || 'yml' => 'yaml',
    'toml' => 'ini',
    'ini' || 'cfg' || 'conf' => 'ini',
    'xml' || 'html' || 'htm' || 'xhtml' => 'xml',
    'css' => 'css',
    'scss' || 'sass' => 'scss',
    'less' => 'less',
    'sql' => 'sql',
    'md' || 'markdown' => 'markdown',
    'gradle' => 'gradle',
    'dockerfile' => 'dockerfile',
    'lua' => 'lua',
    'r' => 'r',
    'scala' => 'scala',
    'dart_tool' => null,
    _ => null,
  };
}
