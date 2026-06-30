import 'package:aetherlink_devtools/aetherlink_devtools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('createLogger / DevLogger', () {
    final store = ConsoleStore.instance;
    setUp(store.clear);

    test('feeds ConsoleStore with level + context', () {
      final log = createLogger('Demo');
      log.info('hello');
      log.warn('careful');
      final entries = store.entries.value;
      expect(entries.length, 2);
      expect(entries[0].level, LogLevel.info);
      expect(entries[0].context, 'Demo');
      expect(entries[0].message, 'hello');
      expect(entries[1].level, LogLevel.warn);
    });

    test('error attaches error text + stack trace', () {
      final log = createLogger('Net');
      log.error('request failed', error: 'timeout', stackTrace: StackTrace.current);
      final e = store.entries.value.single;
      expect(e.level, LogLevel.error);
      expect(e.context, 'Net');
      expect(e.message, 'request failed: timeout');
      expect(e.stackTrace, isNotNull);
    });

    test('context becomes a filterable group key', () {
      createLogger('A').info('a1');
      createLogger('B').info('b1');
      createLogger('A').info('a2');
      store.setFilter(const ConsoleFilter(search: 'A'));
      // search matches context 'A' (and not 'B')
      final ctxs = store.filtered.map((e) => e.context).toSet();
      expect(ctxs, {'A'});
    });
  });
}
