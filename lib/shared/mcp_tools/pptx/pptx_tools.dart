// `@aether/pptx` built-in MCP server — local execution entry point.
//
// Turns a structured deck.json source (the intermediate representation the
// model produces) into a native, fully-editable .pptx written into the user's
// workspace, plus an optional self-contained HTML preview. Generation is pure
// Dart (packages/aetherlink_pptx) and runs inside an isolate; deterministic
// layout QA gates delivery so the model can self-correct before exporting.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';

import 'package:aetherlink_flutter/app/di/media_generation_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
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
        return await _check(args);
      case 'pptx_render':
        return await _render(ref, args);
      case 'pptx_edit':
        return await _edit(ref, args);
      case 'pptx_illustrate':
        return await _illustrate(ref, args);
      case 'pptx_read':
        return await _read(ref, args);
      case 'pptx_styles':
        return fileEditorOk({
          'styles': builtinDeckStyleCatalog(),
          'usage':
              '在 deck.json 顶层加 "style": "<id>" 套用；元素可省略颜色，'
              '背景/文字/卡片/图表配色自动推导；也可传内联风格对象自定义',
        });
    }
    return fileEditorError('未知的工具: $toolName');
  } on DeckParseException catch (e) {
    return fileEditorError('deck 源无效：${e.message}');
  } on PptxReadException catch (e) {
    return fileEditorError('pptx 读取失败：${e.message}');
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

Future<McpToolResult> _check(Map<String, Object?> args) async {
  final deck = _parseDeckArg(args);
  // check 不做 IO：未展开的 src 只验证结构，真正下载/读取在 render/edit。
  final issues = runDeckQa(deck);
  // deck_validate：实际构建一次 pptx 包并做结构自检（内容类型覆盖/
  // 关系完整性/图表与备注引用），对齐 validate.py 的检查面。
  final raw = _deckToTransferable(args);
  final hasUnresolvedImages = _hasUnresolvedImageSrc(raw);
  final structureIssues = hasUnresolvedImages
      ? const <Map<String, Object?>>[]
      : await (() {
          final deckJson = jsonEncode(raw);
          return Isolate.run(() {
            final bytes = buildPptxBytes(DeckDocument.parse(deckJson));
            return [for (final i in validatePptxPackage(bytes)) i.toJson()];
          });
        })();
  final hasErrors =
      issues.any((i) => i.severity == DeckQaSeverity.error) ||
      structureIssues.isNotEmpty;
  return fileEditorOk({
    'valid': true,
    'slides': deck.slides.length,
    'qa': _qaSummary(issues),
    'structure': {'errors': structureIssues},
    'message': hasErrors
        ? 'deck 结构合法，但有错误需要修正后再导出'
        : hasUnresolvedImages
        ? 'deck 通过校验（含未展开的图片 src，导出时自动下载/读取并做包结构自检）'
        : 'deck 通过校验，可以调用 pptx_render 导出',
  });
}

bool _hasUnresolvedImageSrc(Object raw) {
  if (raw is! Map) return false;
  final slides = raw['slides'];
  if (slides is! List) return false;
  for (final s in slides) {
    if (s is! Map) continue;
    final elements = s['elements'];
    if (elements is! List) continue;
    for (final e in elements) {
      if (e is Map &&
          e['type'] == 'image' &&
          e['data'] == null &&
          e['src'] is String) {
        return true;
      }
    }
  }
  return false;
}

/// 单张引用图片上限（下载/工作区读取）。
const int _kMaxImageBytes = 10 * 1024 * 1024;

/// 把 image 元素的 `src`（http(s) URL 或工作区路径）展开为内联 base64
/// `data`，返回展开后的 deck JSON（深拷受影响节点，不改入参）。
Future<Map<String, Object?>> _resolveImageSources(
  Ref ref,
  Map<String, Object?> args,
  Object raw,
) async {
  if (raw is! Map) {
    throw const FileEditorError('deck 必须是 JSON 对象');
  }
  final deck = Map<String, Object?>.from(raw.cast<String, Object?>());
  final slides = deck['slides'];
  if (slides is! List) return deck;
  final newSlides = <Object?>[];
  for (final s in slides) {
    if (s is! Map) {
      newSlides.add(s);
      continue;
    }
    final slide = Map<String, Object?>.from(s.cast<String, Object?>());
    final elements = slide['elements'];
    if (elements is List) {
      final newElements = <Object?>[];
      for (final e in elements) {
        if (e is Map &&
            e['type'] == 'image' &&
            e['data'] == null &&
            e['src'] is String) {
          final el = Map<String, Object?>.from(e.cast<String, Object?>());
          final src = (el.remove('src')! as String).trim();
          final bytes = await _loadImage(ref, args, src);
          if (detectImageFormat(Uint8List.fromList(bytes)) == null) {
            throw FileEditorError('图片 src 不是 PNG/JPEG：$src');
          }
          el['data'] = base64Encode(bytes);
          newElements.add(el);
        } else {
          newElements.add(e);
        }
      }
      slide['elements'] = newElements;
    }
    newSlides.add(slide);
  }
  deck['slides'] = newSlides;
  return deck;
}

Future<List<int>> _loadImage(
  Ref ref,
  Map<String, Object?> args,
  String src,
) async {
  if (src.startsWith('http://') || src.startsWith('https://')) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(src));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw FileEditorError('下载图片失败（HTTP ${response.statusCode}）：$src');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > _kMaxImageBytes) {
          throw FileEditorError('图片超过 $_kMaxImageBytes 字节上限：$src');
        }
      }
      return builder.takeBytes();
    } on FileEditorError {
      rethrow;
    } catch (e) {
      throw FileEditorError('下载图片失败：$src（$e）');
    } finally {
      client.close(force: true);
    }
  }
  final resolved = await resolvePathArg(ref, args, src);
  final List<int> bytes;
  try {
    bytes = await resolved.backend.readFileBytes(resolved.path);
  } catch (e) {
    throw FileEditorError('读取图片文件失败：$src（$e）');
  }
  if (bytes.length > _kMaxImageBytes) {
    throw FileEditorError('图片超过 $_kMaxImageBytes 字节上限：$src');
  }
  return bytes;
}

