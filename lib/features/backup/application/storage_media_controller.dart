import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/storage_access.dart';
import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media_repository.dart';

class StorageMediaState {
  const StorageMediaState({this.items = const [], this.isLoading = true,
    this.isBusy = false, this.hasLoaded = false, this.isUpdating = false,
    this.error});
  final List<StorageMedia> items;
  final bool isLoading;

  /// 已有内容在显示（缓存 / 快速扫描结果），后台仍在刷新或核对引用。
  final bool isUpdating;
  final bool isBusy;
  final bool hasLoaded;
  final String? error;
}

final storageMediaControllerProvider =
    NotifierProvider<StorageMediaController, StorageMediaState>(StorageMediaController.new);

class StorageMediaController extends Notifier<StorageMediaState> {
  Future<void>? _refreshFuture;

  @override
  StorageMediaState build() => const StorageMediaState();

  bool get isRefreshing => _refreshFuture != null;

  Future<String> blockPayload(String id) =>
      ref.read(storageMediaRepositoryProvider).blockPayload(id);

  Future<void> refresh({bool force = false}) {
    if (state.isBusy) return _refreshFuture ?? Future<void>.value();
    if (force) return _refreshAfterCurrent();
    return _startRefresh();
  }

  Future<void> _refreshAfterCurrent() async {
    await _refreshFuture;
    if (ref.mounted && !state.isBusy) await _startRefresh();
  }

  Future<void> _startRefresh() => _refreshFuture ??=
      Future<void>.microtask(_load).whenComplete(() => _refreshFuture = null);

  Future<void> _load() async {
    if (!ref.mounted) return;
    final repo = ref.read(storageMediaRepositoryProvider);
    if (repo is CachedStorageMediaSource) return _loadFast(repo);
    state = StorageMediaState(items: state.items, hasLoaded: state.hasLoaded,
      isLoading: !state.hasLoaded, isBusy: state.isBusy);
    try {
      final items = await ref.read(storageMediaRepositoryProvider).load();
      if (ref.mounted) state = StorageMediaState(items: items, hasLoaded: true,
        isLoading: false, isBusy: state.isBusy);
    } catch (error) {
      if (ref.mounted) state = StorageMediaState(items: state.items,
        hasLoaded: state.hasLoaded, isLoading: false, isBusy: state.isBusy, error: '$error');
    }
  }

  /// 秒开三段式：① 读上次缓存立即显示 ② 快速扫描（不查引用）替换列表
  /// ③ 一次遍历核对「是否在用」并写回缓存。①② 之后列表就可浏览，
  /// 只有删除要等 ③ 完成（核对中的磁盘文件不可勾选）。
  Future<void> _loadFast(CachedStorageMediaSource repo) async {
    void emit(List<StorageMedia> items, {required bool updating, String? error}) {
      if (!ref.mounted) return;
      state = StorageMediaState(items: items, hasLoaded: true, isLoading: false,
        isUpdating: updating, isBusy: state.isBusy, error: error);
    }

    try {
      if (!state.hasLoaded) {
        final cached = await repo.loadCached();
        if (cached != null) {
          emit([for (final item in cached)
            item.id.startsWith('disk:') ? item.copyWith(usagePending: true) : item],
            updating: true);
        } else if (ref.mounted) {
          state = StorageMediaState(isLoading: true, isBusy: state.isBusy);
        }
      } else {
        emit(state.items, updating: true);
      }
      if (!ref.mounted) return;
      final quick = await repo.scanQuick(previous: state.items);
      emit(quick, updating: true);
      if (!ref.mounted) return;
      emit(await repo.resolveUsage(quick), updating: false);
    } catch (error) {
      if (!ref.mounted) return;
      if (state.hasLoaded) {
        emit(state.items, updating: false, error: '$error');
      } else {
        state = StorageMediaState(isLoading: false, isBusy: state.isBusy,
          error: '$error');
      }
    }
  }

  void selectTopic(StorageMedia item) {
    final topicId = item.topicId;
    if (topicId == null) throw StateError('该块已没有关联话题');
    ref.read(storageTopicSelectionProvider)(topicId, item.assistantId);
  }

  Future<StorageMediaDeletion> deleteUnused(Set<String> ids) async {
    if (state.isBusy || state.isLoading || ref.read(storageControllerProvider).isBusy ||
        ref.read(backupControllerProvider).status == BackupStatus.working) {
      throw StateError('请等待当前存储操作、备份或恢复结束');
    }
    state = StorageMediaState(items: state.items, hasLoaded: state.hasLoaded,
      isLoading: false, isBusy: true);
    try {
      await _refreshFuture;
      if (!ref.mounted) throw StateError('存储管理已关闭');
      return await ref.read(storageMediaRepositoryProvider).deleteUnused(ids);
    } finally {
      if (ref.mounted) {
        await _startRefresh();
        if (ref.mounted) {
          await ref.read(storageControllerProvider.notifier).refresh(force: true);
        }
        if (ref.mounted) {
          state = StorageMediaState(items: state.items, hasLoaded: state.hasLoaded,
            isLoading: false, error: state.error);
        }
      }
    }
  }
}
