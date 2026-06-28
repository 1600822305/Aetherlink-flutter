import 'package:flutter/material.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/shared/widgets/app_toast.dart';
import 'package:aetherlink_flutter/shared/widgets/copy_icon_button.dart';

/// Renders a Mermaid diagram with a header bar (label + copy + collapse/expand +
/// fullscreen) that visually matches [CodeBlockView].
///
/// When parsing fails the widget falls back to showing the raw Mermaid source
/// inside a scrollable code container so the user can still read/copy the code.
class MermaidBlockView extends StatefulWidget {
  const MermaidBlockView({
    required this.code,
    super.key,
  });

  final String code;

  @override
  State<MermaidBlockView> createState() => _MermaidBlockViewState();
}

class _MermaidBlockViewState extends State<MermaidBlockView> {
  bool _expanded = true;
  bool _copied = false;
  bool _hasError = false;

  Future<void> _copy() async {
    await AppToast.copy(context, widget.code);
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _openFullScreen(bool isDark) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => _MermaidFullScreen(
          code: widget.code,
          isDark: isDark,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xF21E1E1E) : const Color(0xF2FAFAFA);
    final headerBg =
        isDark ? const Color(0xF2282828) : const Color(0xF2F0F0F0);
    final border = isDark ? Colors.white12 : Colors.black12;
    final labelColor = isDark ? Colors.white70 : Colors.black54;

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
          _buildHeader(headerBg, border, labelColor, isDark),
          // Body
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _expanded
                ? _buildDiagram(isDark)
                : const SizedBox(
                    key: ValueKey('mermaid-collapsed'),
                    width: double.infinity,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    Color headerBg,
    Color border,
    Color labelColor,
    bool isDark,
  ) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.gitBranch, size: 14, color: labelColor),
                  const SizedBox(width: 6),
                  Text(
                    'MERMAID',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (_hasError) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'fallback',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              isDark ? Colors.orange[300] : Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 14,
                    color: labelColor,
                  ),
                ],
              ),
            ),
          ),
          // Fullscreen
          IconButton(
            tooltip: '全屏查看',
            onPressed: () => _openFullScreen(
              Theme.of(context).brightness == Brightness.dark,
            ),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: Icon(LucideIcons.maximize2, size: 14, color: labelColor),
          ),
          // Copy
          IconButton(
            tooltip: _copied ? '已复制' : '复制代码',
            onPressed: _copy,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: Icon(
              _copied ? LucideIcons.check : LucideIcons.copy,
              size: 14,
              color: _copied ? Colors.green : labelColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagram(bool isDark) {
    final style = isDark ? MermaidStyle.dark() : const MermaidStyle();

    return Padding(
      key: const ValueKey('mermaid-expanded'),
      padding: const EdgeInsets.all(8),
      child: MermaidDiagram(
        code: widget.code,
        style: style,
        onError: (_) {
          if (!_hasError && mounted) setState(() => _hasError = true);
        },
        errorBuilder: (context, error) => _buildFallback(isDark, error),
      ),
    );
  }

  Widget _buildFallback(bool isDark, String error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '图表解析失败，显示原始代码',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.orange[300] : Colors.orange[800],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            widget.code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fullscreen Mermaid diagram viewer with InteractiveViewer for pan & zoom.
class _MermaidFullScreen extends StatelessWidget {
  const _MermaidFullScreen({
    required this.code,
    required this.isDark,
  });

  final String code;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final style = isDark ? MermaidStyle.dark() : const MermaidStyle();

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF282828) : const Color(0xFFF0F0F0),
        foregroundColor: labelColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: labelColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '<MERMAID>',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: labelColor,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          CopyIconButton(
            text: code,
            size: 18,
            color: labelColor,
            copiedColor: Colors.green,
            copyTooltip: '复制代码',
            padding: const EdgeInsets.all(12),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: InteractiveMermaidDiagram(
          code: code,
          style: style,
          minScale: 0.2,
          maxScale: 5.0,
        ),
      ),
    );
  }
}
