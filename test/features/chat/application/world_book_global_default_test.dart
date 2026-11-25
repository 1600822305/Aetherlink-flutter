import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/di/world_book_access.dart';
import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar_controllers.dart';
import 'package:aetherlink_flutter/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_cancel_token.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_chat_request.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_gateway_factory.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_stream_chunk.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/features/world_book/data/repositories/world_book_repository_impl.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_binding.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

class _Gateway implements LlmGateway {
  final List<LlmChatRequest> requests = [];

  @override
  Stream<LlmStreamChunk> streamChat(
    LlmChatRequest request, {
    LlmCancelToken? cancelToken,
  }) async* {
    requests.add(request);
    yield const LlmStreamChunk.textDelta('ok');
    yield const LlmStreamChunk.done();
  }
}

class _Factory implements LlmGatewayFactory {
  _Factory(this.gateway);

  final LlmGateway gateway;

  @override
  LlmGateway forModel(Model model) => gateway;
}

const _provider = ModelProvider(
  id: 'p1',
  name: 'Test',
  avatar: 'T',
  color: '#000000',
  apiKey: 'sk-test',
  baseUrl: 'https://example.test',
  providerType: 'openai',
);
const _model = CurrentModel(
  provider: _provider,
  model: Model(id: 'gpt', name: 'GPT', provider: 'Test', isDefault: true),
);

WorldBook _constantBook(String id) => WorldBook(
  id: id,
  name: id,
  entries: [
    WorldBookEntry(
      id: 'e',
      name: id,
      content: 'LORE-$id',
      constant: true,
      position: WorldBookInjectionPosition.beforeSystemPrompt,
    ),
  ],
);

void main() {
  late AppDatabase db;
  late ChatRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ChatRepositoryImpl(db);
  });
  tearDown(() => db.close());

  Future<(ProviderContainer, _Gateway)> setUpChat({
    required List<String> assistantBooks,
    required List<String> globalBooks,
    Topic? topic,
  }) async {
    await repo.saveAssistant(
      Assistant(
        id: 'default-assistant',
        name: 'A',
        systemPrompt: 'PERSONA',
        worldBookIds: assistantBooks,
      ),
    );
    final wb = WorldBookRepositoryImpl(db.worldBookDao);
    await wb.save(_constantBook('assistant-book'));
    await wb.save(_constantBook('global-book'));
    await repo.saveSetting(
      kWorldBookGlobalDefaultKey,
      encodeWorldBookGlobalDefault(globalBooks),
    );
    final gateway = _Gateway();
    final container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        llmGatewayFactoryProvider.overrideWithValue(_Factory(gateway)),
        currentTopicProvider.overrideWith((ref) async => topic),
        appCurrentModelProvider.overrideWith((ref) async => _model),
        appModelProvidersProvider.overrideWith(
          (ref) async => const <ModelProvider>[_provider],
        ),
        worldBookRepositoryProvider.overrideWithValue(wb),
      ],
    );
    addTearDown(container.dispose);
    await container.read(chatControllerProvider.future);
    return (container, gateway);
  }

  test('an assistant with no books uses the global default', () async {
    final (container, gateway) = await setUpChat(
      assistantBooks: const [],
      globalBooks: const ['global-book'],
    );
    await container.read(chatControllerProvider.notifier).send('hi');
    expect(gateway.requests.single.system, contains('LORE-global-book'));
  });

  test('assistant books beat the global default', () async {
    final (container, gateway) = await setUpChat(
      assistantBooks: const ['assistant-book'],
      globalBooks: const ['global-book'],
    );
    await container.read(chatControllerProvider.notifier).send('hi');
    final system = gateway.requests.single.system!;
    expect(system, contains('LORE-assistant-book'));
    expect(system, isNot(contains('LORE-global-book')));
  });

  test('dangling ids (e.g. after restoring assistants only) are ignored', () async {
    final (container, gateway) = await setUpChat(
      assistantBooks: const ['restored-but-missing'],
      globalBooks: const ['also-missing'],
    );
    await container.read(chatControllerProvider.notifier).send('hi');
    final system = gateway.requests.single.system ?? '';
    expect(system, isNot(contains('LORE-')));
  });

  test('the global default can be updated through its notifier', () async {
    final (container, _) = await setUpChat(
      assistantBooks: const [],
      globalBooks: const [],
    );
    await container
        .read(worldBookGlobalDefaultProvider.notifier)
        .setIds(const ['global-book', 'global-book', ' ']);
    expect(await container.read(worldBookGlobalDefaultProvider.future), [
      'global-book',
    ]);
    expect(
      decodeWorldBookGlobalDefault(
        await repo.getSetting(kWorldBookGlobalDefaultKey),
      ),
      ['global-book'],
    );
  });

  test('copying an assistant carries its worldBookIds', () async {
    final (container, _) = await setUpChat(
      assistantBooks: const ['assistant-book'],
      globalBooks: const [],
    );
    final source = (await repo.getAssistant('default-assistant'))!;
    await container.read(assistantsProvider.future);
    await container.read(assistantsProvider.notifier).copy(source);
    final copies = (await repo.getAllAssistants())
        .where((a) => a.id != source.id)
        .toList();
    expect(copies, hasLength(1));
    expect(copies.single.name, 'A (复制)');
    expect(copies.single.worldBookIds, ['assistant-book']);
  });
}
