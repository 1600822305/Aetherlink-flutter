import 'package:aetherlink_devtools/aetherlink_devtools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NetworkStore', () {
    final store = NetworkStore.instance;

    setUp(store.clear);

    test('start → completeResponse: success for 2xx, error otherwise', () {
      final ok = store.start(method: 'get', url: 'https://x/ok');
      store.completeResponse(ok, statusCode: 200, body: 'hi');
      final bad = store.start(method: 'POST', url: 'https://x/bad');
      store.completeResponse(bad, statusCode: 500, body: 'no');

      final a = store.byId(ok)!;
      expect(a.method, 'GET'); // uppercased
      expect(a.status, NetworkStatus.success);
      expect(a.responseSize, 2);
      final b = store.byId(bad)!;
      expect(b.status, NetworkStatus.error);
    });

    test('streaming: appends chunks then seals to final status', () {
      final id = store.start(method: 'POST', url: 'https://x/chat/completions');
      store.beginStream(id, statusCode: 200);
      store.appendStream(id, [1, 2, 3], 'da');
      store.appendStream(id, [4, 5], 'ta');
      final mid = store.byId(id)!;
      expect(mid.isStream, true);
      expect(mid.status, NetworkStatus.pending);
      expect(mid.responseData, 'data');
      expect(mid.responseSize, 5);
      store.endStream(id);
      expect(store.byId(id)!.status, NetworkStatus.success);
    });

    test('markCancelled only affects pending entries', () {
      final id = store.start(method: 'GET', url: 'https://x/slow');
      store.markCancelled(id);
      expect(store.byId(id)!.status, NetworkStatus.cancelled);

      final done = store.start(method: 'GET', url: 'https://x/done');
      store.completeResponse(done, statusCode: 200);
      store.markCancelled(done); // no-op: already finalised
      expect(store.byId(done)!.status, NetworkStatus.success);
    });

    test('rings: never exceeds maxEntries, drops oldest first', () {
      for (var i = 0; i < NetworkStore.maxEntries + 10; i++) {
        store.start(method: 'GET', url: 'https://x/$i');
      }
      final values = store.entries.value;
      expect(values.length, NetworkStore.maxEntries);
      expect(values.first.url, 'https://x/10');
    });

    test('filtered: newest first, honours method/error/search filters', () {
      final a = store.start(method: 'GET', url: 'https://a.com/one');
      store.completeResponse(a, statusCode: 200);
      final b = store.start(method: 'POST', url: 'https://b.com/two');
      store.completeResponse(b, statusCode: 404);

      // Newest first.
      expect(store.filtered.first.url, 'https://b.com/two');

      store.setFilter(const NetworkFilter(methods: {'GET'}));
      expect(store.filtered.single.url, 'https://a.com/one');

      store.setFilter(const NetworkFilter(onlyErrors: true));
      expect(store.filtered.single.url, 'https://b.com/two');

      store.setFilter(const NetworkFilter(search: 'a.com'));
      expect(store.filtered.single.url, 'https://a.com/one');
    });
  });

  test('formatSize / formatDuration mirror the web helpers', () {
    expect(formatSize(0), '0 B');
    expect(formatSize(512), '512 B');
    expect(formatSize(2048), '2.0 KB');
    expect(formatDuration(const Duration(milliseconds: 820)), '820ms');
    expect(formatDuration(const Duration(milliseconds: 1200)), '1.20s');
  });
}
