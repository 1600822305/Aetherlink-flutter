import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/features/backup/data/storage_repository_impl.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_repository.dart';
import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart'
    show chatRepositoryProvider;
import 'package:aetherlink_flutter/features/chat/application/sidebar/topics_providers.dart';
import 'package:aetherlink_flutter/features/notes/application/notes_controller.dart';
import 'package:aetherlink_flutter/features/workspace/application/workspace_store.dart';

final storageRepositoryProvider = Provider<StorageRepository>(
  (ref) => StorageRepositoryImpl(
    ref.watch(appDatabaseProvider),
    notesDirectory: () async =>
        Directory(await ref.read(notesFileStoreProvider).rootPath()),
    workspaceNames: () async => {
      for (final workspace in await ref.read(workspaceStoreProvider.future))
        workspace.id: workspace.name,
    },
    clearImageCache: () =>
        CachedNetworkImageProvider.defaultCacheManager.emptyCache(),
  ),
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