Future<McpToolResult> _render(Ref ref, Map<String, Object?> args) async {
  final deckRaw = await _resolveImageSources(
    ref,
    args,
    _deckToTransferable(args),
  );
  final deck = DeckDocument.fromJson(deckRaw.cast<String, Object?>());
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

  final deckJson = jsonEncode(deckRaw);
  final bytes = await Isolate.run(
    () => buildPptxBytes(DeckDocument.parse(deckJson)),
  );
  final structureIssues = [
    for (final i in validatePptxPackage(bytes)) i.toJson(),
  ];
  if (structureIssues.isNotEmpty && !force) {
    return fileEditorError(
      '导出的 pptx 包结构自检未通过，未写入文件（可传 force=true 强制）：\n'
      '${jsonEncode(structureIssues)}',
    );
  }

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
    'structure': {'errors': structureIssues},
  });
}

/// 增量编辑：以工作区 .deck.json 为源应用 ops，写回源文件并可重导出
/// .pptx（允许覆盖旧导出），不用重发完整 deck。
Future<McpToolResult> _edit(Ref ref, Map<String, Object?> args) async {
  final source = requireString(args, 'source');
  if (!source.toLowerCase().endsWith('.deck.json')) {
    throw const FileEditorError('source 必须以 .deck.json 结尾');
  }
  final ops = args['ops'];
  if (ops is! List || ops.isEmpty) {
    throw const FileEditorError('缺少必需参数: ops（编辑操作数组）');
  }
  final resolved = await resolvePathArg(ref, args, source);
  final String sourceText;
  try {
    sourceText = await resolved.backend.readFile(resolved.path);
  } catch (e) {
    throw FileEditorError('读取 deck 源失败：$source（$e）');
  }
  final Object decoded;
  try {
    decoded = jsonDecode(sourceText) as Object;
  } on FormatException catch (e) {
    throw FileEditorError('deck 源不是合法 JSON：$source（${e.message}）');
  }
  if (decoded is! Map) {
    throw FileEditorError('deck 源必须是 JSON 对象：$source');
  }
  var deckRaw = Map<String, Object?>.from(decoded.cast<String, Object?>());
  for (final (i, op) in ops.indexed) {
    if (op is! Map) throw FileEditorError('ops[$i] 必须是对象');
    deckRaw = _applyOp(deckRaw, op.cast<String, Object?>(), 'ops[$i]');
  }

  deckRaw = await _resolveImageSources(ref, args, deckRaw);
  final deck = DeckDocument.fromJson(deckRaw);
  final issues = runDeckQa(deck);
  final force = optionalBool(args, 'force');
  final hasErrors = issues.any((i) => i.severity == DeckQaSeverity.error);
  if (hasErrors && !force) {
    return fileEditorError(
      'QA 未通过，未写回。修正 ops 后重试（或传 force=true 强制）：\n'
      '${jsonEncode(_qaSummary(issues))}',
    );
  }

  await resolved.backend.writeFile(
    resolved.path,
    const JsonEncoder.withIndent('  ').convert(deckRaw),
  );

  final export = optionalString(args, 'export');
  String? pptxPath;
  var structureIssues = const <Map<String, Object?>>[];
  if (export != null) {
    if (!export.toLowerCase().endsWith('.pptx')) {
      throw const FileEditorError('export 必须以 .pptx 结尾');
    }
    final deckJson = jsonEncode(deckRaw);
    final bytes = await Isolate.run(
      () => buildPptxBytes(DeckDocument.parse(deckJson)),
    );
    structureIssues = [for (final i in validatePptxPackage(bytes)) i.toJson()];
    if (structureIssues.isNotEmpty && !force) {
      return fileEditorError(
        'deck 源已写回，但导出包结构自检未通过、未写 pptx（可传 force=true）：\n'
        '${jsonEncode(structureIssues)}',
      );
    }
    pptxPath = await _writeBytes(ref, args, export, bytes, overwrite: true);
  }

  return fileEditorOk({
    'message': export == null
        ? 'deck 源已增量更新（未导出，传 export 可同时重导出 pptx）'
        : 'deck 源已增量更新并重导出 pptx',
    'source': source,
    if (pptxPath != null) 'path': pptxPath,
    'slides': deck.slides.length,
    'ops': ops.length,
    'qa': _qaSummary(issues),
    'structure': {'errors': structureIssues},
  });
}

