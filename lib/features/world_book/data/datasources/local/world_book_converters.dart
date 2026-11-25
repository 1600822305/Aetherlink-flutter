import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';

/// 把整本 [WorldBook]（含条目）存为单列 JSON blob，做法同 `AssistantConverter`。
/// [WorldBook.groupName] 不在 blob 内，由独立列回填。
class WorldBookConverter extends TypeConverter<WorldBook, String> {
  const WorldBookConverter();

  @override
  WorldBook fromSql(String fromDb) {
    final decoded = jsonDecode(fromDb);
    if (decoded is! Map<dynamic, dynamic>) return const WorldBook(id: '');
    return WorldBook.fromJson(decoded.cast<String, dynamic>());
  }

  @override
  String toSql(WorldBook value) => jsonEncode(value.toJson());
}
