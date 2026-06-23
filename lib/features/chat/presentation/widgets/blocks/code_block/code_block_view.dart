import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/sidebar_settings.dart';
import 'code_block_body.dart';
import 'code_block_fullscreen.dart';
import 'code_block_search.dart';
import 'code_highlight_utils.dart';
import 'mermaid_view.dart';

/// A fenced code block with syntax highlighting (190+ languages, 110+ themes),
/// line numbers, collapsible/default-collapsed state, wrap-vs-horizontal-scroll,
/// font size control, fullscreen, diff rendering, search, and streaming
/// debounce.
///
/// Uses the `highlighting` package (highlight.js 11.8.0 Dart port) for parsing
/// and `flutter_highlighting` themes for styling.
class CodeBlockView extends ConsumerStatefulWidget {
  const CodeBlockView({
    required this.language,
    required this.code,
    this.isStreaming = false,
    super.key,
  });

  final String language;
  final String code;
  final bool isStreaming;

  @override
  ConsumerState<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends ConsumerState<CodeBlockView> {
  bool _copied = false;
  bool? _expandedOverride;
  bool _showSearch = false;
  String _searchQuery = '';
  int _currentMatchIndex = 0;

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

  void _openFullScreen(SidebarSettings settings, bool isDark) {
    final highlightLanguage = normalizeHighlightLanguage(widget.language);
    final highlightTheme =
        resolveTheme(settings.codeHighlightTheme, isDark);
    final fontSize = settings.codeFontSize.toDouble();
    final theme = Theme.of(context);
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.5,
      color: theme.colorScheme.onSurface,
    );
    final lineNumberStyle = codeStyle.copyWith(
      color: labelColor.withValues(alpha: isDark ? 0.62 : 0.72),
      fontWeight: FontWeight.w500,
    );
    final border = isDark ? Colors.white12 : Colors.black12;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => CodeBlockFullScreen(
          code: widget.code,
          language: widget.language,
          highlightLanguage: highlightLanguage,
          highlightTheme: highlightTheme,
          codeStyle: codeStyle,
          lineNumberStyle: lineNumberStyle,
          gutterBorderColor: border,
          showLineNumbers: settings.codeShowLineNumbers,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _onSearchChanged(String query, int matchCount, int currentIndex) {
    setState(() {
      _searchQuery = query;
      _currentMatchIndex = currentIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(sidebarSettingsControllerProvider);

    // Mermaid: dispatch to dedicated renderer when enabled.
    if (settings.mermaidEnabled &&
        widget.language.toLowerCase() == 'mermaid') {
      return MermaidBlockView(code: widget.code);
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xF21E1E1E) : const Color(0xF2FAFAFA);
    final headerBg =
        isDark ? const Color(0xF2282828) : const Color(0xF2F0F0F0);
    final border = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final expanded = _effectiveExpanded(settings);
    final normalizedLanguage = displayLanguage(widget.language);
    final highlightLanguage = normalizeHighlightLanguage(widget.language);
    final highlightTheme =
        resolveTheme(settings.codeHighlightTheme, isDark);
    final fontSize = settings.codeFontSize.toDouble();
    final codeStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
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
          // Header
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
                // Search button
                IconButton(
                  tooltip: '搜索代码',
                  onPressed: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) _searchQuery = '';
                  }),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: Icon(
                    LucideIcons.search,
                    size: 14,
                    color: _showSearch
                        ? theme.colorScheme.primary
                        : labelColor,
                  ),
                ),
                // Fullscreen button
                IconButton(
                  tooltip: '全屏查看',
                  onPressed: () => _openFullScreen(settings, isDark),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                  icon: Icon(
                    LucideIcons.maximize2,
                    size: 14,
                    color: labelColor,
                  ),
                ),
                // Copy button
                if (settings.copyableCodeBlocks)
                  IconButton(
                    tooltip: _copied ? '已复制' : '复制代码',
                    onPressed: _copy,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 28, height: 28),
                    icon: Icon(
                      _copied ? LucideIcons.check : LucideIcons.copy,
                      size: 14,
                      color: _copied ? Colors.green : labelColor,
                    ),
                  ),
              ],
            ),
          ),
          // Search bar
          if (_showSearch)
            CodeBlockSearchBar(
              code: widget.code,
              onChanged: _onSearchChanged,
              onClose: () => setState(() {
                _showSearch = false;
                _searchQuery = '';
              }),
              labelColor: labelColor,
            ),
          // Body
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: expanded
                ? _buildBody(settings, highlightLanguage, highlightTheme,
                    codeStyle, lineNumberStyle, border)
                : const SizedBox(
                    key: ValueKey('code-block-body-collapsed'),
                    width: double.infinity,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    SidebarSettings settings,
    String? highlightLanguage,
    Map<String, TextStyle> highlightTheme,
    TextStyle codeStyle,
    TextStyle lineNumberStyle,
    Color border,
  ) {
    final body = CodeBlockBody(
      key: const ValueKey('code-block-body-expanded'),
      code: widget.code,
      highlightLanguage: highlightLanguage,
      highlightTheme: highlightTheme,
      showLineNumbers: settings.codeShowLineNumbers,
      wrappable: settings.codeWrappable,
      codeStyle: codeStyle,
      lineNumberStyle: lineNumberStyle,
      gutterBorderColor: border,
      isStreaming: widget.isStreaming,
      searchQuery: _showSearch ? _searchQuery : null,
      currentMatchIndex: _showSearch ? _currentMatchIndex : null,
    );

    if (!settings.codeFixedHeight) return body;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: settings.codeMaxHeight.toDouble()),
      child: SingleChildScrollView(child: body),
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
