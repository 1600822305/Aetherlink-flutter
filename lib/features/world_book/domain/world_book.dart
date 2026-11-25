import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_legacy.dart';

part 'world_book.freezed.dart';

/// 一本世界书。JSON 就是 SillyTavern 原生 World Info 文件
/// （`{ "entries": { "<uid>": entry } }`），另在顶层多写本应用的
/// `id` / `name` / `description` / `enabled`——ST 读取时忽略这些键。
/// 所以导出文件可以直接导入酒馆，酒馆导出的文件也能原样读回。
///
/// [groupName] 是存储层元数据（独立列），**不**进 [toJson]。
/// 顶层不认识的键放进 [extra] 原样保留。
@freezed
abstract class WorldBook with _$WorldBook {
  const factory WorldBook({
    required String id,
    @Default('') String name,
    @Default('') String description,
    @Default(true) bool enabled,
    @Default(<WorldBookEntry>[]) List<WorldBookEntry> entries,
    String? groupName,
    @Default(<String, dynamic>{}) Map<String, dynamic> extra,
  }) = _WorldBook;

  const WorldBook._();

  int get enabledEntryCount => entries.where((entry) => entry.enabled).length;

  /// 顶层由本应用读写的键；备份记录附带的存储字段也在这里，免得被当成
  /// 未知键塞进 [extra]。
  static const Set<String> _reservedKeys = {
    'id',
    'name',
    'description',
    'enabled',
    'entries',
    'sortOrder',
    'groupName',
    'updatedAt',
  };

  /// 下一个可用的数字 uid（新建条目用）。
  String nextEntryId() {
    var max = -1;
    for (final e in entries) {
      final n = int.tryParse(e.id);
      if (n != null && n > max) max = n;
    }
    return '${max + 1}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    ...extra,
    'id': id,
    'name': name,
    'description': description,
    'enabled': enabled,
    'entries': <String, dynamic>{
      for (var i = 0; i < entries.length; i++)
        entries[i].id: entries[i].toJson(displayIndex: i),
    },
  };

  /// 读 ST 文件或本应用文件；`entries` 为数组时按 kelivo / RikkaHub 旧格式读。
  /// 条目按 `displayIndex`（缺省用 uid）排成编辑器顺序。从不抛异常。
  static WorldBook fromJson(Map<String, dynamic> json) {
    final raw = json['entries'];
    final entries = <WorldBookEntry>[];
    if (raw is List<dynamic>) {
      for (final e in raw) {
        // ST 的 entries 永远是对象；数组只出现在 kelivo / RikkaHub 旧格式里。
        if (e is Map<dynamic, dynamic>) {
          entries.add(worldBookEntryFromLegacyJson(e.cast<String, dynamic>()));
        }
      }
    } else if (raw is Map<dynamic, dynamic>) {
      final indexed = <({WorldBookEntry entry, num sort, int seq})>[];
      var seq = 0;
      for (final MapEntry(:key, :value) in raw.entries) {
        if (value is! Map<dynamic, dynamic>) continue;
        final map = value.cast<String, dynamic>();
        final entry = WorldBookEntry.fromJson(map, fallbackId: '$key');
        final display = map['displayIndex'];
        indexed.add((
          entry: entry,
          sort: display is num ? display : (int.tryParse(entry.id) ?? seq),
          seq: seq++,
        ));
      }
      indexed.sort((a, b) {
        final c = a.sort.compareTo(b.sort);
        return c != 0 ? c : a.seq.compareTo(b.seq);
      });
      entries.addAll(indexed.map((e) => e.entry));
    }
    String str(Object? v) => v is String ? v : '';
    final enabled = json['enabled'];
    return WorldBook(
      id: str(json['id']),
      name: str(json['name']),
      description: str(json['description']),
      enabled: enabled is bool ? enabled : true,
      entries: entries,
      extra: {
        for (final MapEntry(:key, :value) in json.entries)
          if (!_reservedKeys.contains(key)) key: value,
      },
    );
  }
}
