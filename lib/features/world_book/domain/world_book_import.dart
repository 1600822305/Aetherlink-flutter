import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';

class WorldBookImportResult {
  const WorldBookImportResult(this.book, {this.pendingEntryCount = 0});

  final WorldBook book;

  /// 用到了「已保存、但引擎暂未实现」的 ST 功能的条目数（见
  /// [worldBookPendingFeatures]）。这些条目**照常启用**，只是部分设置暂不生效。
  final int pendingEntryCount;
}

/// 读取世界书文件。支持：
/// - SillyTavern 原生 World Info（`entries` 为以 uid 为键的对象）——也就是
///   本应用自己的导出格式；
/// - 外面包一层 `{ "data": {...} }` 的文件（RikkaHub 等）；
/// - kelivo / RikkaHub 旧格式（`entries` 为数组）。
///
/// 所有字段原样读入、条目保持原来的开关状态，不再因为「不支持」而禁用。
/// 书名为空时用文件名。无法识别时返回 null。
WorldBookImportResult? parseWorldBookImport(
  Object? decoded, {
  required String fileName,
}) {
  if (decoded is! Map<dynamic, dynamic>) return null;
  var json = decoded.cast<String, dynamic>();
  if (json['entries'] == null && json['data'] is Map<dynamic, dynamic>) {
    json = (json['data'] as Map<dynamic, dynamic>).cast<String, dynamic>();
  }
  final entries = json['entries'];
  if (entries is! Map<dynamic, dynamic> && entries is! List<dynamic>) {
    return null;
  }
  final values = entries is Map<dynamic, dynamic> ? entries.values : entries as List<dynamic>;
  if (values.any((e) => e is! Map<dynamic, dynamic>)) return null;

  var book = WorldBook.fromJson(json);
  if (book.name.trim().isEmpty) {
    book = book.copyWith(
      name: fileName
          .replaceAll('\\', '/')
          .split('/')
          .last
          .replaceFirst(RegExp(r'\.json$', caseSensitive: false), ''),
    );
  }
  return WorldBookImportResult(
    book,
    pendingEntryCount: book.entries
        .where((e) => worldBookPendingFeatures(e).isNotEmpty)
        .length,
  );
}

/// 条目用到的、引擎**暂未实现**的 ST 功能（中文名）。随各阶段实现逐步缩短；
/// 为空表示这个条目的行为与 ST 一致。
Set<String> worldBookPendingFeatures(WorldBookEntry e) => {
  if (!e.position.isImplemented) '注入位置',
  // 本应用没有对应来源的匹配源（人设、角色备注、作者备注）永远为空。
  if (e.matchPersonaDescription ||
      e.matchCharacterDepthPrompt ||
      e.matchCreatorNotes)
    '额外匹配源（人设 / 角色备注 / 作者备注）',
  // 本应用不会产生这两种生成类型，只限定它们的条目永远不会激活。
  if (e.triggers.isNotEmpty &&
      e.triggers.every((t) => t == 'impersonate' || t == 'quiet'))
    '生成类型（代写 / 后台生成）',
  if (e.vectorized) '向量匹配',
  if (e.automationId.trim().isNotEmpty) '自动化',
};

/// 导入前整理：书 id 为空或与已有书冲突时重新生成；条目 uid 统一成不重复的
/// 数字（已是数字且不重复的保持不变，其余按顺序分配新号）；标题（ST `comment`）
/// 为空的条目把 [WorldBookEntry.displayTitle] 真正写进标题，这样列表、编辑页、
/// 导出看到的是同一个名字（导回酒馆时标题栏也有内容）。
WorldBook normalizeImportedWorldBook(
  WorldBook book, {
  required Set<String> existingBookIds,
}) {
  var bookId = book.id.trim();
  if (bookId.isEmpty || existingBookIds.contains(bookId)) {
    bookId = generateId('wb');
  }
  final used = <int>{};
  final keep = <bool>[];
  for (final e in book.entries) {
    final n = int.tryParse(e.id.trim());
    final ok = n != null && n >= 0 && '$n' == e.id.trim() && used.add(n);
    keep.add(ok);
  }
  var next = used.isEmpty ? 0 : used.reduce((a, b) => a > b ? a : b) + 1;
  final entries = <WorldBookEntry>[
    for (var i = 0; i < book.entries.length; i++)
      _withTitle(
        keep[i] ? book.entries[i] : book.entries[i].copyWith(id: '${next++}'),
      ),
  ];
  return book.copyWith(id: bookId, entries: entries);
}

WorldBookEntry _withTitle(WorldBookEntry e) =>
    e.hasInferredTitle ? e.copyWith(name: e.displayTitle) : e;
