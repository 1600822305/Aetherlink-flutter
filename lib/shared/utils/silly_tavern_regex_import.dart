import 'dart:convert';

import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';

/// SillyTavern 正则脚本导入转换器 — 将 SillyTavern 的正则脚本格式转换为
/// 本项目的 [AssistantRegex]（`sillyTavernRegexImport.ts` 的迁移）。

/// 导入解析失败时抛出，携带面向用户的中文提示。
class SillyTavernImportException implements Exception {
  const SillyTavernImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 将 SillyTavern 的 `placement` 数组转换为作用范围。
/// placement: 0=User Input, 1=AI Response。无匹配时默认 assistant。
List<AssistantRegexScope> _convertPlacementToScopes(List<int> placement) {
  final scopes = <AssistantRegexScope>[];
  if (placement.contains(0)) scopes.add(AssistantRegexScope.user);
  if (placement.contains(1)) scopes.add(AssistantRegexScope.assistant);
  if (scopes.isEmpty) scopes.add(AssistantRegexScope.assistant);
  return scopes;
}

/// 将 SillyTavern 的 `{{match}}` 宏转换为 `$&`（整段匹配引用）。
String _convertReplaceString(String replaceString) => replaceString.replaceAll(
  RegExp(r'\{\{match\}\}', caseSensitive: false),
  r'$&',
);

List<int> _readPlacement(Object? raw) {
  if (raw is List) {
    return <int>[
      for (final value in raw)
        if (value is num) value.toInt(),
    ];
  }
  return const <int>[];
}

/// 将单个 SillyTavern 脚本（JSON map）转换为 [AssistantRegex]。
AssistantRegex _convertScript(Map<String, dynamic> script) {
  final placement = _readPlacement(script['placement']);
  return AssistantRegex(
    id: generateId('regex'),
    name: (script['scriptName'] as String?)?.trim().isNotEmpty == true
        ? script['scriptName'] as String
        : '未命名规则',
    pattern: (script['findRegex'] as String?) ?? '',
    replacement: _convertReplaceString(
      (script['replaceString'] as String?) ?? '',
    ),
    scopes: _convertPlacementToScopes(
      placement.isEmpty ? const [1] : placement,
    ),
    visualOnly: script['markdownOnly'] as bool? ?? false,
    enabled: !(script['disabled'] as bool? ?? false),
  );
}

/// 是否为有效的 SillyTavern 正则脚本格式（单个或数组）。每个脚本至少有
/// `scriptName` 或 `findRegex`，且 `placement` 若存在必须是数组。
bool isSillyTavernRegexFormat(Object? data) {
  if (data == null) return false;
  final scripts = data is List ? data : [data];
  if (scripts.isEmpty) return false;
  for (final script in scripts) {
    if (script is! Map) return false;
    final hasName = (script['scriptName'] as String?)?.isNotEmpty ?? false;
    final hasRegex = (script['findRegex'] as String?)?.isNotEmpty ?? false;
    if (!hasName && !hasRegex) return false;
    final placement = script['placement'];
    if (placement != null && placement is! List) return false;
  }
  return true;
}

/// 批量导入：解析 JSON 字符串并转换为 [AssistantRegex] 列表。无效 JSON 抛出
/// [SillyTavernImportException]；逐条跳过既无名称又无正则的无效脚本。
List<AssistantRegex> importSillyTavernRegexScripts(String jsonContent) {
  Object? data;
  try {
    data = jsonDecode(jsonContent);
  } catch (_) {
    throw const SillyTavernImportException('无效的 JSON 格式');
  }

  final scripts = data is List ? data : [data];
  final results = <AssistantRegex>[];
  for (final script in scripts) {
    if (script is! Map) continue;
    final map = Map<String, dynamic>.from(script);
    final hasName = (map['scriptName'] as String?)?.isNotEmpty ?? false;
    final hasRegex = (map['findRegex'] as String?)?.isNotEmpty ?? false;
    if (!hasName && !hasRegex) continue;
    results.add(_convertScript(map));
  }
  return results;
}
