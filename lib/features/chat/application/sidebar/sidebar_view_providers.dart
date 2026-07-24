import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/chat/application/sidebar/assistants_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/groups_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/sidebar_selection_providers.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/topic_defaults.dart';
import 'package:aetherlink_flutter/features/chat/application/sidebar/topics_providers.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';
import 'package:aetherlink_flutter/shared/domain/group.dart';
import 'package:aetherlink_flutter/shared/domain/topic.dart';
import 'package:aetherlink_flutter/shared/utils/pinyin_sort.dart';

part 'sidebar_view_providers.g.dart';

/// The current assistant: the selected one, else the first (web fallback
/// `setCurrentAssistant(defaultAssistants[0])`). `null` only when none exist.
@riverpod
Assistant? currentAssistant(Ref ref) {
  final list =
      ref.watch(assistantsProvider).asData?.value ?? const <Assistant>[];
  if (list.isEmpty) return null;
  final id = ref.watch(currentAssistantIdProvider);
  if (id != null) {
    for (final a in list) {
      if (a.id == id) return a;
    }
  }
  return list.first;
}

/// The current assistant's topics, sorted pinned-first then most-recent.
@riverpod
List<Topic> currentAssistantTopics(Ref ref) {
  final assistant = ref.watch(currentAssistantProvider);
  if (assistant == null) return const <Topic>[];
  final topics = ref.watch(topicsProvider).asData?.value ?? const <Topic>[];
  final mine = topics.where((t) => t.assistantId == assistant.id).toList();
  mine.sort(compareTopicsByRecency);
  return mine;
}

/// Topic count per assistant id, for the 助手 list's "N 个话题" subtitle.
@riverpod
Map<String, int> topicCountByAssistant(Ref ref) {
  final topics = ref.watch(topicsProvider).asData?.value ?? const <Topic>[];
  final counts = <String, int>{};
  for (final t in topics) {
    counts[t.assistantId] = (counts[t.assistantId] ?? 0) + 1;
  }
  return counts;
}

/// Assistant folders, ascending by display order.
@riverpod
List<Group> assistantGroups(Ref ref) {
  final groups = ref.watch(groupsProvider).asData?.value ?? const <Group>[];
  final list = groups.where((g) => g.type == GroupType.assistant).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return list;
}

/// Assistants not in any assistant folder ("未分组助手").
@riverpod
List<Assistant> ungroupedAssistants(Ref ref) {
  final assistants =
      ref.watch(assistantsProvider).asData?.value ?? const <Assistant>[];
  final grouped = <String>{
    for (final g in ref.watch(assistantGroupsProvider)) ...g.items,
  };
  final ungrouped = assistants.where((a) => !grouped.contains(a.id)).toList();

  final order = ref.watch(assistantSortOrderControllerProvider);
  if (order != AssistantSortOrder.none) {
    ungrouped.sort((a, b) {
      final cmp = pinyinSortKey(a.name).compareTo(pinyinSortKey(b.name));
      return order == AssistantSortOrder.asc ? cmp : -cmp;
    });
  }
  return ungrouped;
}

/// Topic folders for [assistantId], ascending by display order.
@riverpod
List<Group> topicGroups(Ref ref, String assistantId) {
  final groups = ref.watch(groupsProvider).asData?.value ?? const <Group>[];
  final list =
      groups
          .where(
            (g) => g.type == GroupType.topic && g.assistantId == assistantId,
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
  return list;
}

/// The current assistant's topics not in any of its topic folders ("未分组话题").
@riverpod
List<Topic> ungroupedTopics(Ref ref) {
  final assistant = ref.watch(currentAssistantProvider);
  if (assistant == null) return const <Topic>[];
  final grouped = <String>{
    for (final g in ref.watch(topicGroupsProvider(assistant.id))) ...g.items,
  };
  return ref
      .watch(currentAssistantTopicsProvider)
      .where((t) => !grouped.contains(t.id))
      .toList();
}
