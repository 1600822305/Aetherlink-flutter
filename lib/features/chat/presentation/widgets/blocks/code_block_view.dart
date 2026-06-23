import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_highlight/themes/atom-one-dark-reasonable.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/highlight.dart' show Node, highlight;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';

/// A fenced code block, ported from the original `CodeBlockView` /
/// `MarkdownCodeBlock`.
///
/// Header shows the language as `<LANG>` (uppercase) on the left and a copy
/// button on the right. The body consumes the sidebar's code-block display
/// settings: line numbers, collapsible/default-collapsed state and
/// wrap-vs-horizontal-scroll rendering.
class CodeBlockView extends ConsumerStatefulWidget {
  const CodeBlockView({required this.language, required this.code, super.key});

  final String language;
  final String code;

  @override
  ConsumerState<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends ConsumerState<CodeBlockView> {
  bool _copied = false;
  bool? _expandedOverride;

  @override
  void didUpdateWidget(covariant CodeBlockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language ||
        oldWidget.code != widget.code) {
      _expandedOverride = null;
      _copied = false;
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xF21E1E1E) : const Color(0xF2FAFAFA);
    final headerBg = isDark ? const Color(0xF2282828) : const Color(0xF2F0F0F0);
    final border = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final settings = ref.watch(sidebarSettingsControllerProvider);
    final expanded = _effectiveExpanded(settings);
    final normalizedLanguage = _displayLanguage(widget.language);
    final highlightLanguage = _normalizeHighlightLanguage(widget.language);
    final highlightTheme = _transparentBgTheme(
      isDark ? atomOneDarkReasonableTheme : githubTheme,
    );
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
      color: theme.colorScheme.onSurface,
    );
    final lineNumberStyle = codeStyle.copyWith(
      color: labelColor.withValues(alpha: isDark ? 0.62 : 0.72),
      fontWeight: FontWeight.w500,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: settings.codeCollapsible
                      ? _CodeBlockHeaderToggle(
                          expanded: expanded,
                          onTap: () => _toggleExpanded(settings),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: _LanguageLabel(
                                  language: normalizedLanguage,
                                  color: labelColor,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                expanded
                                    ? LucideIcons.chevronDown
                                    : LucideIcons.chevronRight,
                                size: 14,
                                color: labelColor,
                              ),
                            ],
                          ),
                        )
                      : _LanguageLabel(
                          language: normalizedLanguage,
                          color: labelColor,
                        ),
                ),
                if (settings.copyableCodeBlocks)
                  IconButton(
                    tooltip: _copied ? '已复制' : '复制代码',
                    onPressed: _copy,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      _copied ? LucideIcons.check : LucideIcons.copy,
                      size: 14,
                      color: _copied ? Colors.green : labelColor,
                    ),
                  ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: expanded
                ? _CodeBlockBody(
                    key: const ValueKey('code-block-body-expanded'),
                    code: widget.code,
                    highlightLanguage: highlightLanguage,
                    highlightTheme: highlightTheme,
                    showLineNumbers: settings.codeShowLineNumbers,
                    wrappable: settings.codeWrappable,
                    codeStyle: codeStyle,
                    lineNumberStyle: lineNumberStyle,
                    gutterBorderColor: border,
                  )
                : const SizedBox(
                    key: ValueKey('code-block-body-collapsed'),
                    width: double.infinity,
                  ),
          ),
        ],
      ),
    );
  }

  bool _effectiveExpanded(SidebarSettings settings) {
    if (!settings.codeCollapsible) return true;
    return _expandedOverride ?? !settings.codeDefaultCollapsed;
  }

  void _toggleExpanded(SidebarSettings settings) {
    if (!settings.codeCollapsible) return;
    setState(() => _expandedOverride = !_effectiveExpanded(settings));
  }
}

class _LanguageLabel extends StatelessWidget {
  const _LanguageLabel({required this.language, required this.color});

  final String language;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '<${language.toUpperCase()}>',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        letterSpacing: 0.5,
        color: color,
      ),
    );
  }
}

class _CodeBlockHeaderToggle extends StatelessWidget {
  const _CodeBlockHeaderToggle({
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = expanded ? '折叠代码块' : '展开代码块';
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ),
      ),
    );
  }
}

class _CodeBlockBody extends StatelessWidget {
  const _CodeBlockBody({
    required this.code,
    required this.highlightLanguage,
    required this.highlightTheme,
    required this.showLineNumbers,
    required this.wrappable,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
    super.key,
  });

  final String code;
  final String? highlightLanguage;
  final Map<String, TextStyle> highlightTheme;
  final bool showLineNumbers;
  final bool wrappable;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;

  @override
  Widget build(BuildContext context) {
    final displayCode = _displayCode(code);
    final lineCount = _lineCount(displayCode);
    final content = _CodeBlockContent(
      code: displayCode.isEmpty ? ' ' : displayCode,
      highlightLanguage: highlightLanguage,
      highlightTheme: highlightTheme,
      lineCount: lineCount,
      showLineNumbers: showLineNumbers,
      wrappable: wrappable,
      codeStyle: codeStyle,
      lineNumberStyle: lineNumberStyle,
      gutterBorderColor: gutterBorderColor,
    );

    if (wrappable) {
      return Padding(padding: const EdgeInsets.all(12), child: content);
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: content,
      ),
    );
  }
}

