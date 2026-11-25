import 'package:xterm3/src/core/input/event.dart';
import 'package:xterm3/src/core/input/keys.dart';
import 'package:xterm3/src/core/platform.dart';

/// Whether the platform composed a character out of a modified key press, so
/// the modifier is part of the layout rather than a modifier to report.
///
/// macOS composes with Option unless the app opts into option-as-meta: on a
/// Turkish Q layout Option+Q is how `@` is typed. An encoding that reports the
/// press as Alt plus the key (kitty's `CSI 113;3u`, modifyOtherKeys'
/// `CSI 27;3;64~`) hands the application Alt+`@` instead of `@`, and the
/// character is never typed.
///
/// Every Option-only press that produced a printable character counts, on any
/// layout, except one whose character is the key's own: Option added nothing
/// there, so it is left as Alt. A key with no US-layout character to compare
/// against (a layout's own letters, such as Turkish `ş` or `ğ`) produced
/// something only Option could have, so it counts as composed too.
bool isMacOptionComposedText(TerminalKeyboardEvent event) {
  if (event.platform != TerminalTargetPlatform.macos) return false;
  if (!event.alt || event.ctrl || event.superKey) return false;
  final text = event.text;
  if (text == null || text.runes.length != 1) return false;
  final composed = text.runes.first;
  if (isControlCodepoint(composed)) return false;
  final base = usLayoutCodepoint(event.key);
  return base != composed;
}

bool isControlCodepoint(int codepoint) {
  return codepoint < 0x20 || (codepoint >= 0x7f && codepoint <= 0x9f);
}

/// The code point a key carries on a US layout, independent of the text the
/// platform produced for this event.
int? usLayoutCodepoint(TerminalKey key) {
  if (key.index >= TerminalKey.keyA.index &&
      key.index <= TerminalKey.keyZ.index) {
    return key.index - TerminalKey.keyA.index + 97;
  }
  if (key.index >= TerminalKey.digit1.index &&
      key.index <= TerminalKey.digit9.index) {
    return key.index - TerminalKey.digit1.index + 49;
  }
  return switch (key) {
    TerminalKey.digit0 => 48,
    TerminalKey.space => 32,
    TerminalKey.minus => 45,
    TerminalKey.equal => 61,
    TerminalKey.bracketLeft => 91,
    TerminalKey.bracketRight => 93,
    TerminalKey.backslash || TerminalKey.intlBackslash => 92,
    TerminalKey.semicolon => 59,
    TerminalKey.quote => 39,
    TerminalKey.backquote => 96,
    TerminalKey.comma => 44,
    TerminalKey.period => 46,
    TerminalKey.slash => 47,
    _ => null,
  };
}