int _opIndex(Map<String, Object?> op, String key, int max, String where) {
  final v = op[key];
  if (v is! int || v < 0 || v >= max) {
    throw FileEditorError('$where 的 $key 必须是 0..${max - 1} 的整数（收到 $v）');
  }
  return v;
}

Map<String, Object?> _applyOp(
  Map<String, Object?> deck,
  Map<String, Object?> op,
  String where,
) {
  final result = Map<String, Object?>.from(deck);
  final slides = [...?(deck['slides'] as List?)];
  List<Object?> elementsOf(int slideIndex) {
    final s = slides[slideIndex];
    if (s is! Map) throw FileEditorError('$where 目标幻灯片不是对象');
    return [...?(s['elements'] as List?)];
  }

  void setElements(int slideIndex, List<Object?> elements) {
    final s = Map<String, Object?>.from(
      (slides[slideIndex] as Map).cast<String, Object?>(),
    );
    s['elements'] = elements;
    slides[slideIndex] = s;
  }

  switch (op['op']) {
    case 'set_meta':
      for (final key in const ['title', 'style', 'layout']) {
        if (op.containsKey(key)) result[key] = op[key];
      }
    case 'set_slide':
      slides[_opIndex(op, 'index', slides.length, where)] = op['slide'];
    case 'insert_slide':
      final index = op['index'] == null
          ? slides.length
          : _opIndex(op, 'index', slides.length + 1, where);
      slides.insert(index, op['slide']);
    case 'remove_slide':
      slides.removeAt(_opIndex(op, 'index', slides.length, where));
    case 'move_slide':
      final from = _opIndex(op, 'from', slides.length, where);
      final to = _opIndex(op, 'to', slides.length, where);
      slides.insert(to, slides.removeAt(from));
    case 'set_element':
      final si = _opIndex(op, 'slide', slides.length, where);
      final elements = elementsOf(si);
      elements[_opIndex(op, 'index', elements.length, where)] = op['element'];
      setElements(si, elements);
    case 'append_element':
      final si = _opIndex(op, 'slide', slides.length, where);
      final elements = elementsOf(si)..add(op['element']);
      setElements(si, elements);
    case 'remove_element':
      final si = _opIndex(op, 'slide', slides.length, where);
      final elements = elementsOf(si)
        ..removeAt(_opIndex(op, 'index', elementsOf(si).length, where));
      setElements(si, elements);
    default:
      throw FileEditorError(
        '$where 的 op 未知：${op['op']}（支持 set_meta/set_slide/insert_slide/'
        'remove_slide/move_slide/set_element/append_element/remove_element）',
      );
  }
  result['slides'] = slides;
  return result;
}

