import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';

/// 世界书的持久化契约（实现见 data 层 `WorldBookRepositoryImpl`）。
///
/// 返回顺序即用户排序（同时也是注入时的书序）。[WorldBook.groupName] 由实现从
/// 独立列回填。
abstract interface class WorldBookRepository {
  Future<List<WorldBook>> getAll();

  Future<WorldBook?> getById(String id);

  /// 新增或整本覆盖（含条目）。已存在的书保持原排序位，新书排到末尾。
  Future<void> save(WorldBook book);

  Future<void> delete(String id);

  /// 按 [orderedIds] 的顺序重写排序位；不在列表里的书保持原值。
  Future<void> reorder(List<String> orderedIds);

  /// 设置所属分组；null / 空白表示移出分组。
  Future<void> setGroup(String id, String? groupName);

  /// 重命名分组，返回受影响的书数。
  Future<int> renameGroup(String from, String to);

  /// 解散分组（书本身保留），返回受影响的书数。
  Future<int> dissolveGroup(String name);
}
