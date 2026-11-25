import 'dart:convert';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';

/// 把一本世界书编码为 kelivo / RikkaHub 兼容的 JSON（缩进两格，便于人工审阅）。
/// [parseWorldBookImport] 能无损读回。
String encodeWorldBookExport(WorldBook book) =>
    const JsonEncoder.withIndent('  ').convert(book.toJson());

/// 导出文件名：书名去掉文件系统非法字符，空名回退为 `world_book`。
String worldBookExportFileName(WorldBook book) {
  final sanitized = book.name.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  return '${sanitized.isEmpty ? 'world_book' : sanitized}.json';
}
