extension StringCharCode on String {
  int get charCode {
    return codeUnitAt(0);
  }
}

/// The single code point [text] consists of, or null when it is not exactly
/// one.
///
/// Equivalent to `text.runes.length == 1 ? text.runes.first : null`, without
/// walking the string to count runes or allocating a rune iterator to read
/// the first one. Key handling asks this per keystroke and used to do both.
int? singleCodePoint(String text) {
  if (text.length == 1) return text.codeUnitAt(0);
  if (text.length != 2) return null;

  final leading = text.codeUnitAt(0);
  if (leading < 0xd800 || leading > 0xdbff) return null;
  final trailing = text.codeUnitAt(1);
  if (trailing < 0xdc00 || trailing > 0xdfff) return null;

  return 0x10000 + ((leading - 0xd800) << 10) + (trailing - 0xdc00);
}
