import 'package:aetherlink_flutter/features/chat/domain/entities/message.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/message_role.dart';
import 'package:aetherlink_flutter/features/chat/domain/message_ordering.dart';

/// One node's tree placement: its parent and its multi-model sibling group.
/// `parentId == null` marks a first-turn message — the backfill reparents it to
/// the topic's virtual root (see [backfillMessageTree]).
typedef TreePlacement = ({String? parentId, int siblingsGroupId});

/// Builds the message tree from a flat, **chronologically-sorted** message list
/// — a faithful Dart port of Cherry Studio v2's `buildMessageTree`
/// (`src/main/data/migration/v2/migrators/mappings/ChatMappings.ts`). See
/// `docs/design/message-tree-model-design.md` §5/§9.
///
/// It turns the legacy `askId` / `foldSelected` shape into `parentId` +
/// `siblingsGroupId`:
/// - normal sequential messages: `parentId = previous message`;
/// - multi-model replies (same `askId`, count > 1): one shared
///   `siblingsGroupId (>0)`, `parentId = the asked user message`;
/// - a user message following a multi-model group links to the `foldSelected`
///   reply (or the last group member when none was selected);
/// - orphaned groups (the asked user message was deleted) share a fallback
///   parent so siblings stay together.
///
/// First-turn messages get `parentId = null` here; the caller maps that to the
/// virtual-root id.
Map<String, TreePlacement> buildMessageTree(List<Message> messages) {
  final result = <String, TreePlacement>{};
  if (messages.isEmpty) return result;

  // First pass: count messages per askId to spot multi-model groups.
  final askIdCounts = <String, int>{};
  for (final msg in messages) {
    final ask = msg.askId;
    if (ask != null && ask.isNotEmpty) {
      askIdCounts[ask] = (askIdCounts[ask] ?? 0) + 1;
    }
  }

  // Assign a unique group id to each askId with more than one reply. Iterating
  // a LinkedHashMap preserves first-encounter order, so ids are deterministic.
  final askIdToGroupId = <String, int>{};
  var nextGroupId = 1;
  askIdCounts.forEach((ask, count) {
    if (count > 1) askIdToGroupId[ask] = nextGroupId++;
  });

  final knownIds = {for (final m in messages) m.id};

  // Fallback parent for orphaned groups (asked user message deleted): all
  // members share the previousMessageId captured when the first one is seen.
  final orphanedGroupParent = <String, String?>{};

  String? previousMessageId;
  String? lastNonGroupMessageId; // selected/last reply, for linking next user msg
  String? lastGroupFallbackId; // last group member when no foldSelected
  var groupHasFoldSelected = false;

  for (final msg in messages) {
    String? parentId;
    var siblingsGroupId = 0;
    final ask = msg.askId;

    if (ask != null && askIdToGroupId.containsKey(ask)) {
      siblingsGroupId = askIdToGroupId[ask]!;

      if (knownIds.contains(ask)) {
        // Normal multi-model: parent is the asked user message.
        parentId = ask;
      } else {
        // Orphaned multi-model: share a common fallback parent.
        orphanedGroupParent.putIfAbsent(ask, () => previousMessageId);
        parentId = orphanedGroupParent[ask];
      }

      if (msg.foldSelected == true) {
        lastNonGroupMessageId = msg.id;
        groupHasFoldSelected = true;
        // Deviation from Cherry's source (which has a bug here): clear the
        // fallback so a selected reply wins even when an unselected member came
        // before it. This matches Cherry's documented intent ("the user message
        // links to the foldSelected reply"); its code leaves an earlier
        // member's id in lastGroupFallbackId, which `?? ` then wrongly prefers.
        lastGroupFallbackId = null;
      }
      if (!groupHasFoldSelected) {
        lastGroupFallbackId = msg.id;
      }
    } else if (msg.role == MessageRole.user &&
        (lastNonGroupMessageId != null || lastGroupFallbackId != null)) {
      // A user message after a multi-model group links to the selected reply
      // (or the last group member when none was selected — that takes priority).
      parentId = lastGroupFallbackId ?? lastNonGroupMessageId;
      lastNonGroupMessageId = null;
      lastGroupFallbackId = null;
      groupHasFoldSelected = false;
    } else {
      // Normal sequential message.
      parentId = previousMessageId;
    }

    result[msg.id] = (parentId: parentId, siblingsGroupId: siblingsGroupId);

    previousMessageId = msg.id;
    if (siblingsGroupId == 0) {
      lastNonGroupMessageId = msg.id;
      lastGroupFallbackId = null;
      groupHasFoldSelected = false;
    }
  }

  return result;
}

