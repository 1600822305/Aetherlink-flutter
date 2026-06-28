import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';
import 'package:aetherlink_flutter/app/di/json_kv_notifier.dart';
import 'package:aetherlink_flutter/features/chat/domain/repositories/chat_repository.dart';
import 'package:aetherlink_flutter/features/memory/domain/memory_settings.dart';

part 'memory_settings_controller.g.dart';

/// Storage key for the persisted 记忆 settings (a single JSON blob, mirroring
/// how the web kept memory config inside `settings`).
const String kMemorySettingsKey = 'memorySettings';

/// Holds the 聊天记忆 settings so the 记忆 pages stay pure views and the chat
/// pipeline (auto-extract + injection) can read them.
///
/// `keepAlive: true`: an app-level preference shared by the memory pages and the
/// chat pipeline. Hydrated from the Drift key/value store on first build and
/// written through on every change so the configuration survives a restart.
@Riverpod(keepAlive: true)
class MemorySettingsController extends _$MemorySettingsController
    with JsonKvNotifier<MemorySettings> {
  @override
  ChatRepository get kvStore => ref.read(appSettingsStoreProvider);

  @override
  String get storageKey => kMemorySettingsKey;

  @override
  MemorySettings fromStored(Map<String, dynamic> json) =>
      MemorySettings.fromJson(json);

  @override
  Map<String, dynamic> toStored(MemorySettings value) => value.toJson();

  @override
  MemorySettings build() => hydrate(const MemorySettings());

  /// Toggles the 启用记忆 master switch.
  void setEnabled(bool value) => persist(state.copyWith(enabled: value));

  /// Toggles 自动记忆 · 私有 (auto-extract into the current assistant's memory).
  void setAutoWritePrivate(bool value) =>
      persist(state.copyWith(autoWritePrivate: value));

  /// Toggles 自动记忆 · 全局 (allow auto-extract into global memory).
  void setAutoWriteGlobal(bool value) =>
      persist(state.copyWith(autoWriteGlobal: value));

  /// Sets the memory injection mode (记忆设置 sub-page).
  void setInjectionMode(MemoryInjectionMode mode) =>
      persist(state.copyWith(injectionMode: mode));

  /// Sets the per-turn token budget for injected memories (clamped ≥ 0).
  void setTokenBudget(int value) =>
      persist(state.copyWith(tokenBudget: value < 0 ? 0 : value));

  /// Sets how many memories vector retrieval injects (clamped ≥ 1).
  void setTopK(int value) =>
      persist(state.copyWith(topK: value < 1 ? 1 : value));

  /// Sets the collection size below which `auto` falls back to a full dump
  /// (clamped ≥ 0).
  void setFullDumpThreshold(int value) =>
      persist(state.copyWith(fullDumpThreshold: value < 0 ? 0 : value));

  /// Sets how many days a soft-deleted memory is kept before 整理记忆 purges it
  /// (clamped ≥ 0).
  void setRetentionDays(int value) =>
      persist(state.copyWith(retentionDays: value < 0 ? 0 : value));

  /// Sets the embedding model (`providerId:modelId`) for semantic retrieval;
  /// null clears it (semantic/auto then fall back to keyword matching).
  void setEmbeddingModelKey(String? key) => persist(
    state.copyWith(embeddingModelKey: (key == null || key.isEmpty) ? null : key),
  );

  /// Records when the last 整理记忆 (consolidation) run finished.
  void setLastConsolidated(int epochMillis) =>
      persist(state.copyWith(lastConsolidatedAt: epochMillis));

  /// 实验性: toggles native sqlite-vec KNN retrieval (off → Dart cosine path).
  void setUseSqliteVec(bool value) =>
      persist(state.copyWith(useSqliteVec: value));
}
