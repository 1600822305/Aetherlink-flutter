import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/core/database/database_provider.dart';
import 'package:aetherlink_flutter/features/chat/domain/token_estimate.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message.dart';
import 'package:aetherlink_flutter/features/chat/domain/gateways/llm_message_segment.dart';
import 'package:aetherlink_flutter/features/world_book/application/world_book_injector.dart';
import 'package:aetherlink_flutter/features/world_book/data/repositories/world_book_repository_impl.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_binding.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_repository.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_activation_state.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_entry.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_macros.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_scan_context.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_settings.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_timed_selection.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_turn.dart';
import 'package:aetherlink_flutter/features/world_book/domain/world_book_turn_state.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';

export 'package:aetherlink_flutter/features/world_book/domain/world_book_scan_context.dart'
    show WorldBookTrigger;

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

/// The 全局默认 world book ids (settings key [kWorldBookGlobalDefaultKey]),
/// the third binding level below topic and assistant. Hydrates from the KV
/// store on first build; [setIds] writes through.
@Riverpod(keepAlive: true)
class WorldBookGlobalDefault extends _$WorldBookGlobalDefault {
  @override
  Future<List<String>> build() async => decodeWorldBookGlobalDefault(
    await ref.read(appSettingsStoreProvider).getSetting(
      kWorldBookGlobalDefaultKey,
    ),
  );

  Future<void> setIds(List<String> ids) async {
    final clean = [
      for (final id in ids.toSet())
        if (id.trim().isNotEmpty) id.trim(),
    ];
    await ref
        .read(appSettingsStoreProvider)
        .saveSetting(
          kWorldBookGlobalDefaultKey,
          encodeWorldBookGlobalDefault(clean),
        );
    state = AsyncData(List<String>.unmodifiable(clean));
  }
}

/// 世界书全局设置（ST `world_info_*`），存应用设置 KV 的 [kWorldBookSettingsKey]。
/// 界面用它读写；发送时用 [readWorldBookSettings]（等存储读完，不受 hydrate
/// 时序影响）。
@Riverpod(keepAlive: true)
class WorldBookSettingsController extends _$WorldBookSettingsController
    with JsonKvNotifier<WorldBookSettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kWorldBookSettingsKey;

  @override
  WorldBookSettings fromStored(Map<String, dynamic> json) =>
      WorldBookSettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(WorldBookSettings value) => value.toJson();

  @override
  WorldBookSettings build() => hydrate(WorldBookSettings.defaults);

  void update(WorldBookSettings next) => persist(next);

  void reset() => persist(WorldBookSettings.defaults);
}

/// 发送时读取全局设置：直接读存储，损坏或缺失时用 ST 默认值，从不抛异常。
Future<WorldBookSettings> readWorldBookSettings(Ref ref) async {
  try {
    final raw = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kWorldBookSettingsKey);
    if (raw == null || raw.isEmpty) return WorldBookSettings.defaults;
    return WorldBookSettings.fromJson(jsonDecode(raw));
  } on Object {
    return WorldBookSettings.defaults;
  }
}

/// Resolves [assistant] / [topic]'s effective 世界书 binding — the single
/// resolver every injection path and the 扩展 menu go through.
/// [globalBookIds] is the 全局默认 level (see [resolveWorldBookBinding]).
WorldBookBinding worldBookBindingFor(
  Assistant? assistant,
  Topic? topic, {
  List<String> globalBookIds = const <String>[],
}) => resolveWorldBookBinding(
  assistantBookIds: assistant?.worldBookIds ?? const <String>[],
  topicBookIds: topic?.worldBookIds,
  globalBookIds: globalBookIds,
);

/// Reads the 全局默认 ids for a request (awaits hydration; never throws).
Future<List<String>> readWorldBookGlobalDefault(Ref ref) async {
  try {
    return await ref.read(worldBookGlobalDefaultProvider.future);
  } on Object {
    return const <String>[];
  }
}

