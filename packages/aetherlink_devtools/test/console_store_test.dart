import 'package:aetherlink_devtools/aetherlink_devtools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConsoleStore', () {
    final store = ConsoleStore.instance;

    setUp(store.clear);

    test('appends entries with monotonic ids', () {
      store.add(level: LogLevel.info, message: 'a');
      store.add(level: LogLevel.warn, message: 'b');
      final ids = store.entries.value.map((e) => e.id).toList();
      expect(ids.length, 2);
      expect(ids[1], greaterThan(ids[0]));
    });

    test('rings: never exceeds maxEntries, drops oldest first', () {
      for (var i = 0; i < ConsoleStore.maxEntries + 50; i++) {
        store.add(level: LogLevel.debug, message: 'm$i');
      }
      final values = store.entries.value;
      expect(values.length, ConsoleStore.maxEntries);
      // oldest 50 dropped → first retained is m50
      expect(values.first.message, 'm50');
      expect(values.last.message, 'm${ConsoleStore.maxEntries + 49}');
    });

    test('filter by level', () {
      store.add(level: LogLevel.error, message: 'boom');
      store.add(level: LogLevel.debug, message: 'noise');
      store.setFilter(const ConsoleFilter(levels: {LogLevel.error}));
      final f = store.filtered;
      expect(f.length, 1);
      expect(f.single.message, 'boom');
    });

    test('filter by search over message and context', () {
      store.add(level: LogLevel.info, message: 'hello world');
      store.add(level: LogLevel.info, message: 'other', context: 'ChatController');
      store.setFilter(const ConsoleFilter(search: 'chat'));
      expect(store.filtered.single.message, 'other');

      store.setFilter(const ConsoleFilter(search: 'WORLD'));
      expect(store.filtered.single.message, 'hello world');
    });
  });

  test('LogEntry.toLine formats level + context + message', () {
    final e = LogEntry(
      id: 1,
      level: LogLevel.warn,
      message: 'msg',
      context: 'ctx',
      timestamp: DateTime(2026, 1, 1, 9, 8, 7, 6),
    );
    expect(e.toLine(), '[09:08:07.006] [WARN] [ctx] msg');
  });
}
