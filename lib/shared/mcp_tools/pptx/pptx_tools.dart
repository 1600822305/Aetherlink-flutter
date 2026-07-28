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
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_pptx/aetherlink_pptx.dart';

import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/app/di/deck_snapshot_access.dart';
import 'package:aetherlink_flutter/app/di/media_generation_access.dart';
import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/model_detection/model_checks.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_support.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_write_handlers.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';

/// The built-in MCP server name this router serves.
const String kPptxServerName = '@aether/pptx';

/// 工作区自定义风格目录：`<id>.json` 文件名即风格 id，deck.json 用
/// `"style": "<id>"` 引用；同名覆盖内置风格。
const String kDeckStylesDirName = '.aetherlink/deck_styles';

final RegExp _styleIdPattern = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_\-]*$');

/// 这次 `@aether/pptx` 调用是否要先经用户确认。
///
/// 只有 `pptx_modify` 原地改写用户既有文件时需要——它替换的是别人给的
/// 或用户自己做的 pptx，覆盖后原内容就没了。另存到新路径（`output` 指向
/// 别的文件）视同产出新文件，和 `pptx_render` 一样免确认。
bool pptxToolNeedsConfirmation(String toolName, Map<String, Object?> args) {
  if (toolName != 'pptx_modify') return false;
  final output = args['output'];
  if (output is! String || output.trim().isEmpty) return true;
  final path = args['path'];
  return path is String && path.trim() == output.trim();
}

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
        return await _check(ref, args);
      case 'pptx_draft':
        return await _draft(ref, args);
      case 'pptx_snapshot':
        return await _snapshot(ref, args);
      case 'pptx_render':
        return await _render(ref, args);
      case 'pptx_edit':
        return await _edit(ref, args);
      case 'pptx_illustrate':
        return await _illustrate(ref, args);
      case 'pptx_read':
        return await _read(ref, args);
      case 'pptx_outline':
        return await _outline(ref, args);
      case 'pptx_modify':
        return await _modify(ref, args);
      case 'pptx_styles':
        return await _styles(ref, args);
      case 'pptx_schema':
        return fileEditorOk({
          'schema': kDeckJsonSchema,
          'outlineSchema': kOutlineJsonSchema,
          'usage':
              'deck.json 格式的单一权威来源（与解析器同步，含别名容错说明）。'
              '解析报错时先对照 schema 自查字段名/枚举值/结构',
        });
    }
    return fileEditorError('未知的工具: $toolName');
  } on DeckParseException catch (e) {
    return fileEditorError(
      'deck 源无效：${e.message}\n（字段名/枚举/结构不确定时调 pptx_schema 查权威格式）',
    );
  } on PptxReadException catch (e) {
    return fileEditorError('pptx 读取失败：${e.message}');
  } on PptxEditException catch (e) {
    return fileEditorError('pptx 编辑失败：${e.message}');
  } on FileEditorError catch (e) {
    return fileEditorError(e.message);
  } catch (e) {
    return fileEditorError('PPT 工具执行失败: $e');
  }
}

/// 解析并校验一份工作区风格 JSON，返回可内联进 deck 的风格对象
/// （id 强制为文件名，保证 `"style": "<文件名>"` 与实际一致）。
@visibleForTesting
Map<String, Object?> parseWorkspaceDeckStyle(String id, String jsonText) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (e) {
    throw FileEditorError(
      '工作区风格 $kDeckStylesDirName/$id.json 不是合法 JSON：${e.message}',
    );
  }
  if (decoded is! Map) {
    throw FileEditorError('工作区风格 $kDeckStylesDirName/$id.json 必须是 JSON 对象');
  }
  final style = Map<String, Object?>.from(decoded.cast<String, Object?>());
  style['id'] = id;
  try {
    DeckStyle.fromJson(style, '工作区风格 $kDeckStylesDirName/$id.json');
  } on DeckParseException catch (e) {
    throw FileEditorError(e.message);
  }
  return style;
}

/// 读工作区里 id 对应的自定义风格文件；目录/文件不存在返回 null
/// （回退内置风格），存在但内容非法则报明确错误。
Future<Map<String, Object?>?> _loadWorkspaceStyle(
  Ref ref,
  Map<String, Object?> args,
  String id,
) async {
  if (!_styleIdPattern.hasMatch(id)) return null;
  final String text;
  try {
    final resolved = await resolvePathArg(
      ref,
      args,
      '$kDeckStylesDirName/$id.json',
    );
    text = await resolved.backend.readFile(resolved.path);
  } catch (_) {
    return null;
  }
  return parseWorkspaceDeckStyle(id, text);
}