/// The entries one request triggers, with sticky / cooldown / delay applied
/// (P3). [scanTexts] are the request's user / assistant view texts, oldest
/// first; [clock] is this turn's inherited state + turn number (see
/// [resolveWorldBookClock]). Returns [WorldBookTurn.none] without touching the
/// store when nothing is bound.
Future<WorldBookTurn> collectWorldBookTurn(
  Ref ref, {
  required Assistant? assistant,
  required Topic? topic,
  required List<String> scanTexts,
  WorldBookClock? clock,
  List<String> globalBookIds = const <String>[],
  WorldBookMacroContext? macros,
  WorldBookSettings settings = WorldBookSettings.defaults,
  String trigger = WorldBookTrigger.normal,
}) async {
  final binding = worldBookBindingFor(
    assistant,
    topic,
    globalBookIds: globalBookIds,
  );
  if (binding.ids.isEmpty) return WorldBookTurn.none;
  final books = activeWorldBooks(
    binding,
    await ref.read(worldBookRepositoryProvider).getAll(),
  );
  if (books.isEmpty) return WorldBookTurn.none;
  final result = selectTimedWorldBookEntries(
    books: books,
    scanTexts: scanTexts,
    turn: clock?.turn ?? 1,
    previous: clock?.previous ?? WorldBookActivationState.empty,
    macros: macros,
    settings: settings,
    trigger: trigger,
    // 角色 = 当前助手：名字与 id 参与名字筛选，标签参与标签筛选。
    character: assistant == null
        ? null
        : WorldBookCharacter(
            names: [assistant.name, assistant.id],
            tags: assistant.tags,
          ),
    // Outlet 只在助手 / 话题提示词里展开，没被引用的不参与。
    outletNames: worldBookOutletNamesIn([assistant?.systemPrompt, topic?.prompt]),
    sources: WorldBookScanSources(
      characterDescription: assistant?.systemPrompt ?? '',
      characterPersonality: assistant?.description ?? '',
      scenario: topic?.prompt ?? '',
    ),
    // 预算按 ST 的方式计 token；上下文长度暂不可知，只受 budgetCap 约束。
    countTokens: estimateTokens,
  );
  return WorldBookTurn(
    result.entries,
    state: result.state,
    reasons: result.reasons,
  );
}

/// [resolveWorldBookClock] over a path given as `(isUserTurn, isSummary,
/// metadata)` nodes — re-exported so chat need not import world_book domain
/// internals beyond the record type.
WorldBookClock worldBookClockFor(List<WorldBookPathNode> ancestors) =>
    resolveWorldBookClock(ancestors);

/// [metadata] with [turn]'s timer state written under the activation key, or
/// null when the turn carries no state (nothing bound → metadata untouched).
Map<String, dynamic>? worldBookMetadataFor(
  Map<String, dynamic>? metadata,
  WorldBookTurn turn,
) => turn.state?.writeTo(metadata);

/// The newest timer state among compressed messages (oldest first), so the
/// compression summary can inherit it.
WorldBookActivationState? worldBookStateToCarry(
  List<Map<String, dynamic>?> metadataOldestFirst,
) => latestWorldBookState(metadataOldestFirst);

/// The text a turn injects (system + chat positions), for token estimates and
/// the 本轮注入 block.
String worldBookInjectedText(WorldBookTurn turn) => [
  for (final WorldBookEntry e in turn.triggered)
    if (e.content.trim().isNotEmpty) e.content.trim(),
].join('\n');

/// [WorldBookInjector.injectSystem] for chat, which may not import the
/// world_book application layer directly.
///
/// 没有绑定任何世界书（[WorldBookTurn.none]，`state` 为 null）时原样返回，
/// 不用世界书的用户提示词里即使写了 `{{outlet::…}}` 也不会被改动；绑定了但
/// 本轮没触发条目时，`{{outlet::…}}` 替换为空（同 ST）。
String? applyWorldBookSystem(String? system, WorldBookTurn turn) =>
    turn.state == null && turn.isEmpty
    ? system
    : WorldBookInjector.injectSystem(system, turn.triggered);

/// [WorldBookInjector.injectMessages]; an empty [turn] just flattens. Adjacent
/// plain user turns are merged per [kWorldBookMergeAdjacentUser].
///
/// [nativeSystem]: whether the target protocol accepts mid-chat `system`
/// messages (OpenAI-compatible does; Anthropic / Gemini do not — see
/// [WorldBookInjector]). Defaults to the degraded form.
List<LlmMessage> applyWorldBookMessages(
  List<LlmMessageSegment> segments,
  WorldBookTurn turn, {
  bool nativeSystem = false,
}) => turn.isEmpty
    ? [for (final segment in segments) ...segment.messages]
    : WorldBookInjector.injectMessages(
        segments,
        turn.triggered,
        mergeAdjacentUser: kWorldBookMergeAdjacentUser,
        nativeSystem: nativeSystem,
      );

/// The 扩展 menu's 世界书 status for a binding: whether any book is in effect,
/// how many books, and how many of their entries are enabled.
typedef WorldBookMenuStatus = ({bool isOn, int bookCount, int entryCount});

/// Computes [WorldBookMenuStatus] for [assistant] / [topic] against the
/// library [books]. Pure, so the chat-side provider (which owns the current
/// topic / assistant) can derive it synchronously from loaded values.
WorldBookMenuStatus worldBookMenuStatusOf(
  Assistant? assistant,
  Topic? topic,
  List<WorldBook> books, {
  List<String> globalBookIds = const <String>[],
}) {
  final active = activeWorldBooks(
    worldBookBindingFor(assistant, topic, globalBookIds: globalBookIds),
    books,
  );
  var entries = 0;
  for (final book in active) {
    entries += book.enabledEntryCount;
  }
  return (isOn: active.isNotEmpty, bookCount: active.length, entryCount: entries);
}
