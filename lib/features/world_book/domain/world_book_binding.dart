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
}

/// The resolved binding for one conversation: its [source] and the effective
/// book [ids] in binding order.
class WorldBookBinding {
  const WorldBookBinding({required this.source, required this.ids});

  final WorldBookBindingSource source;
  final List<String> ids;
}

/// Resolves the effective binding: a `null` topic list inherits the assistant,
/// an empty one disables world books for the topic, anything else overrides.
WorldBookBinding resolveWorldBookBinding({
  required List<String> assistantBookIds,
  required List<String>? topicBookIds,
}) {
  if (topicBookIds == null) {
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
