import 'dart:io';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';
import 'package:dex_editor/dex_editor.dart';
import 'package:permission_handler/permission_handler.dart';

/// `@aether/dex-editor` tool execution — the Dart port of the web
/// `DexEditorServer.ts` (`src/shared/services/mcp/servers/`).
///
/// The server exposes a session-based workflow (open APK → open DEX → search /
/// view / modify → save) plus stateless APK/resource utilities. Every tool
/// forwards to a native action via [DexEditor.execute]; this layer only
/// normalizes arguments and formats the model-facing text, matching the web
/// server's output shape (JSON envelopes + Chinese hints) 1:1.
///
/// [editor] is injectable so unit tests can stub the native bridge.
Future<McpToolResult> runDexEditorTool(
  String toolName,
  Map<String, Object?> args, {
  DexEditor? editor,
}) async {
  final dex = editor ?? DexEditor.instance;
  try {
    // dex 工具直接按绝对路径读写 APK（如 /storage/emulated/0/...）。Android 11+
    // 需要「所有文件访问」权限，否则原生层会报权限错误。凡是带 apkPath/filePath
    // 的工具，先确保拿到存储权限。
    if (args.containsKey('apkPath') || args.containsKey('filePath')) {
      final denied = await _ensureStoragePermission();
      if (denied != null) return denied;
    }
    switch (toolName) {
      case 'dex_open_apk':
        return await _openApk(dex, args);
      case 'dex_open':
        return await _openDex(dex, args);
      case 'dex_list_classes':
        return await _listClasses(dex, args);
      case 'dex_search':
        return await _search(dex, args);
      case 'dex_get_class':
        return await _getClass(dex, args);
      case 'dex_modify_class':
        return await _modifyClass(dex, args);
      case 'dex_save':
        return await _save(dex, args);
      case 'dex_close':
        return await _close(dex, args);
      case 'dex_list_sessions':
        return await _listSessions(dex);
      case 'dex_add_class':
        return await _addClass(dex, args);
      case 'dex_delete_class':
        return await _deleteClass(dex, args);
      case 'dex_get_method':
        return await _getMethod(dex, args);
      case 'dex_modify_method':
        return await _modifyMethod(dex, args);
      case 'dex_outline_class':
        return await _outlineClass(dex, args);
      case 'dex_rename_class':
        return await _renameClass(dex, args);
      case 'dex_find_xrefs':
        return await _findXrefs(dex, args);
      case 'dex_smali_to_java':
        return await _smaliToJava(dex, args);
      case 'apk_get_manifest':
        return await _getManifest(dex, args);
      case 'apk_edit_manifest':
        return await _editManifest(dex, args);
      case 'apk_list_resources':
        return await _listResources(dex, args);
      case 'apk_get_resource':
        return await _getResource(dex, args);
      case 'apk_modify_resource':
        return await _modifyResource(dex, args);
      case 'apk_get_resource_value':
        return await _getResourceValue(dex, args);
      case 'apk_set_resource_value':
        return await _setResourceValue(dex, args);
      case 'apk_list_files':
        return await _listApkFiles(dex, args);
      case 'apk_read_file':
        return await _readApkFile(dex, args);
      case 'apk_delete_file':
        return await _deleteApkFile(dex, args);
      case 'apk_add_file':
        return await _addApkFile(dex, args);
      case 'apk_parse_arsc_cpp':
        return await _parseArscCpp(dex, args);
      case 'attempt_completion':
        return _attemptCompletion(args);
    }
    return McpToolResult('未知的工具: $toolName', isError: true);
  } on DexException catch (e) {
    return McpToolResult('错误: ${e.message ?? '未知错误'}', isError: true);
  } catch (error) {
    return McpToolResult('错误: ${errMsg(error, '未知错误')}', isError: true);
  }
}

// ==================== helpers ====================

/// Native results decode as `Map<Object?, Object?>`; normalize to string keys.
Map<String, Object?> _map(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return const <String, Object?>{};
}

String _str(Object? value) => value?.toString() ?? '';

int _int(Object? value, [int fallback = 0]) => asIntOr(value, fallback);

bool _bool(Object? value) => value == true;

/// Normalizes a class name to dotted form (`com.example.Foo`), accepting every
/// format the tools might see or the model might pass:
///  - type descriptor `Lcom/example/Foo;` → `com.example.Foo`
///  - slash form `com/example/Foo` → `com.example.Foo`
///  - already-dotted `com.example.Foo` → unchanged
/// Array/primitive descriptors (e.g. `[Lcom/x/Y;`) are left untouched.
String _normalizeClassName(String className) {
  if (className.startsWith('L') && className.endsWith(';')) {
    return className.substring(1, className.length - 1).replaceAll('/', '.');
  }
  // Bare slash form → dotted; dotted names have nothing to convert.
  if (!className.contains('.') && className.contains('/')) {
    return className.replaceAll('/', '.');
  }
  return className;
}

