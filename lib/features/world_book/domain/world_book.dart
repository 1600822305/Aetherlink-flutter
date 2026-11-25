import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

part 'world_book.freezed.dart';

/// 一本世界书：一组按顺序排列的 [entries]。
///
/// [groupName] 是存储层元数据（轻量字符串分组，同名即同组，做法同知识库分组），
/// 由仓库从独立列回填；它**不**进入 [toJson]，所以导出文件与 kelivo / RikkaHub
/// 格式保持一致。
@freezed
abstract class WorldBook with _$WorldBook {
  const factory WorldBook({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default(true) bool enabled,
    @Default(<WorldBookEntry>[]) List<WorldBookEntry> entries,
    String? groupName,
  }) = _WorldBook;

  const WorldBook._();

  int get enabledEntryCount => entries.where((entry) => entry.enabled).length;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'description': description,
    'enabled': enabled,
    'entries': entries.map((e) => e.toJson()).toList(growable: false),
  };

  static WorldBook fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = rawEntries is List<dynamic>
        ? rawEntries
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => WorldBookEntry.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false)
        : const <WorldBookEntry>[];
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    final enabled = json['enabled'];
    return WorldBook(
      id: id is String ? id : '',
      name: name is String ? name : '',
      description: description is String ? description : '',
      enabled: enabled is bool ? enabled : true,
      entries: entries,
    );
  }
}
