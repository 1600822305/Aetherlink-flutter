import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tool_helpers.dart';
import 'package:dex_editor/dex_editor.dart';

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
      case 'dex_list_methods':
        return await _listMethods(dex, args);
      case 'dex_list_fields':
        return await _listFields(dex, args);
      case 'dex_rename_class':
        return await _renameClass(dex, args);
      case 'dex_list_strings':
        return await _listStrings(dex, args);
      case 'dex_find_method_xrefs':
        return await _findMethodXrefs(dex, args);
      case 'dex_find_field_xrefs':
        return await _findFieldXrefs(dex, args);
      case 'dex_smali_to_java':
        return await _smaliToJava(dex, args);
      case 'apk_get_manifest':
        return await _getManifest(dex, args);
      case 'apk_modify_manifest':
        return await _modifyManifest(dex, args);
      case 'apk_patch_manifest':
        return await _patchManifest(dex, args);
      case 'apk_replace_in_manifest':
        return await _replaceInManifest(dex, args);
      case 'apk_list_resources':
        return await _listResources(dex, args);
      case 'apk_get_resource':
        return await _getResource(dex, args);
      case 'apk_modify_resource':
        return await _modifyResource(dex, args);
      case 'apk_list_files':
        return await _listApkFiles(dex, args);
      case 'apk_search_text':
        return await _searchTextInApk(dex, args);
      case 'apk_read_file':
        return await _readApkFile(dex, args);
      case 'apk_delete_file':
        return await _deleteApkFile(dex, args);
      case 'apk_add_file':
        return await _addApkFile(dex, args);
      case 'apk_search_arsc':
        return await _searchArsc(dex, args);
      case 'apk_parse_manifest_cpp':
        return await _parseManifestCpp(dex, args);
      case 'apk_search_manifest_cpp':
        return await _searchManifestCpp(dex, args);
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

/// Normalizes `Lcom/example/Foo;` → `com.example.Foo`; leaves dotted names.
String _normalizeClassName(String className) {
  if (className.startsWith('L') && className.endsWith(';')) {
    return className.substring(1, className.length - 1).replaceAll('/', '.');
  }
  return className;
}

/// Slices [text] by UTF-16 code units, matching JS `String.slice`.
String _sliceFrom(String text, int offset) {
  if (offset <= 0) return text;
  if (offset >= text.length) return '';
  return text.substring(offset);
}

String _sliceMax(String text, int maxChars) {
  if (maxChars <= 0 || text.length <= maxChars) return text;
  return text.substring(0, maxChars);
}

