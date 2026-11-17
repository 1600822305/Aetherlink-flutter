import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/storage_access.dart';
import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';

class StorageMediaState {
  const StorageMediaState({this.items = const [], this.isLoading = true,
    this.isBusy = false, this.hasLoaded = false, this.error});
  final List<StorageMedia> items;
  final bool isLoading;
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
