import 'dart:convert';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/knowledge/application/knowledge_recall_history_controller.dart';
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

  KnowledgeRecallHistoryController notifier() =>
      container.read(knowledgeRecallHistoryControllerProvider.notifier);

  test('record 去重并把最新查询放到最前，写穿到 KV 存储', () async {
    notifier()
      ..record('base-1', 'dart')
      ..record('base-1', 'python')
      ..record('base-1', ' dart ');
    expect(notifier().queriesOf('base-1'), ['dart', 'python']);
    expect(notifier().queriesOf('base-2'), isEmpty);
    expect(
      jsonDecode(store.values[kKnowledgeRecallHistoryKey]!),
      {
        'base-1': ['dart', 'python'],
      },
    );
  });

  test('record 超过上限截断，空白查询忽略', () {
    final n = notifier();
    for (var i = 0; i < kKnowledgeRecallHistoryLimit + 3; i++) {
      n.record('base-1', 'q$i');
    }
    n.record('base-1', '   ');
    final queries = n.queriesOf('base-1');
    expect(queries.length, kKnowledgeRecallHistoryLimit);
    expect(queries.first, 'q${kKnowledgeRecallHistoryLimit + 2}');
  });

  test('remove 删除单条，清空后移除该库的键', () {
    notifier()
      ..record('base-1', 'a')
      ..record('base-1', 'b')
      ..remove('base-1', 'b');
    expect(notifier().queriesOf('base-1'), ['a']);
    notifier().remove('base-1', 'a');
    expect(
      jsonDecode(store.values[kKnowledgeRecallHistoryKey]!),
      isEmpty,
    );
  });

  test('build 时从 KV 存储 hydrate，坏值回落为空', () async {
    store.values[kKnowledgeRecallHistoryKey] = jsonEncode({
      'base-1': ['x', 'y'],
      'bad': 'not-a-list',
    });
    // hydrate 是异步的，先读一次触发 build 再等它完成。
    container.read(knowledgeRecallHistoryControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(notifier().queriesOf('base-1'), ['x', 'y']);
    expect(notifier().queriesOf('bad'), isEmpty);
  });
}
