import 'dart:convert';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';

/// 把一本世界书编码为 SillyTavern 原生 World Info JSON（缩进两格）。
/// 顶层另带本应用的 `id` / `name` / `description` / `enabled`，酒馆会忽略。
/// 写出前把条目 uid 整理成不重复的数字，保证酒馆能读；[parseWorldBookImport]
/// 能无损读回。
String encodeWorldBookExport(WorldBook book) => const JsonEncoder.withIndent(
  '  ',
).convert(normalizeImportedWorldBook(book, existingBookIds: const {}).toJson());

/// 导出文件名：书名去掉文件系统非法字符，空名回退为 `world_book`。
String worldBookExportFileName(WorldBook book) {
  final sanitized = book.name.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return '${sanitized.isEmpty ? 'world_book' : sanitized}.json';
}
