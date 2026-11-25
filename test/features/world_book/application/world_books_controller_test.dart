import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/features/world_book/application/world_books_controller.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_repository.dart';

/// In-memory [WorldBookRepository] so the controller is tested without Drift.
class _MemoryRepository implements WorldBookRepository {
  final List<WorldBook> books = [];

  @override
  Future<List<WorldBook>> getAll() async => List.of(books);

  @override
  Future<WorldBook?> getById(String id) async {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<void> save(WorldBook book) async {
    final index = books.indexWhere((b) => b.id == book.id);
    if (index < 0) {
      books.add(book);
    } else {
      books[index] = book;
    }
  }

  @override
  Future<void> delete(String id) async => books.removeWhere((b) => b.id == id);

  @override
  Future<void> reorder(List<String> orderedIds) async =>
      books.sort((a, b) => orderedIds.indexOf(a.id) - orderedIds.indexOf(b.id));

  @override
  Future<void> setGroup(String id, String? groupName) async {
    final book = (await getById(id))!;
    await save(book.copyWith(groupName: groupName));
  }

  @override
  Future<int> renameGroup(String from, String to) async => 0;

  @override
  Future<int> dissolveGroup(String name) async => 0;
}

void main() {
  late _MemoryRepository repo;
  late ProviderContainer container;

  WorldBooksController controller() =>
      container.read(worldBooksControllerProvider.notifier);

  setUp(() {
    repo = _MemoryRepository();
    container = ProviderContainer(
      overrides: [worldBookRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  test('createBook persists a trimmed book with a fresh id', () async {
    await container.read(worldBooksControllerProvider.future);
    final book = await controller().createBook('  Lore  ');
    expect(book.id, isNotEmpty);
    expect(repo.books.single.name, 'Lore');
    expect(await container.read(worldBooksControllerProvider.future), [book]);
  });

  test('saveEntry appends new entries and replaces existing ones', () async {
    await container.read(worldBooksControllerProvider.future);
    final book = await controller().createBook('B');
    await controller().saveEntry(
      book.id,
      const WorldBookEntry(id: '', content: 'one'),
    );
    final added = repo.books.single.entries.single;
    // 新条目分配数字 uid（与 SillyTavern 一致）。
    expect(added.id, '0');
    await controller().saveEntry(book.id, const WorldBookEntry(id: ''));
    expect(repo.books.single.entries.map((e) => e.id), ['0', '1']);
    await controller().deleteEntry(book.id, '1');
    await controller().saveEntry(book.id, added.copyWith(content: 'two'));
    expect(repo.books.single.entries.single.content, 'two');
  });

  test('moveEntry and moveBook stay within bounds', () async {
    await container.read(worldBooksControllerProvider.future);
    final a = await controller().createBook('A');
    final b = await controller().createBook('B');
    for (final id in ['x', 'y']) {
      await controller().saveEntry(a.id, WorldBookEntry(id: id));
    }
    await controller().moveEntry(a.id, 'y', -1);
    expect(repo.books.first.entries.map((e) => e.id), ['y', 'x']);
    await controller().moveEntry(a.id, 'y', -1);
    expect(repo.books.first.entries.map((e) => e.id), ['y', 'x']);

    await controller().moveBook(b.id, -1);
    expect(repo.books.map((e) => e.id), [b.id, a.id]);
    await controller().moveBook(b.id, -1);
    expect(repo.books.map((e) => e.id), [b.id, a.id]);
  });

  test('reorderEntry moves by drag indices and ignores bad ones', () async {
    await container.read(worldBooksControllerProvider.future);
    final a = await controller().createBook('A');
    for (final id in ['x', 'y', 'z']) {
      await controller().saveEntry(a.id, WorldBookEntry(id: id));
    }
    await controller().reorderEntry(a.id, 0, 2);
    expect(repo.books.single.entries.map((e) => e.id), ['y', 'z', 'x']);
    await controller().reorderEntry(a.id, 2, 0);
    expect(repo.books.single.entries.map((e) => e.id), ['x', 'y', 'z']);
    await controller().reorderEntry(a.id, 0, 9);
    expect(repo.books.single.entries.map((e) => e.id), ['x', 'y', 'z']);
  });

  test('reorderBooks reorders one group in place, others untouched', () async {
    await container.read(worldBooksControllerProvider.future);
    // 完整顺序 a(组1) b(未分组) c(组1) d(未分组)；只在组 1 内拖动 c 到 a 前面。
    final a = await controller().createBook('a');
    final b = await controller().createBook('b');
    final c = await controller().createBook('c');
    final d = await controller().createBook('d');
    await controller().reorderBooks([c.id, a.id]);
    expect(repo.books.map((e) => e.id), [c.id, b.id, a.id, d.id]);
    // 传入的 id 不全在列表里时不动。
    await controller().reorderBooks([a.id, 'missing']);
    expect(repo.books.map((e) => e.id), [c.id, b.id, a.id, d.id]);
  });

  test('importBook regenerates a colliding id and keeps the count', () async {
    await repo.save(const WorldBook(id: 'dup'));
    await container.read(worldBooksControllerProvider.future);
    final saved = await controller().importBook(
      const WorldBookImportResult(
        WorldBook(id: 'dup', name: 'Imported'),
        pendingEntryCount: 2,
      ),
    );
    expect(saved.book.id, isNot('dup'));
    expect(saved.pendingEntryCount, 2);
    expect(repo.books, hasLength(2));
  });

  test('setEntryEnabled and deleteEntry edit only the target entry', () async {
    await container.read(worldBooksControllerProvider.future);
    final book = await controller().createBook('B');
    await controller().saveEntry(book.id, const WorldBookEntry(id: 'a'));
    await controller().saveEntry(book.id, const WorldBookEntry(id: 'b'));
    await controller().setEntryEnabled(book.id, 'a', false);
    expect(repo.books.single.entries.map((e) => e.enabled), [false, true]);
    await controller().deleteEntry(book.id, 'a');
    expect(repo.books.single.entries.map((e) => e.id), ['b']);
  });
}
