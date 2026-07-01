import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/chat_providers.dart';
import 'package:aetherlink_flutter/features/knowledge/data/knowledge_service.dart';

part 'knowledge_access.g.dart';

/// App-level composition seam exposing [KnowledgeService].
///
/// Mirrors `memory_access.dart`: the import-boundary rule forbids the knowledge
/// feature from importing chat's `application`, but the single app-wide Drift
/// handle lives behind chat's `appDatabaseProvider`. So the service is composed
/// here in `app/` (the composition root) and the feature reaches it through
/// this seam.
@Riverpod(keepAlive: true)
KnowledgeService knowledgeService(Ref ref) =>
    KnowledgeService(ref.watch(appDatabaseProvider).knowledgeDao);
