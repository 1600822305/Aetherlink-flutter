import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/features/backup/data/storage_repository_impl.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_repository.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart'
    show chatRepositoryProvider;
import 'package:aetherlink_flutter/features/chat/application/sidebar/topics_providers.dart';

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => StorageRepositoryImpl(ref.watch(appDatabaseProvider)),
);

final storageTopicDeletionProvider = Provider<Future<void> Function(String)>(
  (ref) => (id) async {
    await ref.read(topicsProvider.future);
    await ref.read(topicsProvider.notifier).delete(id);
    if (await ref.read(chatRepositoryProvider).getTopic(id) != null) {
      throw StateError('话题仍在生成中，本次未删除，请等待生成结束后重试');
    }
  },
);
