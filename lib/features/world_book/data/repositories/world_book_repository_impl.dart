import 'package:aetherlink_flutter/features/world_book/data/datasources/local/world_book_dao.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_repository.dart';

/// Drift 实现：所有读写落到单库的 `world_book_rows`。
class WorldBookRepositoryImpl implements WorldBookRepository {
  const WorldBookRepositoryImpl(this._dao);

  final WorldBookDao _dao;

  @override
  Future<List<WorldBook>> getAll() => _dao.listBooks();

  @override
  Future<WorldBook?> getById(String id) => _dao.getBook(id);

  @override
  Future<void> save(WorldBook book) {
    if (book.id.trim().isEmpty) {
      throw ArgumentError.value(book.id, 'book.id', 'must not be empty');
    }
    return _dao.upsertBook(book);
  }

  @override
  Future<void> delete(String id) => _dao.deleteBook(id);

  @override
  Future<void> reorder(List<String> orderedIds) => _dao.reorder(orderedIds);

  @override
  Future<void> setGroup(String id, String? groupName) =>
      _dao.updateGroup(id, groupName);

  @override
  Future<int> renameGroup(String from, String to) =>
      _dao.renameGroup(from, to);

  @override
  Future<int> dissolveGroup(String name) => _dao.dissolveGroup(name);
}
