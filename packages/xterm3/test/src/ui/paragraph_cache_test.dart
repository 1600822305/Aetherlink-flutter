import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm3/src/ui/paragraph_cache.dart';

void main() {
  test('ParagraphCache evicts the least recently used layout', () {
    final cache = ParagraphCache(2);
    const style = TextStyle();

    cache.performAndCacheLayout('a', style, TextScaler.noScaling, 1);
    cache.performAndCacheLayout('b', style, TextScaler.noScaling, 2);
    expect(cache.getLayoutFromCache(1), isNotNull);

    cache.performAndCacheLayout('c', style, TextScaler.noScaling, 3);

    expect(cache.length, 2);
    expect(cache.getLayoutFromCache(1), isNotNull);
    expect(cache.getLayoutFromCache(2), isNull);
    expect(cache.getLayoutFromCache(3), isNotNull);

    cache.dispose();
    expect(cache.length, 0);
  });

  test('ParagraphCache keeps recently read layouts across batch eviction', () {
    const size = 64;
    final cache = ParagraphCache(size);
    const style = TextStyle();

    for (var key = 0; key < size; key++) {
      cache.performAndCacheLayout('$key', style, TextScaler.noScaling, key);
    }

    // Read the oldest entries back so they become the most recently used ones
    // even though their position in the underlying map never changes.
    for (var key = 0; key < 8; key++) {
      expect(cache.getLayoutFromCache(key), isNotNull);
    }

    cache.performAndCacheLayout('overflow', style, TextScaler.noScaling, size);

    expect(cache.length, lessThanOrEqualTo(size));
    for (var key = 0; key < 8; key++) {
      expect(cache.getLayoutFromCache(key), isNotNull);
    }
    expect(cache.getLayoutFromCache(size), isNotNull);

    cache.dispose();
  });
}