/// 把 deck 顶层 `"style": "<id>"` 引用的工作区自定义风格内联为风格
/// 对象后返回新 deck（同名覆盖内置）；非字符串 style 或无对应文件时
/// 原样返回。只影响解析/导出，不改写用户的 deck 源。
Future<Object> _inlineWorkspaceStyle(
  Ref ref,
  Map<String, Object?> args,
  Object raw,
) async {
  if (raw is! Map) return raw;
  final styleId = raw['style'];
  if (styleId is! String) return raw;
  final custom = await _loadWorkspaceStyle(ref, args, styleId.trim());
  if (custom == null) return raw;
  final deck = Map<String, Object?>.from(raw.cast<String, Object?>());
  deck['style'] = custom;
  return deck;
}

/// 风格目录：内置 12 套 + 工作区自定义（$kDeckStylesDirName/*.json）。
Future<McpToolResult> _styles(Ref ref, Map<String, Object?> args) async {
  final styles = <Map<String, Object?>>[
    for (final s in builtinDeckStyleCatalog()) {...s, 'source': 'builtin'},
  ];
  try {
    final resolved = await resolvePathArg(ref, args, kDeckStylesDirName);
    final entries = await resolved.backend.listDir(resolved.path);
    for (final e in entries) {
      if (e.isDirectory || !e.name.endsWith('.json')) continue;
      final id = e.name.substring(0, e.name.length - '.json'.length);
      if (!_styleIdPattern.hasMatch(id)) continue;
      try {
        final map = parseWorkspaceDeckStyle(
          id,
          await resolved.backend.readFile(e.path),
        );
        final s = DeckStyle.fromJson(map, id);
        styles.add({
          'id': id,
          'name': s.name,
          'category': s.category,
          'background': s.background.value,
          'accents': [for (final a in s.accents) a.value],
          'source': 'workspace',
        });
      } on FileEditorError catch (err) {
        styles.add({'id': id, 'source': 'workspace', 'error': err.message});
      }
    }
  } catch (_) {
    // 无工作区或目录不存在：只列内置风格。
  }
  return fileEditorOk({
    'styles': styles,
    'usage':
        '在 deck.json 顶层加 "style": "<id>" 套用；元素可省略颜色，'
        '背景/文字/卡片/图表配色自动推导；也可传内联风格对象自定义。'
        '工作区 $kDeckStylesDirName/<id>.json 可增加自定义风格'
        '（字段同内联风格对象：background/cardFill/textPrimary/'
        'textSecondary/accents 必填），同名覆盖内置',
  });
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

/// 读 deck 输入：优先 `source`（工作区 .deck.json 路径），否则 `deck`
/// 参数（对象或 JSON 字符串）。check/render/snapshot 共用，落盘后的
/// deck 用 source 引用即可，不用重发完整 JSON。
Future<Object> _deckFromSourceOrArg(Ref ref, Map<String, Object?> args) async {
  final source = args['source'];
  if (source is String && source.trim().isNotEmpty) {
    if (!source.toLowerCase().endsWith('.deck.json')) {
      throw const FileEditorError('source 必须以 .deck.json 结尾');
    }
    final resolved = await resolvePathArg(ref, args, source);
    final String sourceText;
    try {
      sourceText = await resolved.backend.readFile(resolved.path);
    } catch (e) {
      throw FileEditorError('读取 deck 源失败：$source（$e）');
    }
    try {
      return jsonDecode(sourceText) as Object;
    } on FormatException catch (e) {
      throw FileEditorError('deck 源不是合法 JSON：$source（${e.message}）');
    }
  }
  return _deckToTransferable(args);
}

Future<McpToolResult> _check(Ref ref, Map<String, Object?> args) async {
  // check 除工作区风格文件外不做 IO：未展开的 src 只验证结构，
  // 真正下载/读取在 render/edit。
  final raw = await _inlineWorkspaceStyle(
    ref,
    args,
    await _deckFromSourceOrArg(ref, args),
  );
  if (raw is! Map) throw const FileEditorError('deck 必须是 JSON 对象');
  final deck = DeckDocument.fromJson(raw.cast<String, Object?>());
  final issues = runDeckQa(deck);
  // 包结构自检（实际构建一次 pptx 包：内容类型覆盖/关系完整性/
  // 图表与备注引用）是生成器自身 bug 的兜底，正常恒为空；默认跳过，
  // QA 循环里每轮 check 都全量构建是纯浪费，导出时（render/edit 的
  // export）仍必做；传 deep=true 可在 check 阶段提前跑。
  final deep = optionalBool(args, 'deep');
  final hasUnresolvedImages = _hasUnresolvedImageSrc(raw);
  final structureIssues = !deep || hasUnresolvedImages
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
    if (deep) 'structure': {'errors': structureIssues},
    'message': hasErrors
        ? 'deck 结构合法，但有错误需要修正后再导出'
        : hasUnresolvedImages
        ? 'deck 通过校验（含未展开的图片 src，导出时自动下载/读取并做包结构自检）'
        : deep
        ? 'deck 通过校验（含包结构自检），可以调用 pptx_render 导出'
        : 'deck 通过校验，可以调用 pptx_render 导出（导出时自动做包结构自检）',
  });
}

