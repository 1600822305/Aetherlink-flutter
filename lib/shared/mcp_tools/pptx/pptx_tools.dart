// `@aether/pptx` built-in MCP server — local execution entry point.
//
// Turns a structured deck.json source (the intermediate representation the
// model produces) into a native, fully-editable .pptx written into the user's
// workspace, plus an optional self-contained HTML preview. Generation is pure
// Dart (packages/aetherlink_pptx) and runs inside an isolate; deterministic
// layout QA gates delivery so the model can self-correct before exporting.

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_write_handlers.dart';

/// The built-in MCP server name this router serves.
const String kPptxServerName = '@aether/pptx';

/// Runs a `@aether/pptx` [toolName] with [args], using [ref] to reach the
/// workspace providers. Returns an error [McpToolResult] for unknown tools or
/// failures (never throws).
Future<McpToolResult> runPptxTool(
  Ref ref,
  String toolName,
  Map<String, Object?> args,
) async {
  try {
    switch (toolName) {
      case 'pptx_check':
        return _check(args);
      case 'pptx_render':
        return await _render(ref, args);
    }
    return fileEditorError('未知的工具: $toolName');
  } on DeckParseException catch (e) {
    return fileEditorError('deck 源无效：${e.message}');
  } on FileEditorError catch (e) {
    return fileEditorError(e.message);
  } catch (e) {
    return fileEditorError('PPT 工具执行失败: $e');
  }
}

DeckDocument _parseDeckArg(Map<String, Object?> args) {
  final raw = args['deck'];
  if (raw is Map) {
    return DeckDocument.fromJson(raw.cast<String, Object?>());
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return DeckDocument.parse(raw);
  }
  throw const FileEditorError('缺少必需参数: deck（deck.json 对象或其 JSON 字符串）');
}

Map<String, Object?> _qaSummary(List<DeckQaIssue> issues) => {
  'errors': issues
      .where((i) => i.severity == DeckQaSeverity.error)
      .map((i) => i.toJson())
      .toList(),
  'warnings': issues
      .where((i) => i.severity == DeckQaSeverity.warning)
      .map((i) => i.toJson())
      .toList(),
};

McpToolResult _check(Map<String, Object?> args) {
  final deck = _parseDeckArg(args);
  final issues = runDeckQa(deck);
  return fileEditorOk({
    'valid': true,
    'slides': deck.slides.length,
    'qa': _qaSummary(issues),
    'message': issues.any((i) => i.severity == DeckQaSeverity.error)
        ? 'deck 结构合法，但有布局错误需要修正后再导出'
        : 'deck 通过校验，可以调用 pptx_render 导出',
  });
}

Future<McpToolResult> _render(Ref ref, Map<String, Object?> args) async {
  final deck = _parseDeckArg(args);
  final path = requireString(args, 'path');
  if (!path.toLowerCase().endsWith('.pptx')) {
    throw const FileEditorError('path 必须以 .pptx 结尾');
  }
  final force = optionalBool(args, 'force');
  final withPreview = optionalBool(args, 'preview');

  final issues = runDeckQa(deck);
  final hasErrors = issues.any((i) => i.severity == DeckQaSeverity.error);
  if (hasErrors && !force) {
    return fileEditorError(
      'QA 未通过，未导出。修正 deck 源后重试（或传 force=true 强制导出）：\n'
      '${jsonEncode(_qaSummary(issues))}',
    );
  }

  final deckJson = jsonEncode(_deckToTransferable(args));
  final bytes = await Isolate.run(
    () => buildPptxBytes(DeckDocument.parse(deckJson)),
  );

  final pptxPath = await _writeBytes(ref, args, path, bytes);
  String? previewPath;
  if (withPreview) {
    final html = renderDeckHtml(deck);
    previewPath = await _writeBytes(
      ref,
      args,
      '${path.substring(0, path.length - '.pptx'.length)}.preview.html',
      Uint8List.fromList(utf8.encode(html)),
    );
  }

  return fileEditorOk({
    'message': 'PPTX 导出成功（原生可编辑对象）',
    'path': pptxPath,
    if (previewPath != null) 'previewPath': previewPath,
    'slides': deck.slides.length,
    'sizeBytes': bytes.length,
    'qa': _qaSummary(issues),
  });
}

/// Normalizes the `deck` argument to a JSON-encodable object so it can be
/// re-parsed inside the generation isolate (only the JSON string crosses).
Object _deckToTransferable(Map<String, Object?> args) {
  final raw = args['deck'];
  if (raw is Map) return raw;
  return jsonDecode(raw as String) as Object;
}

Future<String> _writeBytes(
  Ref ref,
  Map<String, Object?> args,
  String path,
  Uint8List bytes,
) async {
  final target = await resolveWriteTarget(ref, args, path);
  if (target.existing != null) {
    throw FileEditorError(
      '目标文件已存在：$path。请换一个文件名，或先用 @aether/file-editor 的 '
      'delete_file 删除旧文件。',
    );
  }
  var parent = target.parentPath!;
  for (final dir in target.missingDirs) {
    parent = await target.backend.createDirectory(parent, dir);
  }
  return target.backend.createFileBytes(parent, target.fileName!, bytes);
}