/// The active leaf for a topic after migration — port of Cherry's
/// `findActiveNodeId`. The last message in linear order, preferring the
/// `foldSelected` sibling when the last message belongs to a multi-model group.
String? findActiveNodeId(List<Message> messages) {
  if (messages.isEmpty) return null;
  final last = messages.last;
  final ask = last.askId;
  if (ask != null && ask.isNotEmpty) {
    for (final m in messages) {
      if (m.askId == ask && m.foldSelected == true) return m.id;
    }
  }
  return last.id;
}

/// Projects a topic's flat [content] messages (virtual root already excluded)
/// into the **displayed conversation order** — the Dart analogue of Cherry's
/// `getBranchMessages`. It walks the active path from [activeNodeId] up to
/// [rootId], and for each node on the path that belongs to a multi-model
/// sibling group it **inlines the whole group** (chronologically), so
/// multi-model replies all show. Off-path branches are excluded.
///
/// Returns an empty list when it cannot produce a faithful projection (missing
/// root/active node, a cycle, or the active node not reaching the root). Callers
/// treat that — and any projection that doesn't cover every content message — as
/// a signal to fall back to a plain chronological sort, so no message is ever
/// dropped from the display.
List<Message> orderBranchMessages(
  List<Message> content, {
  required String? rootId,
  required String? activeNodeId,
}) {
  if (rootId == null || activeNodeId == null || content.isEmpty) {
    return const [];
  }
  final byId = {for (final m in content) m.id: m};
  if (!byId.containsKey(activeNodeId)) return const [];

  // Ancestor chain of the active node (the path ids), including itself.
  final pathIds = <String>{};
  String? cur = activeNodeId;
  while (cur != null && cur != rootId) {
    if (!pathIds.add(cur)) return const []; // cycle
    cur = byId[cur]?.parentId;
  }
  if (cur != rootId) return const []; // active node never reaches the root

  final childrenByParent = <String, List<Message>>{};
  for (final m in content) {
    (childrenByParent[m.parentId ?? ''] ??= <Message>[]).add(m);
  }
  for (final list in childrenByParent.values) {
    list.sort(compareMessagesChronologically);
  }

  final result = <Message>[];
  var parent = rootId;
  while (true) {
    final children = childrenByParent[parent];
    if (children == null || children.isEmpty) break;
    Message? found;
    for (final c in children) {
      if (pathIds.contains(c.id)) {
        found = c;
        break;
      }
    }
    if (found == null) break;
    final pathChild = found; // final so it promotes inside the closure below
    // Inline the path node's sibling group (multi-model); otherwise just itself.
    final group = pathChild.siblingsGroupId > 0
        ? children
              .where((c) => c.siblingsGroupId == pathChild.siblingsGroupId)
              .toList()
        : [pathChild];
    result.addAll(group);
    parent = pathChild.id;
  }
  return result;
}

/// Validates a built tree (used by tests and as a migration dry-run check):
/// every content node has a parent, the parent exists (in nodes or is the
/// [rootId]), there are no cycles, and every node reaches the root. Returns the
/// problems found (empty == valid).
List<String> validateTree(
  Map<String, TreePlacement> tree, {
  required String rootId,
}) {
  final problems = <String>[];

  for (final entry in tree.entries) {
    final id = entry.key;
    final parentId = entry.value.parentId;
    if (parentId == null) {
      problems.add('node $id has a null parent (should point at the root)');
      continue;
    }
    if (parentId != rootId && !tree.containsKey(parentId)) {
      problems.add('node $id references missing parent $parentId');
    }
  }

  // Walk each node up to the root; flag cycles / unreachable roots.
  for (final start in tree.keys) {
    final seen = <String>{};
    String? cur = start;
    while (cur != null && cur != rootId) {
      if (!seen.add(cur)) {
        problems.add('cycle detected involving node $cur');
        break;
      }
      cur = tree[cur]?.parentId;
    }
    if (cur == null) {
      problems.add('node $start never reaches the root');
    }
  }

  return problems;
}