/// 大纲 → deck 初稿：引擎确定性展开（页型映射/卡片分配/密度交替），
/// 落盘 .deck.json 并附 QA 报告；后续用 pptx_edit 增量精修。
Future<McpToolResult> _draft(Ref ref, Map<String, Object?> args) async {
  final rawOutline = args['outline'];
  final Map<String, Object?> outline;
  if (rawOutline is Map) {
    outline = rawOutline.cast<String, Object?>();
  } else if (rawOutline is String && rawOutline.trim().isNotEmpty) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawOutline);
    } on FormatException catch (e) {
      throw FileEditorError('outline JSON 解析失败: ${e.message}');
    }
    if (decoded is! Map) {
      throw const FileEditorError('outline 必须是 JSON 对象');
    }
    outline = decoded.cast<String, Object?>();
  } else {
    throw const FileEditorError(
      '缺少必需参数: outline（大纲对象或其 JSON 字符串，格式调 pptx_schema 看 outlineSchema）',
    );
  }
  final path = requireString(args, 'path');
  if (!path.toLowerCase().endsWith('.deck.json')) {
    throw const FileEditorError('path 必须以 .deck.json 结尾');
  }

  final deckRaw = ensureSlideIds(buildDeckDraft(outline));
  final inlined = await _inlineWorkspaceStyle(ref, args, deckRaw);
  final deck = DeckDocument.fromJson((inlined as Map).cast<String, Object?>());
  final issues = runDeckQa(deck);

  final savedPath = await _writeBytes(
    ref,
    args,
    path,
    Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(deckRaw)),
    ),
    overwrite: optionalBool(args, 'overwrite'),
  );
  return fileEditorOk({
    'message':
        'deck 初稿已展开落盘。后续修改用 pptx_edit(source: "$path", ops: [...]) '
        '增量改，不要重发完整 deck；check/render/snapshot 都可用 source '
        '引用该文件；确认无误后 pptx_render 导出',
    'path': savedPath,
    'slides': deck.slides.length,
    if (optionalBool(args, 'echo'))
      'deck': deckRaw
    else
      'outline': deckSlideSummary(deckRaw),
    'qa': _qaSummary(issues),
  });
}

/// 给 deck 的每页补上稳定 id（s1、s2 …，已有的不动）：pptx_edit 的 ops
/// 可用 id 寻址，增删页后不会像位置下标那样连环错位。解析器忽略
/// 未知字段，id 不影响导出。
@visibleForTesting
Map<String, Object?> ensureSlideIds(Map<String, Object?> deckRaw) {
  final slides = deckRaw['slides'];
  if (slides is! List) return deckRaw;
  final used = <String>{
    for (final s in slides)
      if (s is Map && s['id'] is String) s['id']! as String,
  };
  var next = 1;
  final newSlides = <Object?>[
    for (final s in slides)
      if (s is Map && s['id'] is! String)
        (() {
          while (used.contains('s$next')) {
            next++;
          }
          used.add('s$next');
          return <String, Object?>{
            'id': 's${next++}',
            ...s.cast<String, Object?>(),
          };
        })()
      else
        s,
  ];
  return {...deckRaw, 'slides': newSlides};
}

/// deck 的逐页轻量摘要（页号/id/布局型/标题/元素数）：取代在 draft 结果里
/// 回传完整 deck，同一份内容已落盘，再全量注入上下文是纯浪费。
@visibleForTesting
List<Map<String, Object?>> deckSlideSummary(Map<String, Object?> deckRaw) {
  final slides = deckRaw['slides'];
  if (slides is! List) return const [];
  return [
    for (final (i, s) in slides.indexed)
      if (s is Map)
        {
          'page': i + 1,
          if (s['id'] is String) 'id': s['id'],
          'layout': switch (s['layout']) {
            final Map<Object?, Object?> layout =>
              '${layout['type'] ?? 'manual'}',
            final String layout => layout,
            _ => 'manual',
          },
          if (_slideTitleOf(s) case final String title) 'title': title,
          'elements': s['elements'] is List
              ? (s['elements']! as List).length
              : 0,
        },
  ];
}