/// Returns a copy of [items] (a list of native result maps) with the given
/// class-name [keys] normalized to dotted form via [_normalizeClassName], so
/// `dex_search` / `dex_list_classes` output matches what the other tools echo
/// and accept. Non-map entries and missing/empty keys are passed through.
List<Object?> _normalizeClassFields(List<Object?> items, List<String> keys) {
  return items.map((item) {
    if (item is! Map) return item;
    final normalized = _map(item);
    for (final key in keys) {
      final value = normalized[key];
      if (value is String && value.isNotEmpty) {
        normalized[key] = _normalizeClassName(value);
      }
    }
    return normalized;
  }).toList();
}

/// Slices [text] by UTF-16 code units, but never splits a surrogate pair.
///
/// Cutting a UTF-16 string at an arbitrary code-unit index can orphan a
/// surrogate (e.g. inside an emoji or non-BMP CJK char). The resulting string
/// is not well-formed UTF-16 and crashes Flutter's text layout with
/// "string is not well-formed UTF-16". We nudge the boundary by one code unit
/// so the pair stays intact.
String _sliceFrom(String text, int offset) {
  if (offset <= 0) return text;
  if (offset >= text.length) return '';
  // If the boundary lands on a trailing (low) surrogate, its leading half was
  // already consumed — advance past it so we don't emit an orphan.
  if (_isLowSurrogate(text.codeUnitAt(offset))) offset++;
  if (offset >= text.length) return '';
  return text.substring(offset);
}