/// AI 配图：用已配置的图像生成模型把 prompt 生成为图片存进工作区，
/// 之后用 image 元素的 src 引用；无可用图像模型时返回明确错误，
/// 技能侧降级为色块/形状装饰。
Future<McpToolResult> _illustrate(Ref ref, Map<String, Object?> args) async {
  final prompt = requireString(args, 'prompt');
  final path = requireString(args, 'path');
  final lower = path.toLowerCase();
  if (!lower.endsWith('.png') &&
      !lower.endsWith('.jpg') &&
      !lower.endsWith('.jpeg')) {
    throw const FileEditorError('path 必须以 .png / .jpg / .jpeg 结尾');
  }

  final providers = await ref.read(appModelProvidersProvider.future);
  final candidates = <CurrentModel>[
    for (final provider in providers)
      for (final model in provider.models)
        if (isGenerateImageModel(model))
          CurrentModel(provider: provider, model: model),
  ];
  if (candidates.isEmpty) {
    throw const FileEditorError(
      '没有配置任何图像生成模型：无法 AI 配图。'
      '请降级为色块/形状装饰，或引导用户在模型设置里添加图像生成模型',
    );
  }
  final wanted = optionalString(args, 'model')?.trim().toLowerCase();
  CurrentModel selected = candidates.first;
  if (wanted != null && wanted.isNotEmpty) {
    final match = candidates
        .where(
          (c) =>
              c.model.id.toLowerCase() == wanted ||
              c.model.name.toLowerCase() == wanted,
        )
        .firstOrNull;
    if (match == null) {
      throw FileEditorError(
        '没有名为「$wanted」的图像生成模型；可用：'
        '${candidates.map((c) => c.model.name).join('、')}',
      );
    }
    selected = match;
  }

  final gateway = ref.read(appMediaGenerationGatewayProvider);
  final List<String> urls;
  try {
    urls = await gateway.generateImages(
      model: effectiveModelFor(selected),
      prompt: prompt,
    );
  } catch (e) {
    throw FileEditorError('图像生成失败（模型 ${selected.model.name}）：$e');
  }
  if (urls.isEmpty) {
    throw FileEditorError('图像生成模型 ${selected.model.name} 未返回任何图片');
  }

  final url = urls.first;
  final List<int> bytes;
  if (url.startsWith('data:')) {
    final comma = url.indexOf(',');
    if (comma < 0) throw const FileEditorError('生成结果 data URL 格式无效');
    try {
      bytes = base64Decode(url.substring(comma + 1).trim());
    } on FormatException {
      throw const FileEditorError('生成结果 data URL 不是合法 base64');
    }
  } else {
    bytes = await _loadImage(ref, args, url);
  }
  if (detectImageFormat(Uint8List.fromList(bytes)) == null) {
    throw const FileEditorError('生成结果不是 PNG/JPEG 图片，无法嵌入 pptx');
  }

  final saved = await _writeBytes(
    ref,
    args,
    path,
    Uint8List.fromList(bytes),
    overwrite: true,
  );
  return fileEditorOk({
    'message': '配图已生成，在 image 元素里用 "src": "$path" 引用',
    'path': saved,
    'model': selected.model.name,
    'sizeBytes': bytes.length,
    if (urls.length > 1) 'extraUrls': urls.sublist(1),
  });
}

