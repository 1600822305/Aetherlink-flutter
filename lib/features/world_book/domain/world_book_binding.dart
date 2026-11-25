import 'dart:convert';

import 'package:aetherlink_flutter/features/world_book/domain/world_book.dart';

/// Where a conversation's effective 世界书 set comes from.
enum WorldBookBindingSource {
  /// The topic has no override (`Topic.worldBookIds == null`): the assistant's
  /// bound books apply.
  assistant,

  /// The topic overrides the assistant with an explicit, non-empty book list.
  topicOverride,

  /// The topic explicitly turns world books off (`Topic.worldBookIds == []`).
  topicDisabled,

  /// Neither topic nor assistant binds anything: the app-wide 全局默认 applies.
  globalDefault,
}

/// The resolved binding for one conversation: its [source] and the effective
/// book [ids] in binding order.
class WorldBookBinding {
  const WorldBookBinding({required this.source, required this.ids});

  final WorldBookBindingSource source;
  final List<String> ids;
}

/// Settings key holding the 全局默认 world book ids (JSON string list).
const String kWorldBookGlobalDefaultKey = 'world_book.global_default_ids';

/// Resolves the effective binding (three levels):
///
/// 1. topic `[]` → disabled; topic non-empty → override;
/// 2. topic `null` → the assistant's bound books, when it has any;
/// 3. assistant binds nothing → [globalBookIds] (全局默认).
///
/// An assistant's **empty** list means "no assistant-specific books", so it
/// falls through to the global default — `Assistant.worldBookIds` cannot tell
/// "unset" from "explicitly none" (it defaults to `[]` for every legacy
/// assistant), and SillyTavern / kelivo both treat global lorebooks as active
/// alongside / beneath per-character ones. A chat that must run without any
/// world book uses the topic-level 「关闭」 (`[]`), which beats everything.
WorldBookBinding resolveWorldBookBinding({
  required List<String> assistantBookIds,
  required List<String>? topicBookIds,
  List<String> globalBookIds = const <String>[],
}) {
  if (topicBookIds == null) {
    if (assistantBookIds.isEmpty && globalBookIds.isNotEmpty) {
      return WorldBookBinding(
        source: WorldBookBindingSource.globalDefault,
        ids: List<String>.unmodifiable(globalBookIds),
      );
    }
    return WorldBookBinding(
      source: WorldBookBindingSource.assistant,
      ids: List<String>.unmodifiable(assistantBookIds),
    );
  }
  if (topicBookIds.isEmpty) {
    return const WorldBookBinding(
      source: WorldBookBindingSource.topicDisabled,
      ids: <String>[],
    );
  }
  return WorldBookBinding(
    source: WorldBookBindingSource.topicOverride,
    ids: List<String>.unmodifiable(topicBookIds),
  );
}

/// The books a [binding] activates: bound, existing and enabled, kept in the
/// library order of [books] (the user's sort order, which is also the
/// injection order). Ids of deleted books are dropped silently.
List<WorldBook> activeWorldBooks(
  WorldBookBinding binding,
  List<WorldBook> books,
) {
  if (binding.ids.isEmpty) return const <WorldBook>[];
  final ids = binding.ids.toSet();
  return [
    for (final book in books)
      if (book.enabled && ids.contains(book.id)) book,
  ];
}

/// Decodes the stored 全局默认 value (a JSON string list); anything malformed
/// reads as "no global default".
List<String> decodeWorldBookGlobalDefault(String? raw) {
  if (raw == null || raw.isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) return const <String>[];
    return [
      for (final id in decoded)
        if (id is String && id.trim().isNotEmpty) id.trim(),
    ];
  } on FormatException {
    return const <String>[];
  }
}

String encodeWorldBookGlobalDefault(List<String> ids) => jsonEncode(ids);
