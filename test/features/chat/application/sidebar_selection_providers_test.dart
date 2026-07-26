import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_selection_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

/// A [ChatRepository] fake that only implements the settings key/value store,
/// with a [Completer]-gated [getSetting] so tests can hold hydration open and
/// release it after the provider has been touched.
class _SettingsRepo implements ChatRepository {
  _SettingsRepo(this.settings);

  final Map<String, String> settings;
  final Completer<void> gate = Completer<void>();

  @override
  Future<String?> getSetting(String key) async {
    await gate.future;
    return settings[key];
  }

  @override
  Future<void> saveSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  ProviderContainer makeContainer(_SettingsRepo repo) {
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('CurrentTopicId', () {
    test('hydrates the persisted topic id when untouched', () async {
      final repo = _SettingsRepo({kCurrentTopicSettingKey: 'topic-old'});
      final container = makeContainer(repo);

      expect(container.read(currentTopicIdProvider), isNull);
      repo.gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(currentTopicIdProvider), 'topic-old');
    });

    test('set() before hydrate completes wins over the stored value', () async {
      final repo = _SettingsRepo({kCurrentTopicSettingKey: 'topic-old'});
      final container = makeContainer(repo);

      // User (or Topics.create) selects a topic before hydration finishes.
      container.read(currentTopicIdProvider.notifier).set('topic-new');
      repo.gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(currentTopicIdProvider), 'topic-new');
      expect(repo.settings[kCurrentTopicSettingKey], 'topic-new');
    });

    test('set(null) before hydrate completes also blocks the stored value',
        () async {
      final repo = _SettingsRepo({kCurrentTopicSettingKey: 'topic-old'});
      final container = makeContainer(repo);

      container.read(currentTopicIdProvider.notifier).set(null);
      repo.gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(currentTopicIdProvider), isNull);
    });
  });

  group('CurrentAssistantId', () {
    test('hydrates the persisted assistant id when untouched', () async {
      final repo = _SettingsRepo({kCurrentAssistantSettingKey: 'asst-old'});
      final container = makeContainer(repo);

      expect(container.read(currentAssistantIdProvider), isNull);
      repo.gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(currentAssistantIdProvider), 'asst-old');
    });

    test('set() before hydrate completes wins over the stored value', () async {
      final repo = _SettingsRepo({kCurrentAssistantSettingKey: 'asst-old'});
      final container = makeContainer(repo);

      container.read(currentAssistantIdProvider.notifier).set('asst-new');
      repo.gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(currentAssistantIdProvider), 'asst-new');
      expect(repo.settings[kCurrentAssistantSettingKey], 'asst-new');
    });
  });
}
