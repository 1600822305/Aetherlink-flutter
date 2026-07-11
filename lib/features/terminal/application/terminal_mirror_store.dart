// 终端镜像源的选择与自定义源持久化（SharedPreferences）。
// 三类源：system（apk/apt，随发行版）、pip、npm；每类记录「当前选中 id」
// 与「自定义源列表」（JSON）。

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:aetherlink_flutter/features/terminal/domain/terminal_mirrors.dart';

enum TerminalMirrorKind { system, pip, npm }

class TerminalMirrorStore {
  const TerminalMirrorStore();

  static String _selectedKey(TerminalMirrorKind kind) =>
      'terminal_mirror_selected_${kind.name}';

  static String _customKey(TerminalMirrorKind kind) =>
      'terminal_mirror_custom_${kind.name}';

  /// 当前选中的源 id；从未选过返回 null（UI 视为官方默认）。
  Future<String?> selectedId(TerminalMirrorKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey(kind));
  }

  Future<void> setSelectedId(TerminalMirrorKind kind, String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey(kind), id);
  }

  /// 自定义源列表。
  Future<List<TerminalMirror>> customMirrors(TerminalMirrorKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_customKey(kind));
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
  }) async {
    final mirror = TerminalMirror(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      baseUrl: baseUrl,
    );
    final mirrors = [...await customMirrors(kind), mirror];
    await _saveCustom(kind, mirrors);
    return mirror;
  }

  Future<void> removeCustomMirror(TerminalMirrorKind kind, String id) async {
    final mirrors = (await customMirrors(kind))
        .where((m) => m.id != id)
        .toList(growable: false);
    await _saveCustom(kind, mirrors);
  }

  Future<void> _saveCustom(
    TerminalMirrorKind kind,
    List<TerminalMirror> mirrors,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _customKey(kind),
      jsonEncode([
        for (final m in mirrors)
          {'id': m.id, 'name': m.name, 'baseUrl': m.baseUrl},
      ]),
    );
  }
}
