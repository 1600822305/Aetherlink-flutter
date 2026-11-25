/// Formats raw terminal bytes into a human-readable diagnostic string: ESC
/// is rendered as the literal text `ESC`, other C0/C1 control characters as
/// `^0x<hex>`, DEL as `^?`, and everything else is written as-is.
///
/// Used to keep diagnostic output (e.g. `TerminalDebugger` and
/// `Terminal.onUnknownSequence`) consistent across the package.
String formatEscapeSequenceForDiagnostics(String chars) {
  final escaped = StringBuffer();
  for (final char in chars.runes) {
    if (char == 0x1b) {
      escaped.write('ESC');
    } else if (char < 32) {
      escaped.write('^0x${char.toRadixString(16)}');
    } else if (char == 127) {
      escaped.write('^?');
    } else {
      escaped.writeCharCode(char);
    }
  }
  return escaped.toString();
}
