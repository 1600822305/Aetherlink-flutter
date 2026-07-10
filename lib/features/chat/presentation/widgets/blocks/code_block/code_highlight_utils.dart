import 'package:flutter/material.dart';
import 'package:highlighting/highlighting.dart' show Mode, Node, highlight;

import 'code_highlight_themes.dart';

/// Parse [source] into highlighted [TextSpan]s using highlight.js.
///
/// Results are memoized in an LRU cache keyed by (source, language, theme
/// identity): list items are disposed and re-realized constantly while
/// scrolling, and re-running highlight.parse on every realization is the
/// single most expensive part of building a code bubble.
List<TextSpan> parseToSpans(
  String source,
  String? language,
  Map<String, TextStyle> theme,
) {
  if (language == null) {
    return <TextSpan>[TextSpan(text: source)];
  }
  final key = (source, language, identityHashCode(theme));
  final cached = _spanCache.remove(key);
  if (cached != null) {
    _spanCache[key] = cached; // re-insert as most recently used
    return cached;
  }
  List<TextSpan> spans;
  try {
    final result = highlight.parse(source, languageId: language);
    spans = _convertNodes(result.nodes ?? const [], theme);
  } catch (_) {
    spans = <TextSpan>[TextSpan(text: source)];
  }
  _spanCache[key] = spans;
  if (_spanCache.length > _spanCacheLimit) {
    _spanCache.remove(_spanCache.keys.first);
  }
  return spans;
}

const _spanCacheLimit = 128;
final Map<(String, String, int), List<TextSpan>> _spanCache = {};

List<TextSpan> _convertNodes(
  List<Node> nodes,
  Map<String, TextStyle> theme, [
  TextStyle? inheritedStyle,
]) {
  final spans = <TextSpan>[];
  for (final node in nodes) {
    final nodeStyle = _mergeStyle(inheritedStyle, theme[node.className]);
    if (node.value != null) {
      spans.add(TextSpan(text: node.value, style: nodeStyle));
    } else if (node.children.isNotEmpty) {
      spans.addAll(_convertNodes(node.children, theme, nodeStyle));
    }
  }
  return spans;
}

/// Lazy per-line syntax highlighter.
///
/// Highlights one line at a time, carrying the parser's ending mode of each
/// line into the next as a continuation (like highlight.js line-by-line mode),
/// so cross-line constructs (block comments, multi-line strings) stay correct.
/// Lines are only parsed on demand and cached, which keeps opening a huge
/// document O(visible lines) instead of O(document).
class LineHighlighter {
  LineHighlighter({
    required this.lines,
    required this.language,
    required this.theme,
  }) : _cache = List<List<TextSpan>?>.filled(lines.length, null);

  final List<String> lines;
  final String? language;
  final Map<String, TextStyle> theme;

  final List<List<TextSpan>?> _cache;
  Mode? _state;
  int _parsedUpTo = 0;
  bool _plain = false;

  /// Spans for [index], parsing forward from the last parsed line if needed.
  List<TextSpan> spansFor(int index) {
    if (index < 0 || index >= lines.length) return const <TextSpan>[];
    if (language == null || _plain) {
      return <TextSpan>[TextSpan(text: lines[index])];
    }
    _ensureParsedThrough(index);
    return _cache[index] ?? <TextSpan>[TextSpan(text: lines[index])];
  }

  void _ensureParsedThrough(int index) {
    while (_parsedUpTo <= index) {
      final line = lines[_parsedUpTo];
      try {
        // ignore: invalid_use_of_internal_member
        final result = highlight.highlight(
          language!,
          line,
          true,
          continuation: _state,
        );
        _cache[_parsedUpTo] = _convertNodes(result.nodes ?? const [], theme);
        _state = result.top;
      } catch (_) {
        _plain = true;
        return;
      }
      _parsedUpTo++;
    }
  }
}

/// Split a flat list of spans into per-line groups by splitting on '\n'.
List<List<TextSpan>> splitSpansByLine(List<TextSpan> spans, int lineCount) {
  final result = List.generate(lineCount, (_) => <TextSpan>[]);
  var lineIndex = 0;
  for (final span in spans) {
    final text = span.text;
    if (text == null || !text.contains('\n')) {
      if (lineIndex < lineCount) result[lineIndex].add(span);
      continue;
    }
    final parts = text.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) lineIndex++;
      if (lineIndex >= lineCount) break;
      if (parts[i].isNotEmpty) {
        result[lineIndex].add(TextSpan(text: parts[i], style: span.style));
      }
    }
  }
  return result;
}

TextStyle? _mergeStyle(TextStyle? parent, TextStyle? child) {
  if (parent == null) return child;
  if (child == null) return parent;
  return parent.merge(child);
}

/// Resolve theme name to a theme map, with transparent background.
///
/// Returns a **cached** map — the same instance is returned for identical
/// `(themeName, isDark)` pairs so downstream identity checks (`identical()`)
/// work correctly and avoid redundant re-highlights.
Map<String, TextStyle> resolveTheme(String themeName, bool isDark) {
  final key = (themeName, isDark);
  final cached = _resolvedThemeCache[key];
  if (cached != null) return cached;

  Map<String, TextStyle> base;
  if (themeName == 'auto') {
    base = isDark ? kCodeThemeDarkDefault : kCodeThemeLightDefault;
  } else {
    base = kCodeHighlightThemes[themeName] ??
        (isDark ? kCodeThemeDarkDefault : kCodeThemeLightDefault);
  }
  final result = _transparentBg(base);
  _resolvedThemeCache[key] = result;
  return result;
}

final Map<(String, bool), Map<String, TextStyle>> _resolvedThemeCache = {};

Map<String, TextStyle> _transparentBg(Map<String, TextStyle> base) {
  final theme = Map<String, TextStyle>.from(base);
  final root = base['root'];
  theme['root'] = (root ?? const TextStyle()).copyWith(
    backgroundColor: Colors.transparent,
  );
  return theme;
}

/// Normalize raw language string for display.
String displayLanguage(String language) {
  final trimmed = language.trim();
  return trimmed.isEmpty ? 'text' : trimmed;
}

/// Map language aliases to highlight.js language IDs.
String? normalizeHighlightLanguage(String language) {
  final normalized = language.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  return switch (normalized) {
    'js' || 'jsx' => 'javascript',
    'ts' || 'tsx' => 'typescript',
    'sh' || 'zsh' || 'bash' || 'shell' => 'bash',
    'yml' || 'yaml' => 'yaml',
    'py' || 'python' => 'python',
    'rb' || 'ruby' => 'ruby',
    'kt' || 'kotlin' => 'kotlin',
    'c#' || 'cs' || 'csharp' => 'csharp',
    'objc' || 'objective-c' || 'objectivec' => 'objectivec',
    'go' || 'golang' => 'go',
    'rs' || 'rust' => 'rust',
    'html' || 'htm' => 'xml',
    'md' || 'markdown' => 'markdown',
    'text' || 'txt' || 'plain' || 'plaintext' => null,
    _ => normalized,
  };
}

/// Normalize line endings and trim trailing newlines.
String displayCode(String code) {
  final normalized = code.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return normalized.replaceAll(RegExp(r'\n+$'), '');
}
