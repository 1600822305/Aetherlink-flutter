import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_export.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_import.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_st_export.dart';

/// 导出格式。
enum WorldBookExportFormat {
  /// 本应用 / kelivo / RikkaHub 兼容 JSON，可无损导回。
  native,

  /// SillyTavern 原生 World Info，可直接导入酒馆；部分字段会降级。
  sillyTavern,
}

/// 导入文件的读取结果：用户取消 / 无法解析 / 解析成功。
sealed class WorldBookPickOutcome {
  const WorldBookPickOutcome();
}

final class WorldBookPickCancelled extends WorldBookPickOutcome {
  const WorldBookPickCancelled();
}

final class WorldBookPickInvalid extends WorldBookPickOutcome {
  const WorldBookPickInvalid(this.message);

  final String message;
}

final class WorldBookPickParsed extends WorldBookPickOutcome {
  const WorldBookPickParsed(this.result);

  final WorldBookImportResult result;
}

/// 选取一个 JSON 文件并解析为世界书（不落库，交给 controller 的 importBook）。
/// 调用方式同 `regex_rules_tab.dart` 的酒馆正则导入。
Future<WorldBookPickOutcome> pickWorldBookFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['json'],
    withData: true,
  );
  final file = result?.files.singleOrNull;
  if (file == null) return const WorldBookPickCancelled();
  final bytes = file.bytes;
  if (bytes == null) return const WorldBookPickInvalid('无法读取文件');
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    return const WorldBookPickInvalid('不是有效的 JSON 文件');
  }
  final parsed = parseWorldBookImport(decoded, fileName: file.name);
  if (parsed == null) {
    return const WorldBookPickInvalid('无法识别的世界书格式');
  }
  return WorldBookPickParsed(parsed);
}

/// [exportWorldBookFile] 的结果：[saved] 为 false 表示用户取消；
/// [issues] 只在 SillyTavern 格式下可能非空（降级说明）。
class WorldBookExportOutcome {
  const WorldBookExportOutcome({required this.saved, this.issues = const {}});

  final bool saved;
  final Map<WorldBookStExportIssue, int> issues;
}

/// 通过系统保存对话框按 [format] 导出一本书。
/// 写法同 `message_export_service.dart` 的 `saveExportTextFile`。
Future<WorldBookExportOutcome> exportWorldBookFile(
  WorldBook book, {
  WorldBookExportFormat format = WorldBookExportFormat.native,
}) async {
  final st = format == WorldBookExportFormat.sillyTavern
      ? encodeWorldBookStExport(book)
      : null;
  final content = st?.json ?? encodeWorldBookExport(book);
  final baseName = worldBookExportFileName(book);
  final path = await FilePicker.saveFile(
    dialogTitle: st == null ? '导出世界书' : '导出为 SillyTavern 世界书',
    fileName: st == null ? baseName : worldBookStExportFileName(baseName),
    type: FileType.custom,
    allowedExtensions: const ['json'],
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
  if (path == null) return const WorldBookExportOutcome(saved: false);
  // 桌面端 FilePicker.saveFile 不会写入字节，需要手动写。
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(path).writeAsString(content);
  }
  return WorldBookExportOutcome(saved: true, issues: st?.issues ?? const {});
}
