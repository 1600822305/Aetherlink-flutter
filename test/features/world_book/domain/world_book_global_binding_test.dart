import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_binding.dart';

void main() {
  WorldBookBinding resolve({
    List<String> assistant = const [],
    List<String>? topic,
    List<String> global = const [],
  }) => resolveWorldBookBinding(
    assistantBookIds: assistant,
    topicBookIds: topic,
    globalBookIds: global,
  );

  group('priority: topic override > assistant binding > global default', () {
    test('topic override wins over assistant and global', () {
      final b = resolve(assistant: ['a'], topic: ['t'], global: ['g']);
      expect(b.source, WorldBookBindingSource.topicOverride);
      expect(b.ids, ['t']);
    });

    test('topic [] disables even when assistant and global bind books', () {
      final b = resolve(assistant: ['a'], topic: const [], global: ['g']);
      expect(b.source, WorldBookBindingSource.topicDisabled);
      expect(b.ids, isEmpty);
    });

    test('topic null + assistant books → assistant, global ignored', () {
      final b = resolve(assistant: ['a'], global: ['g']);
      expect(b.source, WorldBookBindingSource.assistant);
      expect(b.ids, ['a']);
    });

    test('assistant empty list falls through to the global default', () {
      final b = resolve(global: ['g1', 'g2']);
      expect(b.source, WorldBookBindingSource.globalDefault);
      expect(b.ids, ['g1', 'g2']);
    });

    test('nothing bound anywhere → assistant source with no ids', () {
      final b = resolve();
      expect(b.source, WorldBookBindingSource.assistant);
      expect(b.ids, isEmpty);
    });

    test('defaulted global parameter keeps the P2 two-level behaviour', () {
      final b = resolveWorldBookBinding(
        assistantBookIds: const [],
        topicBookIds: null,
      );
      expect(b.ids, isEmpty);
    });
  });

  test('dangling ids (deleted / not restored books) are ignored', () {
    const books = [WorldBook(id: 'kept')];
    for (final binding in [
      resolve(assistant: ['gone', 'kept']),
      resolve(topic: ['gone']),
      resolve(global: ['gone', 'kept', 'also-gone']),
    ]) {
      final active = activeWorldBooks(binding, books);
      expect(active.every((b) => b.id == 'kept'), isTrue);
    }
    expect(activeWorldBooks(resolve(topic: ['gone']), books), isEmpty);
  });

  group('global default storage codec', () {
    test('round-trips and drops blanks / non-strings', () {
      expect(
        decodeWorldBookGlobalDefault(encodeWorldBookGlobalDefault(['a', 'b'])),
        ['a', 'b'],
      );
      expect(decodeWorldBookGlobalDefault('["a", " ", 3, "b "]'), ['a', 'b']);
    });

    test('missing or malformed values read as no global default', () {
      for (final raw in [null, '', 'x', '{"a":1}', '42']) {
        expect(decodeWorldBookGlobalDefault(raw), isEmpty);
      }
    });

    test('uses the documented settings key', () {
      expect(kWorldBookGlobalDefaultKey, 'world_book.global_default_ids');
    });
  });
}