// ==================== session workflow ====================

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
  final offset = _int(args['offset']);
  final limit = _int(args['limit'], 100);
  final result = await dex.execute('listClasses', {
    'sessionId': _str(args['sessionId']),
    'packageFilter': _str(args['packageFilter']),
    'offset': offset,
    'limit': limit,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  return McpToolResult(encodeJson({
    'total': data['total'] ?? 0,
    'offset': offset,
    'limit': limit,
    'classes': data['classes'] ?? [],
    'hasMore': data['hasMore'] ?? false,
  }));
}

Future<McpToolResult> _search(DexEditor dex, Map<String, Object?> args) async {
  final query = _str(args['query']);
  final searchType = _str(args['searchType']);
  final result = await dex.execute('searchInDexSession', {
    'sessionId': _str(args['sessionId']),
    'query': query,
    'searchType': searchType,
    'caseSensitive': _bool(args['caseSensitive']),
    'maxResults': _int(args['maxResults'], 50),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  return McpToolResult(encodeJson({
    'query': query,
    'searchType': searchType,
    'total': data['total'] ?? 0,
    'results': data['results'] ?? [],
  }));
}

Future<McpToolResult> _getClass(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_str(args['className']));
  final result = await dex.execute('getClassSmaliFromSession', {
    'sessionId': _str(args['sessionId']),
    'className': className,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  var smali = _str(_map(result.data)['smaliContent']);
  final totalLength = smali.length;
  final offset = _int(args['offset']);
  final maxChars = _int(args['maxChars']);
  if (offset > 0) smali = _sliceFrom(smali, offset);
  if (maxChars > 0) smali = _sliceMax(smali, maxChars);
  if (maxChars > 0 || offset > 0) {
    return McpToolResult(encodeJson({
      'className': className,
      'totalLength': totalLength,
      'offset': offset,
      'returnedLength': smali.length,
      'hasMore': offset + smali.length < totalLength,
      'content': smali,
    }));
  }
  return McpToolResult(smali);
}

Future<McpToolResult> _modifyClass(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_str(args['className']));
  final result = await dex.execute('modifyClass', {
    'sessionId': _str(args['sessionId']),
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
    'sessionId': _str(args['sessionId']),
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
    'sessionId': _str(args['sessionId']),
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
  final className = _normalizeClassName(_str(args['className']));
  final result = await dex.execute('getMethodFromSession', {
    'sessionId': _str(args['sessionId']),
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
  final className = _normalizeClassName(_str(args['className']));
  final methodName = _str(args['methodName']);
  final result = await dex.execute('modifyMethodInSession', {
    'sessionId': _str(args['sessionId']),
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

Future<McpToolResult> _listMethods(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_str(args['className']));
  final result = await dex.execute('listMethodsFromSession', {
    'sessionId': _str(args['sessionId']),
    'className': className,
  });
  if (!result.success) {
    return McpToolResult('获取方法列表失败: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

Future<McpToolResult> _listFields(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _normalizeClassName(_str(args['className']));
  final result = await dex.execute('listFieldsFromSession', {
    'sessionId': _str(args['sessionId']),
    'className': className,
  });
  if (!result.success) {
    return McpToolResult('获取字段列表失败: ${result.error}', isError: true);
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
    'sessionId': _str(args['sessionId']),
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
  final result = await dex.execute('saveDexToApk', {
    'sessionId': _str(args['sessionId']),
  });
  if (!result.success) {
    return McpToolResult('保存失败: ${result.error}', isError: true);
  }
  return const McpToolResult('✅ DEX 已编译并保存到 APK。\n\n⚠️ APK 需要重新签名才能安装。请用户自行签名。');
}

Future<McpToolResult> _close(DexEditor dex, Map<String, Object?> args) async {
  final sessionId = _str(args['sessionId']);
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
    'sessionId': _str(args['sessionId']),
    'filter': _str(args['filter']),
    'limit': _int(args['limit'], 100),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
}

Future<McpToolResult> _findMethodXrefs(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('findMethodXrefs', {
    'sessionId': _str(args['sessionId']),
    'className': _str(args['className']),
    'methodName': _str(args['methodName']),
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
    'sessionId': _str(args['sessionId']),
    'className': _str(args['className']),
    'fieldName': _str(args['fieldName']),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final xrefs = _map(result.data)['xrefs'];
  final count = xrefs is List ? xrefs.length : 0;
  return McpToolResult('找到 $count 个交叉引用:\n${encodeJson(result.data)}');
}

Future<McpToolResult> _smaliToJava(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final className = _str(args['className']);
  final result = await dex.execute('smaliToJava', {
    'sessionId': _str(args['sessionId']),
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
  final result = await dex.execute('getManifest', {
    'apkPath': _str(args['apkPath']),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  var content = _str(_map(result.data)['manifest']);
  final totalLength = content.length;
  final offset = _int(args['offset']);
  final maxChars = _int(args['maxChars']);
  if (offset > 0) content = _sliceFrom(content, offset);
  if (maxChars > 0) content = _sliceMax(content, maxChars);
  if (maxChars > 0 || offset > 0) {
    return McpToolResult(encodeJson({
      'totalLength': totalLength,
      'offset': offset,
      'returnedLength': content.length,
      'hasMore': offset + content.length < totalLength,
      'content': content,
    }));
  }
  return McpToolResult(content.isEmpty ? '无法读取 Manifest' : content);
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
  final resourcePath = _str(args['resourcePath']);
  final result = await dex.execute('getResource', {
    'apkPath': _str(args['apkPath']),
    'resourcePath': resourcePath,
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  final data = _map(result.data);
  var content = _str(data['content']);
  final totalLength = content.length;
  final resourceType = data['type'] == null ? 'unknown' : _str(data['type']);
  final offset = _int(args['offset']);
  final maxChars = _int(args['maxChars']);
  if (offset > 0) content = _sliceFrom(content, offset);
  if (maxChars > 0) content = _sliceMax(content, maxChars);
  if (maxChars > 0 || offset > 0) {
    return McpToolResult(encodeJson({
      'path': resourcePath,
      'type': resourceType,
      'totalLength': totalLength,
      'offset': offset,
      'returnedLength': content.length,
      'hasMore': offset + content.length < totalLength,
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

Future<McpToolResult> _listApkFiles(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('listApkFiles', {
    'apkPath': _str(args['apkPath']),
    'filter': _str(args['filter']),
    'limit': _int(args['limit'], 100),
    'offset': _int(args['offset']),
  });
  if (!result.success) {
    return McpToolResult('错误: ${result.error}', isError: true);
  }
  return McpToolResult(encodeJson(result.data));
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
  final filePath = _str(args['filePath']);
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
  final filePath = _str(args['filePath']);
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

Future<McpToolResult> _parseManifestCpp(
  DexEditor dex,
  Map<String, Object?> args,
) async {
  final result = await dex.execute('parseManifestCpp', {
    'apkPath': _str(args['apkPath']),
  });
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
