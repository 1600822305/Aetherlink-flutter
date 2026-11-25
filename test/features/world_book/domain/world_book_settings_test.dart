// 世界书全局设置（world_book_settings.dart + world_book_access.dart）：
// JSON 键名沿用 ST `world_info_*`、缺失 / 类型不对时取默认值、copyWith，
// 以及发送时读取用的 readWorldBookSettings / 界面用的控制器写穿存储。

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';

/// 在 provider 里调用 readWorldBookSettings，拿到它需要的 Ref。
final _read = FutureProvider.autoDispose<WorldBookSettings>(
  readWorldBookSettings,
);

void main() {
  test('默认值（包含名字默认关闭，其余与 ST 一致）', () {
    const d = WorldBookSettings.defaults;
    expect(d.scanDepth, 2);
    expect(d.budgetPercent, 25);
    expect(d.budgetCap, 0);
    expect(d.includeNames, isFalse);
    expect(d.recursive, isFalse);
    expect(d.caseSensitive, isFalse);
    expect(d.matchWholeWords, isFalse);
    expect(d.minActivations, 0);
    expect(d.maxRecursionSteps, 0);
  });

  test('JSON 往返；键名是 ST 的 world_info_*', () {
    const s = WorldBookSettings(
      scanDepth: 7,
      minActivations: 3,
      minActivationsDepthMax: 20,
      budgetPercent: 40,
      budgetCap: 2048,
      includeNames: false,
      recursive: true,
      maxRecursionSteps: 0,
      caseSensitive: true,
      matchWholeWords: true,
      useGroupScoring: true,
      overflowAlert: true,
    );
    final json = s.toJson();
    expect(json['world_info_depth'], 7);
    expect(json['world_info_budget_cap'], 2048);
    expect(WorldBookSettings.fromJson(jsonDecode(jsonEncode(json))), s);
  });

  test('缺失、类型不对或不是对象时取默认值', () {
    expect(WorldBookSettings.fromJson(null), WorldBookSettings.defaults);
    expect(WorldBookSettings.fromJson('x'), WorldBookSettings.defaults);
    final partial = WorldBookSettings.fromJson({
      'world_info_depth': 5,
      'world_info_recursive': 'yes',
    });
    expect(partial.scanDepth, 5);
    expect(partial.recursive, isFalse);
    expect(partial.budgetPercent, 25);
  });

  test('copyWith 只改给定字段', () {
    final s = WorldBookSettings.defaults.copyWith(recursive: true, budgetCap: 9);
    expect(s.recursive, isTrue);
    expect(s.budgetCap, 9);
    expect(s.scanDepth, 2);
    expect(s, isNot(WorldBookSettings.defaults));
  });

  group('存储', () {
    late ProviderContainer c;

    setUp(() {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      c = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
    });

    test('没有保存过时读到默认值', () async {
      expect(await c.read(_read.future), WorldBookSettings.defaults);
    });

    test('控制器写入后，发送时读到同样的值', () async {
      c.read(worldBookSettingsControllerProvider);
      const next = WorldBookSettings(recursive: true, budgetCap: 500);
      c.read(worldBookSettingsControllerProvider.notifier).update(next);
      expect(c.read(worldBookSettingsControllerProvider), next);
      // persist 是异步写入：等写完再读。
      for (var i = 0; i < 100; i++) {
        final raw = await c
            .read(appSettingsStoreProvider)
            .getSetting(kWorldBookSettingsKey);
        if (raw != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(await c.read(_read.future), next);

      c.read(worldBookSettingsControllerProvider.notifier).reset();
      expect(
        c.read(worldBookSettingsControllerProvider),
        WorldBookSettings.defaults,
      );
    });

    test('存储里是损坏的 JSON 时读到默认值', () async {
      await c
          .read(appSettingsStoreProvider)
          .saveSetting(kWorldBookSettingsKey, '{not json');
      expect(await c.read(_read.future), WorldBookSettings.defaults);
    });
  });
}
