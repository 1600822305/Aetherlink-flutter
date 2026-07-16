// 终端镜像源的选择与自定义源持久化（SharedPreferences）。
// 三类源：system（apk/apt，随发行版）、pip、npm；每类记录「当前选中 id」
// 与「自定义源列表」（JSON）。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

enum TerminalMirrorKind { system, pip, npm }

class TerminalMirrorStore {
  const TerminalMirrorStore();

  // [scope] 非空时按作用域隔离持久化（远程工作区按工作区 id 存，
  // 与内置终端的全局选择互不干扰）。
  static String _selectedKey(TerminalMirrorKind kind, String scope) =>
      'terminal_mirror_selected_${scope.isEmpty ? '' : '${scope}_'}${kind.name}';

  static String _customKey(TerminalMirrorKind kind, String scope) =>
      'terminal_mirror_custom_${scope.isEmpty ? '' : '${scope}_'}${kind.name}';

  /// 当前选中的源 id；从未选过返回 null（UI 视为官方默认）。
  Future<String?> selectedId(TerminalMirrorKind kind, {String scope = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey(kind, scope));
  }

  Future<void> setSelectedId(
    TerminalMirrorKind kind,
    String id, {
    String scope = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey(kind, scope), id);
  }

  /// 自定义源列表。
  Future<List<TerminalMirror>> customMirrors(
    TerminalMirrorKind kind, {
    String scope = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customKey(kind, scope));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list.cast<Map<String, dynamic>>())
          TerminalMirror(
            id: item['id'] as String,
            name: item['name'] as String,
            baseUrl: item['baseUrl'] as String,
          ),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// 新增自定义源（id 自动生成，前缀 `custom_`）。
  Future<TerminalMirror> addCustomMirror(
    TerminalMirrorKind kind, {
    required String name,
    required String baseUrl,
    String scope = '',
  }) async {
    final mirror = TerminalMirror(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      baseUrl: baseUrl,
    );
    final mirrors = [...await customMirrors(kind, scope: scope), mirror];
    await _saveCustom(kind, mirrors, scope);
    return mirror;
  }

  Future<void> removeCustomMirror(
    TerminalMirrorKind kind,
    String id, {
    String scope = '',
  }) async {
    final mirrors = (await customMirrors(kind, scope: scope))
        .where((m) => m.id != id)
        .toList(growable: false);
    await _saveCustom(kind, mirrors, scope);
  }

  Future<void> _saveCustom(
    TerminalMirrorKind kind,
    List<TerminalMirror> mirrors,
    String scope,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customKey(kind, scope),
      jsonEncode([
        for (final m in mirrors)
          {'id': m.id, 'name': m.name, 'baseUrl': m.baseUrl},
      ]),
    );
  }
}