/// 从页的 layout 声明或首个文本元素里猜一个标题（纯展示用）。
String? _slideTitleOf(Map<Object?, Object?> slide) {
  final layout = slide['layout'];
  if (layout is Map && layout['title'] is String) {
    return layout['title']! as String;
  }
  final elements = slide['elements'];
  if (elements is List) {
    for (final e in elements) {
      if (e is Map && e['type'] == 'text') {
        if (e['text'] is String) return e['text']! as String;
        final paragraphs = e['paragraphs'];
        if (paragraphs is List && paragraphs.isNotEmpty) {
          final runs = paragraphs.first is Map
              ? (paragraphs.first as Map)['runs']
              : null;
          if (runs is List && runs.isNotEmpty && runs.first is Map) {
            final text = (runs.first as Map)['text'];
            if (text is String) return text;
          }
        }
        return null;
      }
    }
  }
  return null;
}

/// 视觉自检：把 deck 的某一页离屏渲染成 PNG（与编辑器预览同一几何
/// 模型），图片以多模态消息随结果注入上下文，模型直接看图自查。
/// 截图落在应用内部目录，不写工作区。
Future<McpToolResult> _snapshot(Ref ref, Map<String, Object?> args) async {
  final rawDeck = await _deckFromSourceOrArg(ref, args);
  final inlined = await _inlineWorkspaceStyle(ref, args, rawDeck);
  if (inlined is! Map) throw const FileEditorError('deck 必须是 JSON 对象');
  final expanded = await _resolveImageSources(ref, args, inlined);
  final deck = DeckDocument.fromJson(expanded);

  final pages = parseSnapshotPages(args, deck.slides.length);
  final width = asIntOr(args['width'], 1280).clamp(480, 2560).toDouble();

  final render = ref.read(deckSlideSnapshotRendererProvider);
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/pptx_snapshots');
  await dir.create(recursive: true);

  if (pages.length == 1) {
    final page = pages.first;
    final png = await render(deck, page - 1, width: width);
    final path =
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_p$page.png';
    await File(path).writeAsBytes(png);
    return McpToolResult(
      '已渲染第 $page/${deck.slides.length} 页截图（PNG，${png.length} 字节）；'
      '智能体模式下将以图片消息随本结果注入上下文，请对照设计规范自查：'
      '文字溢出/遮挡、对比度、留白与对齐；发现问题用 pptx_edit 修。',
      imagePath: path,
      imageMimeType: 'image/png',
    );
  }

  // 多页：每页按格子宽渲染后拼成一张 contact-sheet，一次注入上下文，
  // 把逐页自检的往返次数从 O(页数) 降到 O(1)。
  final cols = pages.length <= 4 ? 2 : 3;
  final cellWidth = (width / cols).clamp(320.0, 2560.0);
  final pngs = <Uint8List>[];
  for (final page in pages) {
    pngs.add(await render(deck, page - 1, width: cellWidth));
  }
  final sheet = await _composeContactSheet(pngs, pages, cols);
  final path =
      '${dir.path}/${DateTime.now().microsecondsSinceEpoch}'
      '_p${pages.first}-${pages.last}.png';
  await File(path).writeAsBytes(sheet);
  return McpToolResult(
    '已渲染第 ${pages.join('、')} 页（共 ${deck.slides.length} 页）拼图，'
    '按行优先排列、左上角标注页码；逐页对照设计规范自查：文字溢出/遮挡、'
    '对比度、留白与对齐；可疑页再单页高清复查（page 参数），发现问题用 pptx_edit 修。',
    imagePath: path,
    imageMimeType: 'image/png',
  );
}

/// 单次 contact-sheet 最多拼的页数（再多单格太小看不清）。
const int kSnapshotMaxPages = 12;

/// 解析 snapshot 的页码参数：`pages`（数组或 "all"）优先，否则单页 `page`。
/// 返回去重后的 1 基页码列表（保持传入顺序）。
@visibleForTesting
List<int> parseSnapshotPages(Map<String, Object?> args, int slideCount) {
  final rawPages = args['pages'];
  if (rawPages == null) {
    final page = asIntOr(args['page'], 1);
    if (page < 1 || page > slideCount) {
      throw FileEditorError('page 超出范围：$page（deck 共 $slideCount 页，从 1 起）');
    }
    return [page];
  }
  final List<int> pages;
  if (rawPages is String && rawPages.trim().toLowerCase() == 'all') {
    pages = [for (var p = 1; p <= slideCount; p++) p];
  } else if (rawPages is List) {
    final seen = <int>{};
    pages = [];
    for (final raw in rawPages) {
      if (raw is! int) {
        throw const FileEditorError('pages 必须是页码整数数组或 "all"');
      }
      if (raw < 1 || raw > slideCount) {
        throw FileEditorError('pages 超出范围：$raw（deck 共 $slideCount 页，从 1 起）');
      }
      if (seen.add(raw)) pages.add(raw);
    }
  } else {
    throw const FileEditorError('pages 必须是页码整数数组或 "all"');
  }
  if (pages.isEmpty) {
    throw const FileEditorError('pages 不能为空');
  }
  if (pages.length > kSnapshotMaxPages) {
    throw FileEditorError(
      'pages 一次最多 $kSnapshotMaxPages 页（收到 ${pages.length} 页），请分批截图',
    );
  }
  return pages;
}

