import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/procedural_glyph_cache.dart';

Picture _dummyPicture() {
  final recorder = PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint(),
  );
  return recorder.endRecording();
}

void main() {
  test('insert disposes the old Picture when overwriting an existing key', () {
    final cache = ProceduralGlyphCache(4);
    final first = _dummyPicture();

    cache.insert('key', first);
    cache.insert('key', _dummyPicture());

    expect(cache.length, 1, reason: 'no duplicate node left behind');
    // If insert() failed to dispose the overwritten Picture, disposing it
    // here a second time would throw in debug mode.
    expect(first.dispose, throwsA(anything));

    cache.dispose();
  });
}