class _CodeBlockContent extends StatelessWidget {
  const _CodeBlockContent({
    required this.code,
    required this.highlightLanguage,
    required this.highlightTheme,
    required this.lineCount,
    required this.showLineNumbers,
    required this.wrappable,
    required this.codeStyle,
    required this.lineNumberStyle,
    required this.gutterBorderColor,
  });

  final String code;
  final String? highlightLanguage;
  final Map<String, TextStyle> highlightTheme;
  final int lineCount;
  final bool showLineNumbers;
  final bool wrappable;
  final TextStyle codeStyle;
  final TextStyle lineNumberStyle;
  final Color gutterBorderColor;

  @override
  Widget build(BuildContext context) {
    final codeText = _SelectableHighlightView(
      code,
      language: highlightLanguage,
      theme: highlightTheme,
      style: codeStyle,
      maxLines: wrappable ? null : lineCount,
    );

    final children = <Widget>[
      if (showLineNumbers) ...[
        _LineNumberGutter(
          lineCount: lineCount,
          style: lineNumberStyle,
          borderColor: gutterBorderColor,
        ),
        const SizedBox(width: 12),
      ],
      if (wrappable) Expanded(child: codeText) else codeText,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: wrappable ? MainAxisSize.max : MainAxisSize.min,
      children: children,
    );
  }
}

class _SelectableHighlightView extends StatefulWidget {
  const _SelectableHighlightView(
    this.source, {
    required this.language,
    required this.theme,
    required this.style,
    this.maxLines,
  });

  final String source;
  final String? language;
  final Map<String, TextStyle> theme;
  final TextStyle style;
  final int? maxLines;

  @override
  State<_SelectableHighlightView> createState() =>
      _SelectableHighlightViewState();
}

class _SelectableHighlightViewState extends State<_SelectableHighlightView> {
  late List<TextSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _highlightSource();
  }

  @override
  void didUpdateWidget(covariant _SelectableHighlightView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source == widget.source &&
        oldWidget.language == widget.language &&
        oldWidget.style == widget.style &&
        oldWidget.maxLines == widget.maxLines &&
        _highlightThemeEquals(oldWidget.theme, widget.theme)) {
      return;
    }
    _spans = _highlightSource();
  }

  List<TextSpan> _highlightSource() {
    if (widget.language == null) {
      return <TextSpan>[TextSpan(text: widget.source)];
    }
    try {
      final result = highlight.parse(widget.source, language: widget.language);
      return _convertNodes(result.nodes ?? const []);
    } catch (_) {
      return <TextSpan>[TextSpan(text: widget.source)];
    }
  }

  List<TextSpan> _convertNodes(List<Node> nodes, [TextStyle? inheritedStyle]) {
    final spans = <TextSpan>[];
    for (final node in nodes) {
      final nodeStyle = _mergeHighlightStyle(
        inheritedStyle,
        widget.theme[node.className],
      );
      if (node.value != null) {
        spans.add(TextSpan(text: node.value, style: nodeStyle));
      } else if (node.children != null) {
        spans.addAll(_convertNodes(node.children!, nodeStyle));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        style: widget.style,
        children: _spans.isEmpty
            ? <TextSpan>[TextSpan(text: widget.source)]
            : _spans,
      ),
      maxLines: widget.maxLines,
    );
  }
}

class _LineNumberGutter extends StatelessWidget {
  const _LineNumberGutter({
    required this.lineCount,
    required this.style,
    required this.borderColor,
  });

  final int lineCount;
  final TextStyle style;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final width = math.max(34.0, 18.0 + lineCount.toString().length * 8.0);
    return Container(
      width: width,
      padding: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Text(
        List.generate(lineCount, (i) => '${i + 1}').join('\n'),
        textAlign: TextAlign.right,
        style: style,
      ),
    );
  }
}

String _displayLanguage(String language) {
  final trimmed = language.trim();
  return trimmed.isEmpty ? 'text' : trimmed;
}

String? _normalizeHighlightLanguage(String language) {
  final normalized = language.trim().toLowerCase();
  if (normalized.isEmpty) return null;
  return switch (normalized) {
    'js' || 'javascript' => 'javascript',
    'ts' || 'typescript' => 'typescript',
    'sh' || 'zsh' || 'bash' || 'shell' => 'bash',
    'yml' || 'yaml' => 'yaml',
    'py' || 'python' => 'python',
    'rb' || 'ruby' => 'ruby',
    'kt' || 'kotlin' => 'kotlin',
    'c#' || 'cs' || 'csharp' => 'csharp',
    'objc' || 'objectivec' => 'objectivec',
    'go' || 'golang' => 'go',
    'html' || 'xml' => 'xml',
    'md' || 'markdown' => 'markdown',
    'text' || 'txt' || 'plain' || 'plaintext' => null,
    _ => normalized,
  };
}

Map<String, TextStyle> _transparentBgTheme(Map<String, TextStyle> base) {
  final theme = Map<String, TextStyle>.from(base);
  final root = base['root'];
  theme['root'] = (root ?? const TextStyle()).copyWith(
    backgroundColor: Colors.transparent,
  );
  return theme;
}

TextStyle? _mergeHighlightStyle(TextStyle? parent, TextStyle? child) {
  if (parent == null) return child;
  if (child == null) return parent;
  return parent.merge(child);
}

bool _highlightThemeEquals(Map<String, TextStyle> a, Map<String, TextStyle> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

String _displayCode(String code) {
  final normalized = code.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return normalized.replaceAll(RegExp(r'\n+$'), '');
}

int _lineCount(String code) {
  if (code.isEmpty) return 1;
  return code.split('\n').length;
}
