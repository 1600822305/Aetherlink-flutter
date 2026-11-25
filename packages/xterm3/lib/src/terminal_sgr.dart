part of 'terminal.dart';

/// Implements the SGR (Select Graphic Rendition) subset of [EscapeHandler]:
/// text attributes (bold, italic, underline styles, blink, inverse, ...) and
/// foreground/background/underline color selection.
///
/// This is a mixin rather than a standalone class because every one of
/// these methods is an [EscapeHandler] override, so it must end up as a
/// member of [Terminal] itself for `implements EscapeHandler` to be
/// satisfied — there is no independent object to hold this state, since the
/// state (`_cursorStyle`, `_assignedColors`) is inherently
/// [Terminal]-scoped. The three members below are declared abstract here
/// and satisfied structurally by [Terminal]'s own fields/methods of the
/// same name, which is what lets this mixin be typechecked on its own
/// without an `on` clause pointing back at Terminal.
mixin _SgrHandlers {
  CursorStyle get _cursorStyle;

  Map<int, ({int foreground, int background})> get _assignedColors;

  int _namedColor(int color);

  void resetCursorStyle() {
    _cursorStyle.reset();
    _resetAssignedTextColors();
  }

  void _resetAssignedTextColors() {
    final normalTextColor = _assignedColors[1];
    if (normalTextColor == null) return;
    _cursorStyle.foreground = _namedColor(normalTextColor.foreground);
    _cursorStyle.background = _namedColor(normalTextColor.background);
  }

  void setCursorBold() {
    _cursorStyle.setBold();
  }

  void setCursorFaint() {
    _cursorStyle.setFaint();
  }

  void setCursorItalic() {
    _cursorStyle.setItalic();
  }

  void setCursorUnderline() {
    _cursorStyle.setUnderline();
  }

  void setCursorDoubleUnderline() {
    _cursorStyle.setDoubleUnderline();
  }

  void setCursorUndercurl() {
    _cursorStyle.setUndercurl();
  }

  void setCursorDottedUnderline() {
    _cursorStyle.setDottedUnderline();
  }

  void setCursorDashedUnderline() {
    _cursorStyle.setDashedUnderline();
  }

  void setCursorBlink() {
    _cursorStyle.setBlink();
  }

  void setCursorInverse() {
    _cursorStyle.setInverse();
  }

  void setCursorInvisible() {
    _cursorStyle.setInvisible();
  }

  void setCursorStrikethrough() {
    _cursorStyle.setStrikethrough();
  }

  void setCursorOverline() {
    _cursorStyle.setOverline();
  }

  void setCursorFramed() {
    _cursorStyle.setFramed();
  }

  void setCursorEncircled() {
    _cursorStyle.setEncircled();
  }

  void unsetCursorBold() {
    _cursorStyle.unsetBold();
  }

  void unsetCursorFaint() {
    _cursorStyle.unsetFaint();
  }

  void unsetCursorItalic() {
    _cursorStyle.unsetItalic();
  }

  void unsetCursorUnderline() {
    _cursorStyle.unsetUnderline();
  }

  void unsetCursorBlink() {
    _cursorStyle.unsetBlink();
  }

  void unsetCursorInverse() {
    _cursorStyle.unsetInverse();
  }

  void unsetCursorInvisible() {
    _cursorStyle.unsetInvisible();
  }

  void unsetCursorStrikethrough() {
    _cursorStyle.unsetStrikethrough();
  }

  void unsetCursorOverline() {
    _cursorStyle.unsetOverline();
  }

  void unsetCursorFrame() {
    _cursorStyle.unsetFrame();
  }

  void setForegroundColor16(int color) {
    _cursorStyle.setForegroundColor16(color);
  }

  void setForegroundColor256(int index) {
    _cursorStyle.setForegroundColor256(index);
  }

  void setForegroundColorRgb(int r, int g, int b) {
    _cursorStyle.setForegroundColorRgb(r, g, b);
  }

  void resetForeground() {
    final normalTextColor = _assignedColors[1];
    if (normalTextColor == null) {
      _cursorStyle.resetForegroundColor();
      return;
    }
    _cursorStyle.foreground = _namedColor(normalTextColor.foreground);
  }

  void setBackgroundColor16(int color) {
    _cursorStyle.setBackgroundColor16(color);
  }

  void setBackgroundColor256(int index) {
    _cursorStyle.setBackgroundColor256(index);
  }

  void setBackgroundColorRgb(int r, int g, int b) {
    _cursorStyle.setBackgroundColorRgb(r, g, b);
  }

  void resetBackground() {
    final normalTextColor = _assignedColors[1];
    if (normalTextColor == null) {
      _cursorStyle.resetBackgroundColor();
      return;
    }
    _cursorStyle.background = _namedColor(normalTextColor.background);
  }

  void setUnderlineColor256(int index) {
    _cursorStyle.setUnderlineColor256(index);
  }

  void setUnderlineColorRgb(int r, int g, int b) {
    _cursorStyle.setUnderlineColorRgb(r, g, b);
  }

  void resetUnderlineColor() {
    _cursorStyle.resetUnderlineColor();
  }

  void unsupportedStyle(int param) {
    // no-op
  }
}