String _sliceMax(String text, int maxChars) {
  if (maxChars <= 0 || text.length <= maxChars) return text;
  // If the last kept code unit is a leading (high) surrogate, its trailing half
  // is cut off — drop it so we don't emit an orphan.
  if (_isHighSurrogate(text.codeUnitAt(maxChars - 1))) maxChars--;
  return text.substring(0, maxChars);
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// Uniform pagination metadata for the char-sliced readers (`dex_get_class`,
/// `apk_get_resource`, `apk_get_manifest`). Exposes `totalChars`/`hasMore` so
/// the model can decide whether to page again, `nextOffset` so it doesn't have
/// to compute the next window itself, and an opaque `nextCursor` it can echo
/// straight back into `cursor` to fetch the next page.
Map<String, Object?> _pageMeta(
  int offset,
  int returnedLength,
  int totalChars, [
  int maxChars = 0,
]) {
  final hasMore = offset + returnedLength < totalChars;
  final nextOffset = offset + returnedLength;
  return {
    'offset': offset,
    'returnedLength': returnedLength,
    'totalChars': totalChars,
    'hasMore': hasMore,
    if (hasMore) 'nextOffset': nextOffset,
    if (hasMore)
      'nextCursor': encodeCursor({
        'offset': nextOffset,
        if (maxChars > 0) 'maxChars': maxChars,
      }),
  };
}

/// List pagination metadata with an opaque `nextCursor` for the next page.
/// Mirrors [_pageMeta] but for offset/limit list readers (`dex_list_classes`,
/// `apk_list_files`).
Map<String, Object?> _listMeta({
  required int offset,
  required int limit,
  required int returnedCount,
  required bool hasMore,
}) {
  final nextOffset = offset + returnedCount;
  return {
    'offset': offset,
    'limit': limit,
    'hasMore': hasMore,
    if (hasMore) 'nextOffset': nextOffset,
    if (hasMore)
      'nextCursor': encodeCursor({'offset': nextOffset, 'limit': limit}),
  };
}

/// Resolve `(offset, maxChars)` for a char-sliced reader from an opaque
/// `cursor` (takes precedence) or the explicit `offset`/`maxChars` args, so the
/// old params keep working while the model can just echo `nextCursor`.
({int offset, int maxChars}) _textPage(Map<String, Object?> args) {
  final c = decodeCursor(args['cursor']);
  return (
    offset: _int(c['offset'] ?? args['offset']),
    maxChars: _int(c['maxChars'] ?? args['maxChars']),
  );
}

/// Resolve `(offset, limit)` for an offset/limit list reader from an opaque
/// `cursor` (takes precedence) or the explicit `offset`/`limit` args.
({int offset, int limit}) _listPage(Map<String, Object?> args, int defLimit) {
  final c = decodeCursor(args['cursor']);
  return (
    offset: _int(c['offset'] ?? args['offset']),
    limit: _int(c['limit'] ?? args['limit'], defLimit),
  );
}

/// Class name from a unified `locator` (`dex_class:` / `class:`) or the
/// explicit `className` arg (explicit wins only when no matching locator).
String _classNameArg(Map<String, Object?> args) {
  final loc = parseLocator(args['locator']);
  if (loc != null && (loc.scheme == 'dex_class' || loc.scheme == 'class')) {
    return loc.value;
  }
  return _str(args['className']);
}

/// Session key for the multi-DEX workflow, accepting any of:
///  - `sessionId`（旧参数，仍完全兼容）；
///  - `locator: dex_session:<apkPath>`（统一寻址）；
///  - `apkPath`（无需记 sessionId，原生按 apkPath 复用/惰性重建会话）。
///
/// 原生 `requireOrRebuild` 同时接受 sessionId 与 apkPath，故这里只需返回其一：
/// sessionId 优先（保持既有行为），否则回退到 apkPath。
String _sessionArg(Map<String, Object?> args) {
  final sessionId = _str(args['sessionId']);
  if (sessionId.isNotEmpty) return sessionId;
  final loc = parseLocator(args['locator']);
  if (loc != null && loc.scheme == 'dex_session') {
    return loc.value;
  }
  return _str(args['apkPath']);
}

/// APK-internal file path from a unified `locator` (`apk_file:` / `file:`) or
/// the explicit `filePath` arg.
String _filePathArg(Map<String, Object?> args) {
  final loc = parseLocator(args['locator']);
  if (loc != null && (loc.scheme == 'apk_file' || loc.scheme == 'file')) {
    return loc.value;
  }
  return _str(args['filePath']);
}

/// Resource ID from a unified `locator` (`res:` / `resource:`) or the explicit
/// `id` arg.
String _resIdArg(Map<String, Object?> args) {
  final loc = parseLocator(args['locator']);
  if (loc != null && (loc.scheme == 'res' || loc.scheme == 'resource')) {
    return loc.value;
  }
  return _str(args['id']);
}

// ==================== session workflow ====================

/// 确保拿到读取任意路径文件的存储权限。已授权返回 null；否则尝试申请，
/// 仍未授权则返回一个面向模型/用户的错误结果（不抛异常）。非 Android 平台直接放行。
Future<McpToolResult?> _ensureStoragePermission() async {
  if (!Platform.isAndroid) return null;

  // Android 11+：「所有文件访问」。permission_handler 在低版本上该权限不可用，
  // 会走下面的传统存储权限兜底。
  if (await Permission.manageExternalStorage.isGranted) return null;
  final manage = await Permission.manageExternalStorage.request();
  if (manage.isGranted) return null;

  // Android 10 及以下：传统外部存储读写权限。
  final legacy = await Permission.storage.request();
  if (legacy.isGranted) return null;

  return const McpToolResult(
    '缺少存储权限：无法读取该路径下的文件。请在「系统设置 → 应用 → 本应用 → 权限」'
    '中授予「所有文件访问权限」(All files access / MANAGE_EXTERNAL_STORAGE)，'
    '授权后重新调用即可。',
    isError: true,
  );
}

Future<McpToolResult> _openApk(DexEditor dex, Map<String, Object?> args) async {
  final apkPath = _str(args['apkPath']);
  final result = await dex.execute('listDexFiles', {'apkPath': apkPath});
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  return McpToolResult(encodeJson({
    'apkPath': apkPath,
    'dexFiles': data['dexFiles'] ?? [],
    'hint': '请使用 dex_open 打开你想编辑的 DEX 文件',
  }));
}

Future<McpToolResult> _openDex(DexEditor dex, Map<String, Object?> args) async {
  final apkPath = _str(args['apkPath']);
  final dexFiles = args['dexFiles'] ?? [];
  final result = await dex.execute('openDex', {
    'apkPath': apkPath,
    'dexFiles': dexFiles,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  return McpToolResult(encodeJson({
    'sessionId': data['sessionId'],
    'apkPath': apkPath,
    'dexFiles': dexFiles,
    'classCount': data['classCount'] ?? 0,
    'hint': '会话已创建，可以使用 dex_search 或 dex_list_classes 浏览类',
  }));
}

Future<McpToolResult> _listClasses(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final page = _listPage(args, 100);
  final result = await dex.execute('listClasses', {
    'sessionId': _sessionArg(args),
    'packageFilter': _str(args['packageFilter']),
    'offset': page.offset,
    'limit': page.limit,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  final classes = data['classes'] is List
      ? _normalizeClassFields(data['classes'] as List, const ['className'])
      : const <Object?>[];
  final hasMore = data['hasMore'] == true;
  return McpToolResult(encodeJson({
    'total': data['total'] ?? 0,
    ..._listMeta(
      offset: page.offset,
      limit: page.limit,
      returnedCount: classes.length,
      hasMore: hasMore,
    ),
    'classes': classes,
  }));
}

/// Unified search entry. `target` selects the backend so callers no longer need
/// to remember a separate tool per search surface:
///  - `dex`（默认）：已打开会话内的 DEX 搜索（按 searchType 区分类/方法/字符串…）；
///  - `strings`：DEX 字符串池（等价旧 dex_list_strings）；
///  - `files`：APK 内文本文件搜索（等价旧 apk_search_text）；
///  - `arsc`：resources.arsc 搜索（等价旧 apk_search_arsc，arscTarget 区分 strings/resources）；
///  - `manifest`：AndroidManifest 属性/值搜索（等价旧 apk_search_manifest_cpp）。
///
/// dex/strings 走会话（sessionId，也接受 apkPath）；files/arsc/manifest 走 apkPath。
/// 各 target 复用既有专用 handler，行为与旧工具一致；旧工具仍保留向后兼容。
Future<McpToolResult> _search(DexEditor dex, Map<String, Object?> args) async {
  final target = _str(args['target']).isEmpty ? 'dex' : _str(args['target']);
  switch (target) {
    case 'strings':
      return _listStrings(dex, args);
    case 'files':
      return _searchTextInApk(dex, _withPattern(args));
    case 'arsc':
      return _searchArsc(dex, _withArscTarget(_withPattern(args)));
    case 'manifest':
      return _searchManifestCpp(dex, args);
    case 'dex':
      break;
    default:
      return McpToolResult(
        '错误: 未知的 target "$target"（可选 dex/strings/files/arsc/manifest）',
        isError: true,
      );
  }

  final query = _str(args['query']);
  final searchType = _str(args['searchType']);
  if (searchType.isEmpty) {
    return const McpToolResult(
      '错误: target=dex 时需要 searchType（class/package/method/field/string/int/code/'
      'superclass/interface/annotation）',
      isError: true,
    );
  }
  final result = await dex.execute('searchInDexSession', {
    'sessionId': _sessionArg(args),
    'query': query,
    'searchType': searchType,
    'caseSensitive': _bool(args['caseSensitive']),
    'maxResults': _int(args['maxResults'], 50),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  final results = data['results'] is List
      ? _normalizeClassFields(
          data['results'] as List,
          const ['className', 'superclass', 'interface', 'annotation'],
        )
      : const <Object?>[];
  return McpToolResult(encodeJson({
    'query': query,
    'searchType': searchType,
    'total': data['total'] ?? 0,
    'results': results,
  }));
}

/// 统一入口用 `query` 表达搜索词；apk 系列专用 handler 读的是 `pattern`。
/// 当只给了 query 时补一个 pattern，二者都在时不覆盖，保持旧工具直连兼容。
Map<String, Object?> _withPattern(Map<String, Object?> args) {
  if (_str(args['pattern']).isNotEmpty || _str(args['query']).isEmpty) {
    return args;
  }
  return {...args, 'pattern': args['query']};
}

/// arsc target 的子目标参数：统一入口用 `arscTarget`（避免与顶层 target 冲突），
/// _searchArsc 读的是 `target`；这里把 arscTarget 映射过去。
Map<String, Object?> _withArscTarget(Map<String, Object?> args) {
  final arscTarget = _str(args['arscTarget']);
  if (arscTarget.isEmpty) return args;
  return {...args, 'target': arscTarget};
}

Future<McpToolResult> _getClass(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_classNameArg(args));
  final result = await dex.execute('getClassSmaliFromSession', {
    'sessionId': _sessionArg(args),
    'className': className,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  var smali = _str(_map(result.data)['smaliContent']);
  final totalChars = smali.length;
  final page = _textPage(args);
  final offset = page.offset;
  final maxChars = page.maxChars;
  if (offset > 0) smali = _sliceFrom(smali, offset);
  if (maxChars > 0) smali = _sliceMax(smali, maxChars);
  if (maxChars > 0 || offset > 0) {
    return McpToolResult(encodeJson({
      'className': className,
      ..._pageMeta(offset, smali.length, totalChars, maxChars),
      'content': smali,
    }));
  }
  return McpToolResult(smali);
}

Future<McpToolResult> _modifyClass(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_classNameArg(args));
  final result = await dex.execute('modifyClass', {
    'sessionId': _sessionArg(args),
    'className': className,
    'smaliContent': _str(args['smaliContent']),
  });
  if (!result.success) {
    return McpToolResult('修改失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 类 $className 已修改（内存中）。请使用 dex_save 保存到 APK。');
}

Future<McpToolResult> _addClass(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_str(args['className']));
  final result = await dex.execute('addClassToSession', {
    'sessionId': _sessionArg(args),
    'className': className,
    'smaliContent': _str(args['smaliContent']),
  });
  if (!result.success) {
    return McpToolResult('添加类失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 类 $className 已添加（内存中）。请使用 dex_save 保存到 APK。');
}

Future<McpToolResult> _deleteClass(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_str(args['className']));
  final result = await dex.execute('deleteClassFromSession', {
    'sessionId': _sessionArg(args),
    'className': className,
  });
  if (!result.success) {
    return McpToolResult('删除类失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 类 $className 已删除（内存中）。请使用 dex_save 保存到 APK。');
}

Future<McpToolResult> _getMethod(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_classNameArg(args));
  final result = await dex.execute('getMethodFromSession', {
    'sessionId': _sessionArg(args),
    'className': className,
    'methodName': _str(args['methodName']),
    'methodSignature': _str(args['methodSignature']),
  });
  if (!result.success) {
    return McpToolResult('获取方法失败: ${result.error}', isError: true);
  }
  final code = _str(_map(result.data)['methodCode']);
  return McpToolResult(code.isEmpty ? '# 方法未找到' : code);
}

Future<McpToolResult> _modifyMethod(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_classNameArg(args));
  final methodName = _str(args['methodName']);
  final result = await dex.execute('modifyMethodInSession', {
    'sessionId': _sessionArg(args),
    'className': className,
    'methodName': methodName,
    'methodSignature': _str(args['methodSignature']),
    'newMethodCode': _str(args['newMethodCode']),
  });
  if (!result.success) {
    return McpToolResult('修改方法失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 方法 $methodName 已修改（内存中）。请使用 dex_save 保存到 APK。');
}

Future<McpToolResult> _outlineClass(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_classNameArg(args));
  final result = await dex.execute('outlineClassFromSession', {
    'sessionId': _sessionArg(args),
    'className': className,
  });
  if (!result.success) {
    return McpToolResult('获取类轮廓失败: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

Future<McpToolResult> _renameClass(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final oldClassName = _normalizeClassName(_str(args['oldClassName']));
  final newClassName = _normalizeClassName(_str(args['newClassName']));
  final result = await dex.execute('renameClassInSession', {
    'sessionId': _sessionArg(args),
    'oldClassName': oldClassName,
    'newClassName': newClassName,
  });
  if (!result.success) {
    return McpToolResult('重命名类失败: ${result.error}', isError: true);
  }
  return McpToolResult(
    '✅ 类已重命名: $oldClassName → $newClassName。请使用 dex_save 保存到 APK。',
  );
}

Future<McpToolResult> _save(DexEditor dex, Map<String, Object?> args) async {
  // scope=all 保存全部有改动的会话；默认 current 仅当前会话。
  if (_str(args['scope']) == 'all') {
    return _saveAll(dex);
  }
  final result = await dex.execute('saveDexToApk', {
    'sessionId': _sessionArg(args),
  });
  if (!result.success) {
    return McpToolResult('保存失败: ${result.error}', isError: true);
  }
  return const McpToolResult('✅ DEX 已编译并保存到 APK。\n\n⚠️ APK 需要重新签名才能安装。请用户自行签名。');
}

Future<McpToolResult> _saveAll(DexEditor dex) async {
  final result = await dex.execute('saveAllDexToApk', const {});
  if (!result.success) {
    return McpToolResult('保存失败: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  final saved = _int(data['saved']);
  final skipped = _int(data['skipped']);
  final failed = _int(data['failed']);
  final summary =
      '批量保存完成：已保存 $saved 个，跳过 $skipped 个，失败 $failed 个。\n${encodeJson(data)}';
  if (failed > 0) {
    return McpToolResult(summary, isError: true);
  }
  if (saved == 0) {
    return McpToolResult('没有需要保存的会话（$skipped 个无改动）。\n${encodeJson(data)}');
  }
  return McpToolResult('✅ $summary\n\n⚠️ 修改后的 APK 需要重新签名才能安装。');
}

Future<McpToolResult> _close(DexEditor dex, Map<String, Object?> args) async {
  final sessionId = _sessionArg(args);
  final result = await dex.execute('closeMultiDexSession', {
    'sessionId': sessionId,
  });
  if (!result.success) {
    return McpToolResult('关闭失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 会话 $sessionId 已关闭');
}

Future<McpToolResult> _listSessions(DexEditor dex) async {
  final result = await dex.execute('listSessions', const {});
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final sessions = _map(result.data)['sessions'];
  final list = sessions is List ? sessions : const <Object?>[];
  if (list.isEmpty) {
    return const McpToolResult('当前没有打开的 DEX 编辑会话。请使用 dex_open_apk 开始。');
  }
  return McpToolResult(encodeJson({'total': list.length, 'sessions': list}));
}

// ==================== C++ / xref utilities ====================

Future<McpToolResult> _listStrings(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('listStrings', {
    'sessionId': _sessionArg(args),
    'filter': _str(args['filter']),
    'limit': _int(args['limit'], 100),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

/// 统一交叉引用入口。`target` 选择分析对象（method|field|class），复用既有专用 handler。
Future<McpToolResult> _findXrefs(DexEditor dex, Map<String, Object?> args) async {
  final target = _str(args['target']).isEmpty ? 'method' : _str(args['target']);
  switch (target) {
    case 'method':
      return _findMethodXrefs(dex, args);
    case 'field':
      return _findFieldXrefs(dex, args);
    case 'class':
      return _findClassXrefs(dex, args);
    default:
      return McpToolResult(
        '错误: 未知的 target「$target」，应为 method/field/class',
        isError: true,
      );
  }
}

Future<McpToolResult> _findMethodXrefs(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('findMethodXrefs', {
    'sessionId': _sessionArg(args),
    'className': _classNameArg(args),
    'methodName': _str(args['methodName']),
    'methodSignature': _str(args['methodSignature']),
    'resolution': _str(args['resolution']),
    'limit': _int(args['limit'], 50),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final xrefs = _map(result.data)['xrefs'];
  final count = xrefs is List ? xrefs.length : 0;
  return McpToolResult('找到 $count 个交叉引用:\n${encodeJson(result.data)}');
}

Future<McpToolResult> _findFieldXrefs(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('findFieldXrefs', {
    'sessionId': _sessionArg(args),
    'className': _classNameArg(args),
    'fieldName': _str(args['fieldName']),
    'fieldType': _str(args['fieldType']),
    'access': _str(args['access']),
    'limit': _int(args['limit'], 50),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final xrefs = _map(result.data)['xrefs'];
  final count = xrefs is List ? xrefs.length : 0;
  return McpToolResult('找到 $count 个交叉引用:\n${encodeJson(result.data)}');
}

Future<McpToolResult> _findClassXrefs(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('findClassXrefs', {
    'sessionId': _sessionArg(args),
    'className': _classNameArg(args),
    'limit': _int(args['limit'], 50),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final xrefs = _map(result.data)['xrefs'];
  final count = xrefs is List ? xrefs.length : 0;
  return McpToolResult('找到 $count 个类级交叉引用:\n${encodeJson(result.data)}');
}

Future<McpToolResult> _smaliToJava(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_classNameArg(args));
  final result = await dex.execute('smaliToJava', {
    'sessionId': _sessionArg(args),
    'className': className,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final java = _str(_map(result.data)['java']);
  return McpToolResult('// Java 伪代码 - $className\n\n${java.isEmpty ? '转换失败' : java}');
}

// ==================== manifest / resources ====================

Future<McpToolResult> _getManifest(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  // format=structured 走 C++ 高性能解析，返回结构化信息；默认 xml 返回可读文本
  if (_str(args['format']) == 'structured') {
    final result = await dex.execute('parseManifestCpp', {
      'apkPath': _str(args['apkPath']),
    });
    if (!result.success) {
      return McpToolResult('错误: ${result.error}', isError: true);
    }
    return McpToolResult(encodeJson(result.data));
  }
  final result = await dex.execute('getManifest', {
    'apkPath': _str(args['apkPath']),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  var content = _str(_map(result.data)['manifest']);
  final totalChars = content.length;
  final page = _textPage(args);
  final offset = page.offset;
  final maxChars = page.maxChars;
  if (offset > 0) content = _sliceFrom(content, offset);
  if (maxChars > 0) content = _sliceMax(content, maxChars);
  if (maxChars > 0 || offset > 0) {
    return McpToolResult(encodeJson({
      ..._pageMeta(offset, content.length, totalChars, maxChars),
      'content': content,
    }));
  }
  return McpToolResult(content.isEmpty ? '无法读取 Manifest' : content);
}

/// 统一清单写入入口。`mode` 选择编辑方式，复用既有专用 handler，行为不变：
///  - `replace_all`（默认）：整体替换（读 `newManifest`）；
///  - `patch`：结构化补丁（读 `patches`）；
///  - `find_replace`：文本查找替换（读 `replacements`）。
Future<McpToolResult> _editManifest(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final mode = _str(args['mode']).isEmpty ? 'replace_all' : _str(args['mode']);
  switch (mode) {
    case 'replace_all':
      return _modifyManifest(dex, args);
    case 'patch':
      return _patchManifest(dex, args);
    case 'find_replace':
      return _replaceInManifest(dex, args);
    default:
      return McpToolResult(
        '错误: 未知的 mode「$mode」，应为 replace_all/patch/find_replace',
        isError: true,
      );
  }
}

Future<McpToolResult> _modifyManifest(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('modifyManifest', {
    'apkPath': _str(args['apkPath']),
    'newManifest': _str(args['newManifest']),
  });
  if (!result.success) {
    return McpToolResult('修改失败: ${result.error}', isError: true);
  }
  return const McpToolResult('✅ AndroidManifest.xml 已修改并保存到 APK\n⚠️ APK 需要重新签名');
}

Future<McpToolResult> _patchManifest(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final patches = args['patches'];
  final patchList = patches is List ? patches : const <Object?>[];
  final result = await dex.execute('patchManifest', {
    'apkPath': _str(args['apkPath']),
    'patches': patchList,
  });
  final data = _map(result.data);
  // `result.success` is the transport-level envelope flag; the business result
  // (whether any patch was actually applied) lives in `data['success']`.
  if (!result.success || data['success'] == false) {
    return McpToolResult(
      encodeJson({
        'success': false,
        'error': result.error ?? data['error'] ?? '修改失败',
        'details': data['details'],
      }),
      isError: true,
    );
  }
  return McpToolResult(encodeJson({
    'success': true,
    'appliedCount': data['appliedCount'] ?? patchList.length,
    'details': data['details'],
    'message': 'AndroidManifest.xml 已修改，APK 需要重新签名',
  }));
}

Future<McpToolResult> _replaceInManifest(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final replacements = args['replacements'] ?? [];
  final result = await dex.execute('replaceInManifest', {
    'apkPath': _str(args['apkPath']),
    'replacements': replacements,
  });
  if (!result.success) {
    return McpToolResult('替换失败: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  return McpToolResult(encodeJson({
    'success': true,
    'replacedCount': data['replacedCount'] ?? 0,
    'details': data['details'] ?? [],
    'message': 'AndroidManifest.xml 已修改，APK 需要重新签名',
  }));
}

Future<McpToolResult> _listResources(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('listResources', {
    'apkPath': _str(args['apkPath']),
    'filter': _str(args['filter']),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  return McpToolResult(encodeJson({
    'total': data['total'] ?? 0,
    'resources': data['resources'] ?? [],
  }));
}

Future<McpToolResult> _getResource(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final resourcePath = _filePathArg(args).isNotEmpty
      ? _filePathArg(args)
      : _str(args['resourcePath']);
  final result = await dex.execute('getResource', {
    'apkPath': _str(args['apkPath']),
    'resourcePath': resourcePath,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  var content = _str(data['content']);
  final totalChars = content.length;
  final resourceType = data['type'] == null ? 'unknown' : _str(data['type']);
  final page = _textPage(args);
  final offset = page.offset;
  final maxChars = page.maxChars;
  if (offset > 0) content = _sliceFrom(content, offset);
  if (maxChars > 0) content = _sliceMax(content, maxChars);
  if (maxChars > 0 || offset > 0) {
    return McpToolResult(encodeJson({
      'path': resourcePath,
      'type': resourceType,
      ..._pageMeta(offset, content.length, totalChars, maxChars),
      'content': content,
    }));
  }
  return McpToolResult(content.isEmpty ? '无法读取资源' : content);
}

Future<McpToolResult> _modifyResource(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final resourcePath = _str(args['resourcePath']);
  final result = await dex.execute('modifyResource', {
    'apkPath': _str(args['apkPath']),
    'resourcePath': resourcePath,
    'newContent': _str(args['newContent']),
  });
  if (!result.success) {
    return McpToolResult('修改资源失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 资源文件 $resourcePath 已修改。APK 需要重新签名。');
}

Future<McpToolResult> _getResourceValue(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final id = _resIdArg(args);
  final result = await dex.execute('getResourceValue', {
    'apkPath': _str(args['apkPath']),
    'id': id,
  });
  if (!result.success) {
    return McpToolResult('读取资源值失败: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

Future<McpToolResult> _setResourceValue(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final id = _resIdArg(args);
  final result = await dex.execute('setResourceValue', {
    'apkPath': _str(args['apkPath']),
    'id': id,
    'config': _str(args['config']),
    'valueType': args['valueType'] == null ? 'auto' : _str(args['valueType']),
    'value': _str(args['value']),
  });
  if (!result.success) {
    return McpToolResult('修改资源值失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 资源 $id 的值已修改并写回 resources.arsc。APK 需要重新签名。');
}

Future<McpToolResult> _listApkFiles(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final page = _listPage(args, 100);
  final result = await dex.execute('listApkFiles', {
    'apkPath': _str(args['apkPath']),
    'filter': _str(args['filter']),
    'limit': page.limit,
    'offset': page.offset,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  final files =
      data['files'] is List ? data['files'] as List : const <Object?>[];
  final hasMore = data['hasMore'] == true;
  return McpToolResult(encodeJson({
    ...data,
    ..._listMeta(
      offset: page.offset,
      limit: page.limit,
      returnedCount: files.length,
      hasMore: hasMore,
    ),
  }));
}

Future<McpToolResult> _searchTextInApk(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final pattern = _str(args['pattern']);
  final result = await dex.execute('searchTextInApk', {
    'apkPath': _str(args['apkPath']),
    'pattern': pattern,
    'fileExtensions': args['fileExtensions'] ?? [],
    'caseSensitive': _bool(args['caseSensitive']),
    'isRegex': _bool(args['isRegex']),
    'maxResults': _int(args['maxResults'], 50),
    'contextLines': _int(args['contextLines'], 2),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  return McpToolResult(encodeJson({
    'pattern': pattern,
    'totalFound': data['totalFound'] ?? 0,
    'filesSearched': data['filesSearched'] ?? 0,
    'truncated': data['truncated'] ?? false,
    'results': data['results'] ?? [],
  }));
}

Future<McpToolResult> _readApkFile(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('readApkFile', {
    'apkPath': _str(args['apkPath']),
    'filePath': _str(args['filePath']),
    'asBase64': _bool(args['asBase64']),
    'maxBytes': _int(args['maxBytes']),
    'offset': _int(args['offset']),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

Future<McpToolResult> _deleteApkFile(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final filePath = _filePathArg(args);
  final result = await dex.execute('deleteFileFromApk', {
    'apkPath': _str(args['apkPath']),
    'filePath': filePath,
  });
  if (!result.success) {
    return McpToolResult('删除文件失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 已删除文件: $filePath\n⚠️ APK 需要重新签名');
}

Future<McpToolResult> _addApkFile(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final filePath = _filePathArg(args);
  final result = await dex.execute('addFileToApk', {
    'apkPath': _str(args['apkPath']),
    'filePath': filePath,
    'content': _str(args['content']),
    'isBase64': _bool(args['isBase64']),
  });
  if (!result.success) {
    return McpToolResult('添加文件失败: ${result.error}', isError: true);
  }
  return McpToolResult('✅ 已添加/替换文件: $filePath\n⚠️ APK 需要重新签名');
}

Future<McpToolResult> _searchArsc(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final target = _str(args['target']).isEmpty ? 'strings' : _str(args['target']);
  final DexResult result;
  if (target == 'resources') {
    result = await dex.execute('searchArscResources', {
      'apkPath': _str(args['apkPath']),
      'pattern': _str(args['pattern']),
      'type': _str(args['type']),
      'limit': _int(args['limit'], 50),
    });
  } else {
    result = await dex.execute('searchArscStrings', {
      'apkPath': _str(args['apkPath']),
      'pattern': _str(args['pattern']),
      'limit': _int(args['limit'], 50),
    });
  }
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

Future<McpToolResult> _searchManifestCpp(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('searchManifestCpp', {
    'apkPath': _str(args['apkPath']),
    'attrName': _str(args['attrName']),
    'value': _str(args['value']),
    'limit': _int(args['limit'], 50),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

Future<McpToolResult> _parseArscCpp(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('parseArscCpp', {
    'apkPath': _str(args['apkPath']),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

/// Agentic completion sentinel — the port of `attemptCompletion`. Returns the
/// same `__agentic_completion__` marker payload the web server emits.
McpToolResult _attemptCompletion(Map<String, Object?> args) {
  final result = _str(args['result']);
  if (result.isEmpty) {
    return const McpToolResult('错误: 缺少必需参数 result（任务完成摘要）', isError: true);
  }
  return McpToolResult(encodeJson({
    '__agentic_completion__': true,
    'result': result,
    'command': args['command'],
    'completedAt': DateTime.now().toUtc().toIso8601String(),
  }));
}
