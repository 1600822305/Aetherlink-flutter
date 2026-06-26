// Pure in-memory find/replace over editor text. No Flutter/backend types so it
// stays trivially testable and reusable. Offsets are UTF-16 code-unit indices,
// matching `String`/`TextEditingController` semantics.

/// A single match as a half-open `[start, end)` range into the searched text.
class TextMatch {
  const TextMatch(this.start, this.end);

  final int start;
  final int end;
}

/// Finds every (non-overlapping) occurrence of [query] in [text]. Returns an
/// empty list when [query] is empty or [regex] fails to compile. Zero-width
/// regex matches are skipped to avoid an infinite scan.
List<TextMatch> findMatches(
  String text,
  String query, {
  bool caseSensitive = false,
  bool regex = false,
}) {
  if (query.isEmpty || text.isEmpty) return const [];
  if (regex) {
    final RegExp re;
    try {
      re = RegExp(query, caseSensitive: caseSensitive, multiLine: true);
    } on FormatException {
      return const [];
    }
    final out = <TextMatch>[];
    for (final m in re.allMatches(text)) {
      if (m.end > m.start) out.add(TextMatch(m.start, m.end));
    }
    return out;
  }
  final hay = caseSensitive ? text : text.toLowerCase();
  final needle = caseSensitive ? query : query.toLowerCase();
  final out = <TextMatch>[];
  var from = 0;
  while (true) {
    final i = hay.indexOf(needle, from);
    if (i < 0) break;
    out.add(TextMatch(i, i + needle.length));
    from = i + needle.length;
  }
  return out;
}

/// Result of a replace-all pass: the rewritten [text] and how many
/// occurrences were [replacements].
class ReplaceResult {
  const ReplaceResult(this.text, this.replacements);

  final String text;
  final int replacements;
}

/// Replaces every occurrence of [query] in [text] with [replacement].
/// For [regex] mode, `$1`/`$2`… backreferences in [replacement] are honored.
ReplaceResult replaceAll(
  String text,
  String query,
  String replacement, {
  bool caseSensitive = false,
  bool regex = false,
}) {
  final matches = findMatches(
    text,
    query,
    caseSensitive: caseSensitive,
    regex: regex,
  );
  if (matches.isEmpty) return ReplaceResult(text, 0);
  if (regex) {
    final re = RegExp(query, caseSensitive: caseSensitive, multiLine: true);
    return ReplaceResult(text.replaceAll(re, replacement), matches.length);
  }
  final buf = StringBuffer();
  var prev = 0;
  for (final m in matches) {
    buf
      ..write(text.substring(prev, m.start))
      ..write(replacement);
    prev = m.end;
  }
  buf.write(text.substring(prev));
  return ReplaceResult(buf.toString(), matches.length);
}

/// Index of the first match at or after [offset], wrapping to 0 when none
/// remain. Returns -1 when [matches] is empty.
int nextMatchIndex(List<TextMatch> matches, int offset) {
  if (matches.isEmpty) return -1;
  for (var i = 0; i < matches.length; i++) {
    if (matches[i].start >= offset) return i;
  }
  return 0;
}

/// Index of the last match strictly before [offset], wrapping to the end when
/// none precede it. Returns -1 when [matches] is empty.
int prevMatchIndex(List<TextMatch> matches, int offset) {
  if (matches.isEmpty) return -1;
  for (var i = matches.length - 1; i >= 0; i--) {
    if (matches[i].start < offset) return i;
  }
  return matches.length - 1;
}
