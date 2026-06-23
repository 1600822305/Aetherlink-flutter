/// Text preprocessing utilities for TTS playback.
///
/// Ported from the Web version's `textProcessor.ts`.
class TtsTextPreprocessor {
  const TtsTextPreprocessor._();

  /// Strips Markdown formatting from [input] so TTS engines receive clean text.
  static String stripMarkdown(String input) {
    var s = input;

    // Remove fenced code blocks
    s = s.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), ' ');

    // Remove inline code
    s = s.replaceAll(RegExp(r'`[^`]*`'), ' ');

    // Images: remove entirely (before links so ![...](...) doesn't become link)
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');

    // Links: keep display text
    s = s.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');

    // Headings and list markers at line start
    s = s.replaceAll(RegExp(r'^[#>\-*+]+\s*', multiLine: true), '');

    // Bold / italic / strikethrough markers
    s = s.replaceAll(RegExp(r'[*_~]{1,3}'), '');

    // Table pipe chars
    s = s.replaceAll('|', ' ');

    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    return s.trim();
  }

  /// Full preprocessing pipeline: stripMarkdown + collapse blank lines.
  static String preprocess(String text) {
    var processed = stripMarkdown(text);
    processed = processed.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return processed.trim();
  }
}
