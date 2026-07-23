import 'dart:convert';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/settings/application/skills_controller.dart';
import 'package:aetherlink_flutter/shared/config/builtin_skills.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 只实现 KV 两个方法的假 ChatRepository（其余方法测试内不会被调用）。
class _FakeKvStore implements ChatRepository {
  final Map<String, String> values = {};

  @override
  Future<String?> getSetting(String key) async => values[key];

  @override
  Future<void> saveSetting(String key, String value) async {
    values[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _FakeKvStore store;
  late ProviderContainer container;

  setUp(() {
    store = _FakeKvStore();
    container = ProviderContainer(
      overrides: [appSettingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  Future<List<Skill>> load() => container.read(skillsProvider.future);

  test('首次运行种子全部内置技能', () async {
    final skills = await load();
    expect(
      skills.map((s) => s.id),
      containsAll(kBuiltinSkills.map((s) => s.id)),
    );
    expect(store.values[kSkillsSettingKey], isNotNull);
  });

  test('启动时按 version 变化重种内置技能，保留用户开关/用量', () async {
    final catalog = kBuiltinSkills.first;
    final stale = catalog.copyWith(
      version: '0.0.1',
      content: '旧正文',
      enabled: false,
      usageCount: 7,
      lastUsedAt: '2026-01-01T00:00:00.000Z',
    );
    store.values[kSkillsSettingKey] = jsonEncode([
      stale.toJson(),
      for (final b in kBuiltinSkills.skip(1)) b.toJson(),
    ]);

    final skills = await load();
    final upgraded = skills.singleWhere((s) => s.id == catalog.id);
    expect(upgraded.version, catalog.version);
    expect(upgraded.content, catalog.content);
    expect(upgraded.enabled, isFalse);
    expect(upgraded.usageCount, 7);
    expect(upgraded.lastUsedAt, '2026-01-01T00:00:00.000Z');

    final persisted = jsonDecode(store.values[kSkillsSettingKey]!) as List;
    final saved = persisted
        .whereType<Map<String, dynamic>>()
        .map(Skill.fromJson)
        .singleWhere((s) => s.id == catalog.id);
    expect(saved.version, catalog.version);
  });

  test('version 未变时不改写存储，用户技能不受影响', () async {
    const user = Skill(
      id: 'skill-user-1',
      name: '自定义',
      description: '',
      emoji: '🔧',
      tags: [],
      content: '用户内容',
      triggerPhrases: [],
      source: SkillSource.user,
      version: '9.9.9',
      enabled: true,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    );
    final seeded = jsonEncode([
      user.toJson(),
      for (final b in kBuiltinSkills) b.toJson(),
    ]);
    store.values[kSkillsSettingKey] = seeded;

    final skills = await load();
    expect(skills.singleWhere((s) => s.id == user.id).content, '用户内容');
    expect(store.values[kSkillsSettingKey], seeded);
  });
}
