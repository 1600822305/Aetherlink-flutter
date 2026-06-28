import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/memory/data/chat_memory_store.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_history.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

void main() {
  late AppDatabase db;
  late ChatMemoryStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = ChatMemoryStore(db.memoryDao);
  });

  tearDown(() async {
    await db.close();
  });

  test('create records an ADD entry with the new content', () async {
    final created = await store.create(
      const MemoryItem(id: '', content: 'likes tea'),
    );

    final history = await store.history(created.id);
    expect(history, hasLength(1));
    expect(history.single.action, MemoryAction.add);
    expect(history.single.previousValue, isNull);
    expect(history.single.newValue, 'likes tea');
  });

  test('update records an UPDATE entry capturing before/after content', () async {
    final created = await store.create(
      const MemoryItem(id: '', content: 'likes tea'),
    );
    await store.update(created.copyWith(content: 'likes coffee'));

    final history = await store.history(created.id);
    // Newest first: UPDATE then ADD.
    expect(history.map((e) => e.action), [
      MemoryAction.update,
      MemoryAction.add,
    ]);
    expect(history.first.previousValue, 'likes tea');
    expect(history.first.newValue, 'likes coffee');
  });

  test('delete records a DELETE entry with the prior content', () async {
    final created = await store.create(
      const MemoryItem(id: '', content: 'likes tea'),
    );
    await store.delete(created.id);

    final history = await store.history(created.id);
    expect(history.first.action, MemoryAction.delete);
    expect(history.first.previousValue, 'likes tea');
    expect(history.first.newValue, isNull);
  });

  test('history survives a soft delete (audit outlives the memory)', () async {
    final created = await store.create(
      const MemoryItem(id: '', content: 'likes tea'),
    );
    await store.delete(created.id);

    // The soft-deleted row itself is still present...
    final live = await db.memoryDao.getById(created.id);
    expect(live?.content, 'likes tea');
    // ...and its full ADD→DELETE trail remains.
    final history = await store.history(created.id);
    expect(history, hasLength(2));
    expect(history.map((e) => e.action), [
      MemoryAction.delete,
      MemoryAction.add,
    ]);
  });

  test('recentHistory spans memories newest first', () async {
    final a = await store.create(const MemoryItem(id: '', content: 'a'));
    final b = await store.create(const MemoryItem(id: '', content: 'b'));

    final recent = await db.memoryDao.recentHistory();
    expect(recent.length, greaterThanOrEqualTo(2));
    // b was created after a, so its entry comes first.
    expect(recent.first.memoryId, b.id);
    expect(recent.map((e) => e.memoryId), contains(a.id));
  });

  group('purge', () {
    test('keeps live memories and those deleted within the window', () async {
      final live = await store.create(const MemoryItem(id: '', content: 'live'));
      final recent = await store.create(
        const MemoryItem(id: '', content: 'recent'),
      );
      await store.delete(recent.id);

      final purged = await store.purge(retentionDays: 30);

      expect(purged, 0);
      expect((await db.memoryDao.getById(live.id))?.content, 'live');
      expect((await db.memoryDao.getById(recent.id))?.content, 'recent');
    });

    test('removes memories deleted past retention, with their history',
        () async {
      final old = await store.create(const MemoryItem(id: '', content: 'old'));
      await store.delete(old.id);
      // Backdate the DELETE audit time to 40 days ago.
      final fortyDaysAgo =
          DateTime.now().millisecondsSinceEpoch - 40 * 86400000;
      await db.customStatement(
        'UPDATE memory_history_rows SET created_at = ? '
        'WHERE memory_id = ? AND action = ?',
        [fortyDaysAgo, old.id, 'DELETE'],
      );

      final purged = await store.purge(retentionDays: 30);

      expect(purged, 1);
      expect(await db.memoryDao.getById(old.id), isNull);
      expect(await store.history(old.id), isEmpty);
    });

    test('retentionDays 0 purges any soft-deleted memory immediately',
        () async {
      final gone = await store.create(const MemoryItem(id: '', content: 'x'));
      await store.delete(gone.id);

      final purged = await store.purge(retentionDays: 0);

      expect(purged, 1);
      expect(await db.memoryDao.getById(gone.id), isNull);
    });
  });
}
