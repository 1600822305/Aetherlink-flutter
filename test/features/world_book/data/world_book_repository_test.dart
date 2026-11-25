import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/world_book/data/repositories/world_book_repository_impl.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

void main() {
  late AppDatabase db;
  late WorldBookRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorldBookRepositoryImpl(db.worldBookDao);
  });

  tearDown(() async {
    await db.close();
  });

  const entry = WorldBookEntry(
    id: 'e1',
    name: 'Dragon',
    content: 'A dragon lives here.',
    keywords: ['dragon'],
    position: WorldBookInjectionPosition.atDepth,
    injectDepth: 2,
    role: WorldBookInjectionRole.assistant,
    sticky: 3,
  );

  test('the world_book_rows table exists on a fresh DB', () async {
    final rows = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1",
          variables: [Variable<String>('world_book_rows')],
        )
        .get();
    expect(rows, hasLength(1));
  });

  test('save then read round-trips the whole book including entries', () async {
    const book = WorldBook(
      id: 'b1',
      name: 'Lore',
      description: 'desc',
      entries: [entry],
    );
    await repo.save(book);
    expect(await repo.getById('b1'), book);
    expect(await repo.getAll(), [book]);
    expect(await repo.getById('missing'), isNull);
  });

  test('new books append; overwriting keeps the sort position', () async {
    await repo.save(const WorldBook(id: 'a', name: 'A'));
    await repo.save(const WorldBook(id: 'b', name: 'B'));
    await repo.save(const WorldBook(id: 'c', name: 'C'));
    await repo.save(const WorldBook(id: 'a', name: 'A2', entries: [entry]));
    final books = await repo.getAll();
    expect(books.map((b) => b.id), ['a', 'b', 'c']);
    expect(books.first.name, 'A2');
    expect(books.first.entries.single, entry);
  });

  test('reorder rewrites the persisted order', () async {
    for (final id in ['a', 'b', 'c']) {
      await repo.save(WorldBook(id: id));
    }
    await repo.reorder(['c', 'a', 'b']);
    expect((await repo.getAll()).map((b) => b.id), ['c', 'a', 'b']);
  });

  test('delete removes only the target book', () async {
    await repo.save(const WorldBook(id: 'a'));
    await repo.save(const WorldBook(id: 'b'));
    await repo.delete('a');
    expect((await repo.getAll()).map((b) => b.id), ['b']);
  });

  test('group column: set, rename, dissolve, blank means ungrouped', () async {
    await repo.save(const WorldBook(id: 'a', groupName: 'g1'));
    await repo.save(const WorldBook(id: 'b'));
    await repo.save(const WorldBook(id: 'c', groupName: '  '));
    expect((await repo.getById('a'))!.groupName, 'g1');
    expect((await repo.getById('c'))!.groupName, isNull);

    await repo.setGroup('b', 'g1');
    expect(await repo.renameGroup('g1', 'g2'), 2);
    expect((await repo.getById('a'))!.groupName, 'g2');
    expect((await repo.getById('b'))!.groupName, 'g2');

    expect(await repo.dissolveGroup('g2'), 2);
    expect((await repo.getAll()).every((b) => b.groupName == null), isTrue);
  });

  test('saving a book keeps the group passed on the entity', () async {
    await repo.save(const WorldBook(id: 'a', groupName: 'g'));
    final loaded = (await repo.getById('a'))!;
    await repo.save(loaded.copyWith(name: 'renamed'));
    expect((await repo.getById('a'))!.groupName, 'g');
  });

  test('saving a book with an empty id is rejected', () async {
    expect(() => repo.save(const WorldBook(id: '')), throwsArgumentError);
  });
}
