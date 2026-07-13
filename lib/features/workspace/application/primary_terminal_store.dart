import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/workspace/domain/primary_terminal.dart';

part 'primary_terminal_store.g.dart';

/// KV key for the persisted default primary terminal（JSON 单对象）。
const String kPrimaryTerminalKey = 'workspace_primary_terminal';

/// 默认主终端的持久化存储：未设置时为 null（入口会先弹选择器）。
/// 只影响新入口的默认选择，不改动既有工作区 / 智能体绑定 / 已开会话。
@Riverpod(keepAlive: true)
class PrimaryTerminalStore extends _$PrimaryTerminalStore {
  @override
  Future<PrimaryTerminal?> build() async {
    final raw = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kPrimaryTerminalKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return PrimaryTerminal.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    }
  }

  Future<void> set(PrimaryTerminal? value) async {
    state = AsyncData(value);
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(
          kPrimaryTerminalKey,
          value == null ? '' : jsonEncode(value.toJson()),
        );
  }
}