/// 单文件读取上限：超大 pptx（内嵌视频等）直接拒绝，避免把内存打爆。
const int _kMaxReadBytes = 50 * 1024 * 1024;

Future<McpToolResult> _read(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final lower = path.toLowerCase();
  if (!lower.endsWith('.pptx') && !lower.endsWith('.potx')) {
    throw const FileEditorError('path 必须以 .pptx 或 .potx 结尾');
  }
  final format = optionalString(args, 'format') ?? 'markdown';
  if (format != 'markdown' && format != 'deck') {
    throw const FileEditorError('format 只支持 markdown / deck');
  }
  final resolved = await resolvePathArg(ref, args, path);
  final List<int> raw;
  try {
    raw = await resolved.backend.readFileBytes(resolved.path);
  } catch (e) {
    throw FileEditorError('读取文件失败：$path（$e）');
  }
  if (raw.length > _kMaxReadBytes) {
    throw FileEditorError('文件过大（${raw.length} 字节，上限 $_kMaxReadBytes），无法读取');
  }
  final bytes = Uint8List.fromList(raw);
  final result = await Isolate.run(() => readPptxBytes(bytes));
  final structureIssues = [
    for (final i in validatePptxPackage(bytes)) i.toJson(),
  ];
  return fileEditorOk({
    'path': path,
    'slides': result.slides.length,
    if (result.title != null) 'title': result.title,
    'canvas':
        '${result.slideWidthInches.toStringAsFixed(2)}×'
        '${result.slideHeightInches.toStringAsFixed(2)} 英寸',
    if (format == 'markdown') 'markdown': pptxToMarkdown(result),
    if (format == 'deck') 'deck': pptxToDeckSkeleton(result),
    'structure': {
      'errors': structureIssues,
      'message': structureIssues.isEmpty
          ? '包结构完整'
          : '包结构有 ${structureIssues.length} 处问题（不影响内容提取）',
    },
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
  Uint8List bytes, {
  bool overwrite = false,
}) async {
  var target = await resolveWriteTarget(ref, args, path);
  final existing = target.existing;
  if (existing != null) {
    if (!overwrite) {
      throw FileEditorError(
        '目标文件已存在：$path。请换一个文件名，或先用 @aether/file-editor 的 '
        'delete_file 删除旧文件。',
      );
    }
    // 覆盖旧导出：后端没有二进制 overwrite，用删除 + 重建实现；
    // 删除后重解析拿到创建目标（parentPath/fileName）。
    await target.backend.delete(existing.path);
    target = await resolveWriteTarget(ref, args, path);
  }
  var parent = target.parentPath!;
  for (final dir in target.missingDirs) {
    parent = await target.backend.createDirectory(parent, dir);
  }
  return target.backend.createFileBytes(parent, target.fileName!, bytes);
}
