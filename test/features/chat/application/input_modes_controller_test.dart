import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

class _SettingsRepo implements ChatRepository {
  _SettingsRepo(this.settings, {this.readError});

  final Map<String, String> settings;
  final Object? readError;
  final Completer<void> gate = Completer<void>();

  @override
  Future<String?> getSetting(String key) async {
    final stored = settings[key];
    await gate.future;
    final error = readError;
    if (error != null) throw error;
    return stored;
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

  Future<void> hydrate(ProviderContainer container, _SettingsRepo repo) async {
    final controller = container.read(inputModeControllerProvider.notifier);
    repo.gate.complete();
    await controller.hydrated;
  }

  for (final mode in [InputMode.image, InputMode.video, InputMode.audio]) {
    test('${mode.name} selection survives a fresh container', () async {
      final settings = <String, String>{};
      final repo = _SettingsRepo(settings);
      final container = makeContainer(repo);
      await hydrate(container, repo);

      container.read(inputModeControllerProvider.notifier).set(mode);

      expect(settings[kMediaInputModeSettingKey], mode.name);
      final restartedRepo = _SettingsRepo(settings);
      final restarted = makeContainer(restartedRepo);
      await hydrate(restarted, restartedRepo);
      expect(restarted.read(inputModeControllerProvider), mode);
    });

    test('toggling ${mode.name} off clears its persisted mode', () async {
      final repo = _SettingsRepo({kMediaInputModeSettingKey: mode.name});
      final container = makeContainer(repo);
      await hydrate(container, repo);

      container.read(inputModeControllerProvider.notifier).toggle(mode);

      expect(container.read(inputModeControllerProvider), isNull);
      expect(repo.settings[kMediaInputModeSettingKey], '');
    });
  }

  for (final stored in <String?>[null, '', 'webSearch', 'unknown']) {
    test('does not restore non-media setting "$stored"', () async {
      final repo = _SettingsRepo({
        if (stored != null) kMediaInputModeSettingKey: stored,
      });
      final container = makeContainer(repo);

      await hydrate(container, repo);

      expect(container.read(inputModeControllerProvider), isNull);
    });
  }

  for (final useToggle in [false, true]) {
    test('web search stays session-only (toggle: $useToggle)', () async {
      final settings = {kMediaInputModeSettingKey: 'image'};
      final repo = _SettingsRepo(settings);
      final container = makeContainer(repo);
      await hydrate(container, repo);
      final controller = container.read(inputModeControllerProvider.notifier);

      if (useToggle) {
        controller.toggle(InputMode.webSearch);
      } else {
        controller.set(InputMode.webSearch);
      }

      expect(container.read(inputModeControllerProvider), InputMode.webSearch);
      expect(settings[kMediaInputModeSettingKey], '');
      final restartedRepo = _SettingsRepo(settings);
      final restarted = makeContainer(restartedRepo);
      await hydrate(restarted, restartedRepo);
      expect(restarted.read(inputModeControllerProvider), isNull);
    });
  }

  test('clear persists after restart without clearing model slots', () async {
    final settings = {
      kMediaInputModeSettingKey: 'image',
      'media_image_model': 'provider\u0000image-model',
    };
    final repo = _SettingsRepo(settings);
    final container = makeContainer(repo);
    await hydrate(container, repo);

    container.read(inputModeControllerProvider.notifier).clear();

    expect(settings[kMediaInputModeSettingKey], '');
    expect(settings['media_image_model'], 'provider\u0000image-model');
    final restartedRepo = _SettingsRepo(settings);
    final restarted = makeContainer(restartedRepo);
    await hydrate(restarted, restartedRepo);
    expect(restarted.read(inputModeControllerProvider), isNull);
  });

  for (final mode in <InputMode?>[
    InputMode.video,
    InputMode.webSearch,
    null,
  ]) {
    test('explicit selection $mode wins over pending hydration', () async {
      final repo = _SettingsRepo({kMediaInputModeSettingKey: 'image'});
      final container = makeContainer(repo);
      final controller = container.read(inputModeControllerProvider.notifier);

      controller.set(mode);
      await hydrate(container, repo);

      expect(container.read(inputModeControllerProvider), mode);
      expect(
        repo.settings[kMediaInputModeSettingKey],
        mode == InputMode.video ? 'video' : '',
      );
    });
  }

  test('read failure finishes hydration without changing selection', () async {
    final repo = _SettingsRepo({}, readError: StateError('read failed'));
    final container = makeContainer(repo);

    await hydrate(container, repo);

    expect(container.read(inputModeControllerProvider), isNull);
  });

  test('pending hydration can finish after disposal', () async {
    final repo = _SettingsRepo({kMediaInputModeSettingKey: 'image'});
    final container = ProviderContainer(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
    );
    final controller = container.read(inputModeControllerProvider.notifier);
    final hydrated = controller.hydrated;

    container.dispose();
    repo.gate.complete();

    await hydrated;
  });
}
