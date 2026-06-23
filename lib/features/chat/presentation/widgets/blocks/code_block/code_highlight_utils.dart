import 'package:flutter/material.dart';
import 'package:highlighting/highlighting.dart' show Node, highlight;

import 'code_highlight_themes.dart';

/// Parse [source] into highlighted [TextSpan]s using highlight.js.
List<TextSpan> parseToSpans(
  String source,
  String? language,
  Map<String, TextStyle> theme,
) {
  if (language == null) {
    return <TextSpan>[TextSpan(text: source)];
  }
  try {
    final result = highlight.parse(source, languageId: language);
    return _convertNodes(result.nodes ?? const [], theme);
  } catch (_) {
    return <TextSpan>[TextSpan(text: source)];
  }
}

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
Map<String, TextStyle> resolveTheme(String themeName, bool isDark) {
  if (themeName == 'auto') {
    return _transparentBg(
      isDark ? kCodeThemeDarkDefault : kCodeThemeLightDefault,
    );
  }
  final resolved = kCodeHighlightThemes[themeName];
  if (resolved != null) return _transparentBg(resolved);
  return _transparentBg(
    isDark ? kCodeThemeDarkDefault : kCodeThemeLightDefault,
  );
}

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
