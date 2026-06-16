import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/models/data/repositories/model_repository_impl.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_capabilities.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/model_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ModelRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ModelRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  // A provider that exercises every field + a nested `models` list with
  // capabilities / enums / dynamic maps, so the round-trip proves the JSON blob
  // keeps every field (no silent loss).
  const richProvider = ModelProvider(
    id: 'openai',
    name: 'OpenAI',
    avatar: 'O',
    color: '#10a37f',
    isEnabled: true,
    apiKey: 'sk-test',
    baseUrl: 'https://api.openai.com/v1',
    providerType: 'openai',
    isSystem: false,
    extraHeaders: {'X-Org': 'acme'},
    extraBody: {'top_p': 0.9, 'stream': true, 'n': 2},
    models: [
      Model(
        id: 'gpt-4o',
        name: 'GPT-4o',
        provider: 'openai',
        enabled: true,
        isDefault: true,
        description: 'omni',
        capabilities: ModelCapabilities(
          multimodal: true,
          vision: true,
          reasoning: true,
        ),
        modelTypes: [ModelType.chat, ModelType.vision],
        extraHeaders: {'X-Model': 'v'},
        extraBody: {'temperature': 0.2},
      ),
      Model(
        id: 'gpt-4o-mini',
        name: 'GPT-4o Mini',
        provider: 'openai',
        enabled: true,
        isDefault: false,
      ),
    ],
  );

  ModelProvider provider(String id) =>
      ModelProvider(id: id, name: id, avatar: id, color: '#000000');

  group('round-trip', () {
    test('keeps every field of a populated provider', () async {
      await repo.saveProvider(richProvider);

      final loaded = await repo.getProvider('openai');

      expect(loaded, richProvider);
    });

    test('preserves an empty apiKey as "" (not null)', () async {
      const seedLike = ModelProvider(
        id: 'gemini',
        name: 'Gemini',
        avatar: 'G',
        color: '#4285f4',
        apiKey: '',
      );

      await repo.saveProvider(seedLike);

      final loaded = await repo.getProvider('gemini');
      expect(loaded, seedLike);
      expect(loaded!.apiKey, '');
    });
  });

  group('CRUD', () {
    test('getProviders is empty on a fresh store', () async {
      expect(await repo.getProviders(), isEmpty);
    });

    test('getProvider returns null for an unknown id', () async {
      expect(await repo.getProvider('nope'), isNull);
    });

    test('saveProvider inserts and getProvider reads back', () async {
      await repo.saveProvider(provider('a'));

      expect(await repo.getProvider('a'), provider('a'));
      expect(await repo.getProviders(), [provider('a')]);
    });

    test('saveProvider updates an existing provider in place', () async {
      await repo.saveProvider(provider('a'));
      await repo.saveProvider(provider('b'));

      await repo.saveProvider(provider('a').copyWith(name: 'Renamed'));

      final all = await repo.getProviders();
      expect(all.map((p) => p.id), ['a', 'b']);
      expect(all.first.name, 'Renamed');
    });

    test('deleteProvider removes only the target', () async {
      await repo.saveProvider(provider('a'));
      await repo.saveProvider(provider('b'));

      await repo.deleteProvider('a');

      expect((await repo.getProviders()).map((p) => p.id), ['b']);
    });
  });

  group('ordering', () {
    test(
      'getProviders returns providers in insertion (append) order',
      () async {
        await repo.saveProvider(provider('a'));
        await repo.saveProvider(provider('b'));
        await repo.saveProvider(provider('c'));

        expect((await repo.getProviders()).map((p) => p.id), ['a', 'b', 'c']);
      },
    );

    test('reorderProviders applies the new order', () async {
      await repo.saveProvider(provider('a'));
      await repo.saveProvider(provider('b'));
      await repo.saveProvider(provider('c'));

      await repo.reorderProviders(['c', 'a', 'b']);

      expect((await repo.getProviders()).map((p) => p.id), ['c', 'a', 'b']);
    });

    test('updating a provider does not change its position', () async {
      await repo.saveProvider(provider('a'));
      await repo.saveProvider(provider('b'));
      await repo.saveProvider(provider('c'));

      await repo.saveProvider(provider('b').copyWith(color: '#ffffff'));

      expect((await repo.getProviders()).map((p) => p.id), ['a', 'b', 'c']);
    });
  });

  group('setDefaultModel', () {
    const withModels = ModelProvider(
      id: 'openai',
      name: 'OpenAI',
      avatar: 'O',
      color: '#10a37f',
      models: [
        Model(id: 'm1', name: 'M1', provider: 'openai', isDefault: true),
        Model(id: 'm2', name: 'M2', provider: 'openai', isDefault: false),
        Model(id: 'm3', name: 'M3', provider: 'openai', isDefault: false),
      ],
    );

    test('marks the chosen model default and clears the others', () async {
      await repo.saveProvider(withModels);

      await repo.setDefaultModel(providerId: 'openai', modelId: 'm2');

      final models = (await repo.getProvider('openai'))!.models;
      expect(models.firstWhere((m) => m.id == 'm1').isDefault, false);
      expect(models.firstWhere((m) => m.id == 'm2').isDefault, true);
      expect(models.firstWhere((m) => m.id == 'm3').isDefault, false);
    });

    test('is a no-op for an unknown provider', () async {
      await repo.setDefaultModel(providerId: 'ghost', modelId: 'm1');

      expect(await repo.getProviders(), isEmpty);
    });
  });
}
