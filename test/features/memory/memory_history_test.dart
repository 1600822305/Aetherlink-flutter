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
}
