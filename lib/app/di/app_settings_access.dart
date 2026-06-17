import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

part 'app_settings_access.g.dart';

/// App-level composition seam for the key/value settings store (the port of the
/// web `dexieStorage.getSetting` / `saveSetting`).
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's
/// `application` / `data`; only its `domain` is allowed. The single Drift-backed
/// KV store is reached through [ChatRepository] (chat's `application`), so any
/// non-chat feature that needs to persist a preference composes it here in
/// `app/` (the composition root, which may depend on any feature). Consumers
/// import this file plus chat's pure-Dart `domain` [ChatRepository] type — never
/// `chat/application` directly.
///
/// Delegates to chat's own repository provider, so there is a single repository
/// instance (and a single Drift handle) behind every read/write.
@Riverpod(keepAlive: true)
ChatRepository appSettingsStore(Ref ref) => ref.watch(chatRepositoryProvider);
