import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message_segment.dart';
import 'package:aetherlink_flutter/features/world_book/application/world_book_injector.dart';
import 'package:aetherlink_flutter/features/world_book/data/repositories/world_book_repository_impl.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_binding.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_repository.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_selection.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_turn.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

part 'world_book_access.g.dart';

/// App-level composition seam for the 世界书 repository.
///
/// 与 `memory_access.dart` / `knowledge_access.dart` 同理：仓库实现需要单库
/// Drift 句柄，在组合根里装配，world_book 的 application 层只依赖 domain 接口。
@Riverpod(keepAlive: true)
WorldBookRepository worldBookRepository(Ref ref) =>
    WorldBookRepositoryImpl(ref.watch(appDatabaseProvider).worldBookDao);

/// The world book library for pickers outside the world_book feature (助手
/// 编辑器 / 话题覆盖面板), which may not import its application layer.
@riverpod
Future<List<WorldBook>> worldBookLibrary(Ref ref) =>
    ref.watch(worldBookRepositoryProvider).getAll();

/// Resolves [assistant] / [topic]'s effective 世界书 binding.
WorldBookBinding worldBookBindingFor(Assistant? assistant, Topic? topic) =>
    resolveWorldBookBinding(
      assistantBookIds: assistant?.worldBookIds ?? const <String>[],
      topicBookIds: topic?.worldBookIds,
    );

/// The entries one request triggers (P2：无计时器). [scanTexts] are the
/// request's user / assistant view texts, oldest first. Returns
/// [WorldBookTurn.none] without touching the store when nothing is bound.
Future<WorldBookTurn> collectWorldBookTurn(
  Ref ref, {
  required Assistant? assistant,
  required Topic? topic,
  required List<String> scanTexts,
}) async {
  final binding = worldBookBindingFor(assistant, topic);
  if (binding.ids.isEmpty) return WorldBookTurn.none;
  final books = activeWorldBooks(
    binding,
    await ref.read(worldBookRepositoryProvider).getAll(),
  );
  if (books.isEmpty) return WorldBookTurn.none;
  return WorldBookTurn(
    selectTriggeredWorldBookEntries(books: books, scanTexts: scanTexts),
  );
}

/// [WorldBookInjector.injectSystem] for chat, which may not import the
/// world_book application layer directly.
String? applyWorldBookSystem(String? system, WorldBookTurn turn) =>
    turn.isEmpty ? system : WorldBookInjector.injectSystem(system, turn.triggered);

/// [WorldBookInjector.injectMessages]; an empty [turn] just flattens.
List<LlmMessage> applyWorldBookMessages(
  List<LlmMessageSegment> segments,
  WorldBookTurn turn,
) => turn.isEmpty
    ? [for (final segment in segments) ...segment.messages]
    : WorldBookInjector.injectMessages(segments, turn.triggered);
