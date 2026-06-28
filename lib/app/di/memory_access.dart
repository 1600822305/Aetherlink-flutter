import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/memory/data/chat_memory_store.dart';

part 'memory_access.g.dart';

/// App-level composition seam exposing the 普通聊天 memory store.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's
/// `application` / `data`; only its `domain` is allowed. [ChatMemoryStore] needs
/// the single app-wide Drift handle, which lives behind chat's
/// `appDatabaseProvider` (chat's `application`). So the store is composed here in
/// `app/` (the composition root, which may depend on any feature) and the memory
/// feature reaches it through this seam instead of importing `chat/application`
/// directly.
@Riverpod(keepAlive: true)
ChatMemoryStore chatMemoryStore(Ref ref) =>
    ChatMemoryStore(ref.watch(appDatabaseProvider).memoryDao);
