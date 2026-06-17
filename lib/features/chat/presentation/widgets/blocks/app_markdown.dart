import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/features/chat/presentation/widgets/blocks/code_block_view.dart';

/// Renders Markdown for message blocks, mirroring the original `Markdown.tsx`.
///
/// The original used `react-markdown` + remark-gfm + remark-math + KaTeX with a
/// custom `code` component ([CodeBlockView]) and external links. This wraps
/// [GptMarkdown] (GFM-style text, tables, lists, links and LaTeX via
/// flutter_math_fork) and routes:
///   * fenced code blocks → [CodeBlockView] (language header + copy);
///   * inline code → a subtle monospace chip;
///   * links → opened externally (`target="_blank"` equivalent).
///
/// LaTeX uses single/double dollar delimiters (`$...$`, `$$...$$`), matching the
/// original's `mathEnableSingleDollar` default.
class AppMarkdown extends StatelessWidget {
  const AppMarkdown({required this.content, this.style, super.key});

  final String content;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyMedium;

    return GptMarkdown(
      content,
      style: baseStyle,
      useDollarSignsForLatex: true,
      onLinkTap: (url, title) {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      codeBuilder: (context, name, code, closed) =>
          CodeBlockView(language: name, code: code),
      highlightBuilder: (context, text, textStyle) {
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(text, style: textStyle.copyWith(fontFamily: 'monospace')),
        );
      },
    );
  }
}
