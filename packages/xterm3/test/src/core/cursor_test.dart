import 'package:test/test.dart';
import 'package:xterm3/xterm.dart';

void main() {
  test('CursorStyle reports italic through the correctly spelled getter', () {
    final style = CursorStyle();
    expect(style.isItalic, isFalse);

    style.setItalic();
    expect(style.isItalic, isTrue);

    style.unsetItalic();
    expect(style.isItalic, isFalse);
  });

  test('CursorStyle reports strikethrough', () {
    final style = CursorStyle();
    expect(style.isStrikethrough, isFalse);

    style.setStrikethrough();
    expect(style.isStrikethrough, isTrue);

    style.unsetStrikethrough();
    expect(style.isStrikethrough, isFalse);
  });
}
