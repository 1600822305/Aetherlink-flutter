// Codex 宠物皮肤：粘贴 codex-pet.org 宠物链接一键导入，下载其
// spritesheet 存到应用目录，之后宠物用该精灵图渲染（覆盖默认外观）。
// 单键 JSON 持久化（同 hooks/压缩设置的模式）。

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

/// Settings-store key（单键 JSON）。
const String kBuddyCodexSkinKey = 'buddy_codex_skin';

class BuddyCodexSkin {
  const BuddyCodexSkin({required this.id, required this.name, required this.path});

  final String id;
  final String name;

  /// spritesheet 本地文件路径。
  final String path;
}

class BuddyCodexSkinState {
  const BuddyCodexSkinState({this.skin, this.importing = false, this.error});

  final BuddyCodexSkin? skin;
  final bool importing;
  final String? error;
}

final buddyCodexSkinProvider =
    NotifierProvider<BuddyCodexSkinController, BuddyCodexSkinState>(
        BuddyCodexSkinController.new);

class BuddyCodexSkinController extends Notifier<BuddyCodexSkinState> {
  @override
  BuddyCodexSkinState build() {
    ref
        .read(appSettingsStoreProvider)
        .getSetting(kBuddyCodexSkinKey)
        .then((raw) {
      if (raw == null || raw.isEmpty) return;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final skin = BuddyCodexSkin(
          id: map['id'] as String,
          name: map['name'] as String? ?? map['id'] as String,
          path: map['path'] as String,
        );
        if (File(skin.path).existsSync()) {
          state = BuddyCodexSkinState(skin: skin);
        }
      } catch (_) {}
    });
    return const BuddyCodexSkinState();
  }

  /// 从 codex-pet.org 宠物页链接（或直接输入宠物 id）导入皮肤。
  Future<bool> importFromUrl(String input) async {
    final id = _parsePetId(input.trim());
    if (id == null) {
      state = BuddyCodexSkinState(
          skin: state.skin, error: '无法识别链接，请粘贴 codex-pet.org 的宠物页链接');
      return false;
    }
    state = BuddyCodexSkinState(skin: state.skin, importing: true);
    try {
      final dio = Dio();
      final bytes = await dio.get<List<int>>(
        'https://codex-pet.org/api/pets/$id/files/spritesheet.webp',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = bytes.data;
      if (data == null || data.isEmpty) throw Exception('empty spritesheet');
      var name = id;
      try {
        final meta = await dio.get<Map<String, dynamic>>(
            'https://codex-pet.org/api/pets/$id/files/pet.json');
        name = meta.data?['displayName'] as String? ?? id;
      } catch (_) {}
      final dir = Directory(
          '${(await getApplicationSupportDirectory()).path}/buddy_skins');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$id.webp');
      await file.writeAsBytes(data, flush: true);
      final skin = BuddyCodexSkin(id: id, name: name, path: file.path);
      state = BuddyCodexSkinState(skin: skin);
      await ref.read(appSettingsStoreProvider).saveSetting(
            kBuddyCodexSkinKey,
            jsonEncode({'id': skin.id, 'name': skin.name, 'path': skin.path}),
          );
      return true;
    } catch (_) {
      state = BuddyCodexSkinState(skin: state.skin, error: '导入失败，请检查链接和网络');
      return false;
    }
  }

  /// 恢复默认外观（保留已下载的文件，便于重新启用时秒切）。
  void clear() {
    state = const BuddyCodexSkinState();
    ref.read(appSettingsStoreProvider).saveSetting(kBuddyCodexSkinKey, '');
  }

  static String? _parsePetId(String input) {
    if (input.isEmpty) return null;
    final urlMatch = RegExp(r'pets/([A-Za-z0-9_-]+)').firstMatch(input);
    if (urlMatch != null) return urlMatch.group(1);
    if (RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(input)) return input;
    return null;
  }
}
