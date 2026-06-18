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

    final brightness = theme.brightness;
    final baseSize = baseStyle?.fontSize ?? 16;

    // Mirror the original markdown.css heading sizes (all relative to body
    // font-size via em units). Because AetherlinkApp applies a global
    // TextScaler (fontSize / 16), baseSize is already scaled — multiplying
    // by the same ratios keeps headings proportional exactly like the web
    // version:
    //   h1: 2em, h2: 1.5em, h3: 1.2em, h4: 1em, h5: 0.9em, h6: 0.8em
    return GptMarkdownTheme(
      gptThemeData: GptMarkdownThemeData(
        brightness: brightness,
        h1: baseStyle?.copyWith(
          fontSize: baseSize * 2.0,
          fontWeight: FontWeight.bold,
        ),
        h2: baseStyle?.copyWith(
          fontSize: baseSize * 1.5,
          fontWeight: FontWeight.bold,
        ),
        h3: baseStyle?.copyWith(
          fontSize: baseSize * 1.2,
          fontWeight: FontWeight.w600,
        ),
        h4: baseStyle?.copyWith(
          fontSize: baseSize * 1.0,
          fontWeight: FontWeight.w600,
        ),
        h5: baseStyle?.copyWith(
          fontSize: baseSize * 0.9,
          fontWeight: FontWeight.w600,
        ),
        h6: baseStyle?.copyWith(
          fontSize: baseSize * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: GptMarkdown(
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
      ),
    );
  }
}