/// 把逐页 PNG 拼成 [cols] 列的网格拼图，左上角画页码角标，返回 PNG 字节。
Future<Uint8List> _composeContactSheet(
  List<Uint8List> pngs,
  List<int> pageNumbers,
  int cols,
) async {
  const gap = 8.0;
  final images = <ui.Image>[];
  try {
    for (final png in pngs) {
      final codec = await ui.instantiateImageCodec(png);
      try {
        images.add((await codec.getNextFrame()).image);
      } finally {
        codec.dispose();
      }
    }
    final cellW = images.first.width.toDouble();
    final cellH = images.first.height.toDouble();
    final rows = (images.length + cols - 1) ~/ cols;
    final sheetW = cols * cellW + (cols + 1) * gap;
    final sheetH = rows * cellH + (rows + 1) * gap;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, sheetW, sheetH),
      ui.Paint()..color = const ui.Color(0xFF202124),
    );
    for (final (i, image) in images.indexed) {
      final x = gap + (i % cols) * (cellW + gap);
      final y = gap + (i ~/ cols) * (cellH + gap);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(x, y, cellW, cellH),
        ui.Paint(),
      );
      final builder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(fontSize: 18, fontWeight: ui.FontWeight.bold),
            )
            ..pushStyle(ui.TextStyle(color: const ui.Color(0xFFFFFFFF)))
            ..addText(' p${pageNumbers[i]} ');
      final paragraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: 120));
      canvas.drawRect(
        ui.Rect.fromLTWH(x, y, paragraph.longestLine + 8, 26),
        ui.Paint()..color = const ui.Color(0xCC202124),
      );
      canvas.drawParagraph(paragraph, ui.Offset(x + 4, y + 2));
    }
    final picture = recorder.endRecording();
    final sheet = await picture.toImage(sheetW.ceil(), sheetH.ceil());
    picture.dispose();
    try {
      final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw const FileEditorError('拼图 PNG 编码失败');
      }
      return bytes.buffer.asUint8List();
    } finally {
      sheet.dispose();
    }
  } finally {
    for (final image in images) {
      image.dispose();
    }
  }
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

  bool isUnresolvedImage(Object? e) =>
      e is Map &&
      e['type'] == 'image' &&
      e['data'] == null &&
      e['src'] is String;

  // 先收集去重后的 src 并发加载（命中缓存的直接读盘），同一 src
  // 多处引用只拉一次；再回填到各元素。
  final srcs = <String>{};
  for (final s in slides) {
    if (s is! Map) continue;
    final elements = s['elements'];
    if (elements is! List) continue;
    for (final e in elements) {
      if (isUnresolvedImage(e)) {
        srcs.add(((e as Map)['src']! as String).trim());
      }
    }
  }
  final dataBySrc = <String, String>{};
  await Future.wait([
    for (final src in srcs)
      (() async {
        final bytes = await _loadImageCached(ref, args, src);
        if (detectImageFormat(Uint8List.fromList(bytes)) == null) {
          throw FileEditorError('图片 src 不是 PNG/JPEG：$src');
        }
        dataBySrc[src] = base64Encode(bytes);
      })(),
  ]);

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
        if (isUnresolvedImage(e)) {
          final el = Map<String, Object?>.from(
            (e as Map).cast<String, Object?>(),
          );
          final src = (el.remove('src')! as String).trim();
          el['data'] = dataBySrc[src];
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

/// 远程图片磁盘缓存：同一 URL 在 QA 循环里每次 render/snapshot/export
/// 都会重新展开，不缓存就是重复下载。只缓存 http(s)（工作区文件本地
/// 读很便宜），且只缓存通过格式校验的内容。
Future<List<int>> _loadImageCached(
  Ref ref,
  Map<String, Object?> args,
  String src,
) async {
  final isRemote = src.startsWith('http://') || src.startsWith('https://');
  if (!isRemote) return _loadImage(ref, args, src);

  File? cacheFile;
  try {
    final cacheRoot = await getApplicationCacheDirectory();
    cacheFile = File(
      '${cacheRoot.path}/pptx_image_cache/'
      '${sha256.convert(utf8.encode(src))}',
    );
    if (await cacheFile.exists()) {
      final cached = await cacheFile.readAsBytes();
      if (cached.isNotEmpty &&
          detectImageFormat(Uint8List.fromList(cached)) != null) {
        return cached;
      }
    }
  } catch (_) {
    cacheFile = null; // 缓存不可用不影响主流程，直接下载。
  }

  final bytes = await _loadImage(ref, args, src);
  if (cacheFile != null &&
      detectImageFormat(Uint8List.fromList(bytes)) != null) {
    try {
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(bytes);
    } catch (_) {
      // 写缓存失败忽略。
    }
  }
  return bytes;
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
    await _inlineWorkspaceStyle(
      ref,
      args,
      await _deckFromSourceOrArg(ref, args),
    ),
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
  final built = await Isolate.run(() {
    final bytes = buildPptxBytes(DeckDocument.parse(deckJson));
    return (
      bytes: bytes,
      structure: [for (final i in validatePptxPackage(bytes)) i.toJson()],
    );
  });
  final bytes = built.bytes;
  final structureIssues = built.structure;
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
    deckRaw = applyDeckEditOp(deckRaw, op.cast<String, Object?>(), 'ops[$i]');
  }

  // 结构校验 + QA 用未展开的源（src 引用是合法结构）；写回也保留 src
  // 与风格 id 字符串，避免把 base64/风格对象膨胀进 .deck.json——
  // 只有解析与导出时才展开。
  final inlined = await _inlineWorkspaceStyle(ref, args, deckRaw);
  final deck = DeckDocument.fromJson((inlined as Map).cast<String, Object?>());
  final issues = runDeckQa(deck);
  final force = optionalBool(args, 'force');
  final hasErrors = issues.any((i) => i.severity == DeckQaSeverity.error);
  if (hasErrors && !force) {
    return fileEditorError(
      'QA 未通过，未写回。修正 ops 后重试（或传 force=true 强制）：\n'
      '${jsonEncode(_qaSummary(issues))}',
    );
  }

  // dry_run：只预演 ops 并返回 QA 报告，不写回、不导出——拿不准的改动
  // 先验证再落盘，避免「写坏了再改回来」的往返。
  if (optionalBool(args, 'dry_run')) {
    return fileEditorOk({
      'message':
          'dry_run：ops 可施加，未写回源文件、未导出。'
          '确认后去掉 dry_run 重发同一批 ops 即可生效',
      'source': source,
      'slides': deck.slides.length,
      'ops': ops.length,
      'qa': _qaSummary(issues),
    });
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
    final resolvedRaw = await _resolveImageSources(ref, args, inlined);
    final deckJson = jsonEncode(resolvedRaw);
    final built = await Isolate.run(() {
      final bytes = buildPptxBytes(DeckDocument.parse(deckJson));
      return (
        bytes: bytes,
        structure: [for (final i in validatePptxPackage(bytes)) i.toJson()],
      );
    });
    structureIssues = built.structure;
    if (structureIssues.isNotEmpty && !force) {
      return fileEditorError(
        'deck 源已写回，但导出包结构自检未通过、未写 pptx（可传 force=true）：\n'
        '${jsonEncode(structureIssues)}',
      );
    }
    pptxPath = await _writeBytes(
      ref,
      args,
      export,
      built.bytes,
      overwrite: true,
    );
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

/// 解析一个引用既有条目的下标：整数位置，或字符串 id（匹配条目的
/// "id" 字段）。id 寻址不受前序增删 op 引起的下标漂移影响。
int _opRef(
  Map<String, Object?> op,
  String key,
  List<Object?> entries,
  String where,
) {
  final v = op[key];
  if (v is String) {
    for (final (i, e) in entries.indexed) {
      if (e is Map && e['id'] == v) return i;
    }
    throw FileEditorError('$where 的 $key 没有匹配 id「$v」的条目');
  }
  return _opIndex(op, key, entries.length, where);
}

/// 对 deck JSON 应用一条 `pptx_edit` 操作，返回新的 deck（不改入参）。
/// [where] 是出错时定位到第几条 op 的前缀。
@visibleForTesting
Map<String, Object?> applyDeckEditOp(
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

  // 替换整页/整个元素时，新对象没写 id 就继承旧 id，保证后续 op
  // 还能用同一 id 寻址。
  Object? carryId(Object? oldEntry, Object? newEntry) {
    if (oldEntry is Map &&
        oldEntry['id'] is String &&
        newEntry is Map &&
        newEntry['id'] == null) {
      return <String, Object?>{
        'id': oldEntry['id'],
        ...newEntry.cast<String, Object?>(),
      };
    }
    return newEntry;
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
      final index = _opRef(op, 'index', slides, where);
      slides[index] = carryId(slides[index], op['slide']);
    case 'insert_slide':
      final index = op['index'] == null
          ? slides.length
          : _opIndex(op, 'index', slides.length + 1, where);
      slides.insert(index, op['slide']);
    case 'remove_slide':
      slides.removeAt(_opRef(op, 'index', slides, where));
    case 'move_slide':
      final from = _opRef(op, 'from', slides, where);
      final to = _opIndex(op, 'to', slides.length, where);
      slides.insert(to, slides.removeAt(from));
    case 'set_element':
      final si = _opRef(op, 'slide', slides, where);
      final elements = elementsOf(si);
      final ei = _opRef(op, 'index', elements, where);
      elements[ei] = carryId(elements[ei], op['element']);
      setElements(si, elements);
    case 'append_element':
      final si = _opRef(op, 'slide', slides, where);
      final elements = elementsOf(si)..add(op['element']);
      setElements(si, elements);
    case 'remove_element':
      final si = _opRef(op, 'slide', slides, where);
      final elements = elementsOf(si);
      elements.removeAt(_opRef(op, 'index', elements, where));
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
  final (result, structureIssues) = await Isolate.run(
    () => (
      readPptxBytes(bytes),
      [for (final i in validatePptxPackage(bytes)) i.toJson()],
    ),
  );
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

/// 读出 [path] 指向的 pptx 字节（带大小上限与后缀校验）。
Future<Uint8List> _readPptxArg(
  Ref ref,
  Map<String, Object?> args,
  String path,
  String argName,
) async {
  final lower = path.toLowerCase();
  if (!lower.endsWith('.pptx') && !lower.endsWith('.potx')) {
    throw FileEditorError('$argName 必须以 .pptx 或 .potx 结尾');
  }
  final resolved = await resolvePathArg(ref, args, path);
  final List<int> raw;
  try {
    raw = await resolved.backend.readFileBytes(resolved.path);
  } catch (e) {
    throw FileEditorError('读取文件失败：$path（$e）');
  }
  if (raw.length > _kMaxReadBytes) {
    throw FileEditorError('文件过大（${raw.length} 字节，上限 $_kMaxReadBytes），无法处理');
  }
  return Uint8List.fromList(raw);
}

/// M6 只读：逐页列出 shape 的下标/类型/占位符/当前文本，供模型定位编辑目标。
Future<McpToolResult> _outline(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final bytes = await _readPptxArg(ref, args, path, 'path');
  final slides = await Isolate.run(() {
    final pkg = PptxPackage.open(bytes);
    return [for (final s in describePptxOutline(pkg)) s.toJson()];
  });
  return fileEditorOk({
    'path': path,
    'slides': slides,
    'usage':
        'slide/shape 都是 0 基下标；用 pptx_modify 的 set_text 按 '
        '{slide, shape} 改文字。placeholder 为 title/body/ctrTitle 的 shape '
        '就是模板里的填充位。',
  });
}

/// M6：直接编辑已有 .pptx/.potx（保留母版/主题/版式），按 ops 顺序施加后写回。
Future<McpToolResult> _modify(Ref ref, Map<String, Object?> args) async {
  final path = requireString(args, 'path');
  final ops = args['ops'];
  if (ops is! List || ops.isEmpty) {
    throw const FileEditorError('缺少必需参数: ops（编辑操作数组）');
  }
  final output = optionalString(args, 'output');
  if (output != null && !output.toLowerCase().endsWith('.pptx')) {
    throw const FileEditorError('output 必须以 .pptx 结尾');
  }
  if (output == null && path.toLowerCase().endsWith('.potx')) {
    throw const FileEditorError('.potx 是模板，不能原地改写。请传 output 指定要生成的 .pptx 路径。');
  }

  final bytes = await _readPptxArg(ref, args, path, 'path');

  // 图片字节要在进 isolate 前取好（isolate 里没有 ref / 网络凭据）。
  final images = <int, List<int>>{};
  for (final (i, op) in ops.indexed) {
    if (op is! Map) throw FileEditorError('ops[$i] 必须是对象');
    if (op['op'] != 'replace_image') continue;
    final src = op['src'];
    if (src is! String || src.trim().isEmpty) {
      throw FileEditorError('ops[$i] 的 replace_image 缺少 src（URL 或工作区路径）');
    }
    final data = await _loadImage(ref, args, src);
    if (detectImageFormat(Uint8List.fromList(data)) == null) {
      throw FileEditorError('ops[$i] 的 src 不是 PNG/JPEG 图片：$src');
    }
    images[i] = data;
  }

  final opsJson = jsonEncode(ops);
  final result = await Isolate.run(() {
    final pkg = PptxPackage.open(bytes);
    final decoded = jsonDecode(opsJson) as List;
    final applied = <String>[];
    for (final (i, raw) in decoded.indexed) {
      applied.add(
        _applyPptxOp(
          pkg,
          (raw as Map).cast<String, Object?>(),
          'ops[$i]',
          images[i],
        ),
      );
    }
    final saved = pkg.save();
    return (
      bytes: saved,
      applied: applied,
      slides: pkg.slidePaths().length,
      structure: [for (final i in validatePptxPackage(saved)) i.toJson()],
    );
  });

  final structureIssues = result.structure;
  final force = optionalBool(args, 'force');
  if (structureIssues.isNotEmpty && !force) {
    return fileEditorError(
      '编辑后的包结构自检未通过，未写文件（可传 force=true 强制写出）：\n'
      '${jsonEncode(structureIssues)}',
    );
  }

  final target = output ?? path;
  final saved = await _writeBytes(
    ref,
    args,
    target,
    result.bytes,
    overwrite: true,
  );
  return fileEditorOk({
    'message': output == null ? 'pptx 已原地编辑' : 'pptx 已编辑并另存',
    'path': saved,
    'source': path,
    'slides': result.slides,
    'ops': result.applied,
    'sizeBytes': result.bytes.length,
    'structure': {'errors': structureIssues},
  });
}

/// 施加一条 pptx 包级操作，返回一句人类可读的结果描述。
/// [imageBytes] 只在 replace_image 时有值（已在主 isolate 里下载好）。
String _applyPptxOp(
  PptxPackage pkg,
  Map<String, Object?> op,
  String where,
  List<int>? imageBytes,
) {
  int intArg(String key) {
    final v = op[key];
    if (v is! int) throw PptxEditException('$where 的 $key 必须是整数（收到 $v）');
    return v;
  }

  String strArg(String key) {
    final v = op[key];
    if (v is! String) throw PptxEditException('$where 的 $key 必须是字符串（收到 $v）');
    return v;
  }

  switch (op['op']) {
    case 'set_text':
      final slide = intArg('slide');
      final shape = intArg('shape');
      setShapeText(pkg, slide, shape, strArg('text'));
      return '$where set_text 第 $slide 页 shape $shape';
    case 'replace_text':
      final slide = op['slide'] is int ? op['slide']! as int : null;
      final n = replaceTextEverywhere(
        pkg,
        strArg('find'),
        strArg('replace'),
        slide: slide,
      );
      return '$where replace_text 命中 $n 处'
          '${slide == null ? '（全 deck）' : '（第 $slide 页）'}';
    case 'set_notes':
      final slide = intArg('slide');
      setSlideNotes(pkg, slide, strArg('text'));
      return '$where set_notes 第 $slide 页';
    case 'replace_image':
      if (imageBytes == null) {
        throw PptxEditException('$where 的 replace_image 没有拿到图片数据');
      }
      final slide = intArg('slide');
      final image = op['image'] is int ? op['image']! as int : 0;
      final fmt = detectImageFormat(Uint8List.fromList(imageBytes));
      replaceSlideImage(
        pkg,
        slide,
        image,
        Uint8List.fromList(imageBytes),
        fmt == 'jpeg' ? 'jpg' : (fmt ?? 'png'),
      );
      return '$where replace_image 第 $slide 页第 $image 张';
    case 'duplicate_slide':
      final slide = intArg('slide');
      final at = op['at'] is int ? op['at']! as int : null;
      final index = duplicateSlide(pkg, slide, at: at);
      return '$where duplicate_slide 第 $slide 页 → 新第 $index 页';
    case 'delete_slide':
      final slide = intArg('slide');
      deleteSlide(pkg, slide);
      return '$where delete_slide 第 $slide 页';
    case 'move_slide':
      final from = intArg('from');
      final to = intArg('to');
      moveSlide(pkg, from, to);
      return '$where move_slide $from → $to';
    default:
      throw PptxEditException(
        '$where 的 op 未知：${op['op']}（支持 set_text/replace_text/set_notes/'
        'replace_image/duplicate_slide/delete_slide/move_slide）',
      );
  }
}

/// Normalizes the `deck` argument to a JSON-encodable object so it can be
/// re-parsed inside the generation isolate (only the JSON string crosses).
Object _deckToTransferable(Map<String, Object?> args) {
  final raw = args['deck'];
  if (raw is Map) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      return jsonDecode(raw) as Object;
    } on FormatException catch (e) {
      throw FileEditorError('deck JSON 解析失败: ${e.message}');
    }
  }
  throw const FileEditorError('缺少必需参数: deck（deck.json 对象或其 JSON 字符串）');
}

/// 落盘 [bytes]。覆盖已存在的文件时走 write-temp-then-swap，
/// 详见 [writeBytesAtPath]——生成或写入失败都不会丢掉旧导出。
Future<String> _writeBytes(
  Ref ref,
  Map<String, Object?> args,
  String path,
  Uint8List bytes, {
  bool overwrite = false,
}) => writeBytesAtPath(
  (p) => resolveWriteTarget(ref, args, p),
  path,
  bytes,
  overwrite: overwrite,
);
