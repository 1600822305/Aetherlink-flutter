import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar_settings_controller.dart';

/// A fenced code block, ported from the original `CodeBlockView` /
/// `MarkdownCodeBlock`.
///
/// Header shows the language as `<LANG>` (uppercase) on the left and a copy
/// button on the right; the body is a horizontally scrollable monospace view.
/// Mirrors the original's rounded, bordered card with a slightly darker header
/// strip. Syntax highlighting and the source/preview/split toolbars are later
/// slices — only the language label + copy affordance are ported here.
class CodeBlockView extends ConsumerStatefulWidget {
  const CodeBlockView({required this.language, required this.code, super.key});

  final String language;
  final String code;

  @override
  ConsumerState<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends ConsumerState<CodeBlockView> {
  bool _copied = false;

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
    // 代码块可复制 (设置 tab 常规设置)：关闭时隐藏复制按钮。
    final copyable = ref.watch(
      sidebarSettingsControllerProvider.select((s) => s.copyableCodeBlocks),
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
                  child: Text(
                    '<${(widget.language.isEmpty ? 'text' : widget.language).toUpperCase()}>',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: labelColor,
                    ),
                  ),
                ),
                if (copyable)
                  InkWell(
                    onTap: _copy,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        _copied ? LucideIcons.check : LucideIcons.copy,
                        size: 14,
                        color: _copied ? Colors.green : labelColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
