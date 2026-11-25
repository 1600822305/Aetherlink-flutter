import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';

part 'world_books_controller.g.dart';

/// 世界书列表的状态与编辑操作（kelivo `WorldBookProvider` 的 Riverpod 版）。
///
/// 每次修改先写仓库再 [ref.invalidateSelf] 重新加载，与 `KnowledgeBasesController`
/// 一致；整本书一行存储，条目增删改都是「读出整本 → 改 → 整本写回」，天然原子。
@Riverpod(keepAlive: true)
class WorldBooksController extends _$WorldBooksController {
  @override
  Future<List<WorldBook>> build() =>
      ref.watch(worldBookRepositoryProvider).getAll();

  Future<WorldBook> createBook(
    String name, {
    String description = '',
    String? groupName,
  }) async {
    final book = WorldBook(
      id: generateId('wb'),
      name: name.trim(),
      description: description.trim(),
      groupName: groupName,
    );
    await _save(book);
    return book;
  }

  /// 导入一份已解析的 JSON（SillyTavern / 本应用 / kelivo / RikkaHub），返回
  /// 导入结果；书 id 冲突时重新生成，条目 uid 整理成不重复的数字。
  Future<WorldBookImportResult> importBook(WorldBookImportResult parsed) async {
    final existing = await future;
    final normalized = normalizeImportedWorldBook(
      parsed.book,
      existingBookIds: {for (final b in existing) b.id},
    );
    await _save(normalized);
    return WorldBookImportResult(
      normalized,
      pendingEntryCount: parsed.pendingEntryCount,
    );
  }

  Future<void> updateBook(
    String id,
    WorldBook Function(WorldBook current) change,
  ) async {
    final current = await ref.read(worldBookRepositoryProvider).getById(id);
    if (current == null) return;
    await _save(change(current));
  }

  Future<void> renameBook(String id, String name, String description) =>
      updateBook(
        id,
        (b) => b.copyWith(name: name.trim(), description: description.trim()),
      );

  Future<void> setBookEnabled(String id, bool enabled) =>
      updateBook(id, (b) => b.copyWith(enabled: enabled));

  Future<void> deleteBook(String id) async {
    await ref.read(worldBookRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }

  /// 把书在完整列表里上移（[delta] = -1）或下移（+1）一位。
  Future<void> moveBook(String id, int delta) async {
    final books = await future;
    final ids = [for (final b in books) b.id];
    final from = ids.indexOf(id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= ids.length) return;
    ids.insert(to, ids.removeAt(from));
    await ref.read(worldBookRepositoryProvider).reorder(ids);
    ref.invalidateSelf();
    await future;
  }

  Future<void> setBookGroup(String id, String? groupName) async {
    await ref.read(worldBookRepositoryProvider).setGroup(id, groupName);
    ref.invalidateSelf();
    await future;
  }

  Future<void> renameGroup(String from, String to) async {
    await ref.read(worldBookRepositoryProvider).renameGroup(from, to);
    ref.invalidateSelf();
    await future;
  }

  Future<void> dissolveGroup(String name) async {
    await ref.read(worldBookRepositoryProvider).dissolveGroup(name);
    ref.invalidateSelf();
    await future;
  }

  /// 新增或覆盖一个条目（按 id 匹配；id 为空时分配下一个数字 uid 并追加到
  /// 末尾，与 ST 一致）。
  Future<void> saveEntry(String bookId, WorldBookEntry entry) =>
      updateBook(bookId, (book) {
        if (entry.id.isEmpty) {
          return book.copyWith(
            entries: [...book.entries, entry.copyWith(id: book.nextEntryId())],
          );
        }
        final exists = book.entries.any((e) => e.id == entry.id);
        return book.copyWith(
          entries: exists
              ? [for (final e in book.entries) e.id == entry.id ? entry : e]
              : [...book.entries, entry],
        );
      });

  Future<void> setEntryEnabled(String bookId, String entryId, bool enabled) =>
      updateBook(
        bookId,
        (book) => book.copyWith(
          entries: [
            for (final e in book.entries)
              e.id == entryId ? e.copyWith(enabled: enabled) : e,
          ],
        ),
      );

  Future<void> deleteEntry(String bookId, String entryId) => updateBook(
    bookId,
    (book) => book.copyWith(
      entries: book.entries.where((e) => e.id != entryId).toList(),
    ),
  );

  /// 条目上移 / 下移一位：只改编辑器里的显示顺序（ST `displayIndex`）；
  /// 注入顺序由条目的 `order` 决定。
  Future<void> moveEntry(String bookId, String entryId, int delta) =>
      updateBook(bookId, (book) {
        final entries = [...book.entries];
        final from = entries.indexWhere((e) => e.id == entryId);
        final to = from + delta;
        if (from < 0 || to < 0 || to >= entries.length) return book;
        entries.insert(to, entries.removeAt(from));
        return book.copyWith(entries: entries);
      });

  Future<void> _save(WorldBook book) async {
    await ref.read(worldBookRepositoryProvider).save(book);
    ref.invalidateSelf();
    await future;
  }
}

/// 单本书（详情页用）；列表刷新时自动跟随。
@riverpod
Future<WorldBook?> worldBookById(Ref ref, String id) async {
  final books = await ref.watch(worldBooksControllerProvider.future);
  for (final book in books) {
    if (book.id == id) return book;
  }
  return null;
}
