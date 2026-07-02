import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';

part 'knowledge_recall_history_controller.g.dart';

/// Storage key for the per-base recall-test query history（单个 JSON blob：
/// `{baseId: [query, ...]}`，最近的在前）。
const String kKnowledgeRecallHistoryKey = 'knowledgeRecallHistory';

/// 每个库最多保留的历史查询条数。
const int kKnowledgeRecallHistoryLimit = 10;

/// 召回测试的查询历史（对齐 Cherry Studio 的 RecallHistoryList）：按库记录最近
/// 跑过的查询语句，供「检索测试」面板点选重跑或删除。
///
/// `keepAlive: true`：Drift KV 存储的 JSON blob，首次 build 异步 hydrate，
/// 每次变更写穿，重启后仍在。
@Riverpod(keepAlive: true)
class KnowledgeRecallHistoryController extends _$KnowledgeRecallHistoryController
    with JsonKvNotifier<Map<String, List<String>>> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kKnowledgeRecallHistoryKey;

  @override
  Map<String, List<String>> fromStored(Map<String, dynamic> json) => {
    for (final entry in json.entries)
      if (entry.value is List)
        entry.key: [
          for (final query in entry.value as List)
            if (query is String) query,
        ],
  };

  @override
  Map<String, dynamic> toStored(Map<String, List<String>> value) => value;

  @override
  Map<String, List<String>> build() => hydrate(const {});

  /// [baseId] 库的历史查询（最近的在前），没有则为空列表。
  List<String> queriesOf(String baseId) => state[baseId] ?? const [];

  /// 记录一次查询：去重后插到最前，超过上限截断。
  void record(String baseId, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final queries = [
      trimmed,
      ...queriesOf(baseId).where((q) => q != trimmed),
    ];
    persist({
      ...state,
      baseId: queries.take(kKnowledgeRecallHistoryLimit).toList(),
    });
  }

  /// 删除 [baseId] 库的一条历史查询。
  void remove(String baseId, String query) {
    final queries = queriesOf(baseId).where((q) => q != query).toList();
    final next = {...state};
    if (queries.isEmpty) {
      next.remove(baseId);
    } else {
      next[baseId] = queries;
    }
    persist(next);
  }
}
