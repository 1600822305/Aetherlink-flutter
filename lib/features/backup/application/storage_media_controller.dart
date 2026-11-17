import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/storage_access.dart';
import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';

class StorageMediaState {
  const StorageMediaState({this.items = const [], this.isLoading = true,
    this.isBusy = false, this.error});
  final List<StorageMedia> items;
  final bool isLoading;
  final bool isBusy;
  final String? error;
}

final storageMediaControllerProvider =
    NotifierProvider<StorageMediaController, StorageMediaState>(StorageMediaController.new);

class StorageMediaController extends Notifier<StorageMediaState> {
  bool _isRefreshing = false;

  @override
  StorageMediaState build() => const StorageMediaState();

  Future<String> blockPayload(String id) =>
      ref.read(storageMediaRepositoryProvider).blockPayload(id);

  Future<void> refresh() async {
    if (state.isBusy || _isRefreshing) return;
    _isRefreshing = true;
    state = const StorageMediaState();
    try {
      final items = await ref.read(storageMediaRepositoryProvider).load();
      if (ref.mounted) state = StorageMediaState(items: items, isLoading: false);
    } catch (error) {
      if (ref.mounted) state = StorageMediaState(isLoading: false, error: '$error');
    } finally {
      _isRefreshing = false;
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
    state = StorageMediaState(items: state.items, isLoading: false, isBusy: true);
    try {
      return await ref.read(storageMediaRepositoryProvider).deleteUnused(ids);
    } finally {
      if (ref.mounted) {
        state = StorageMediaState(items: state.items, isLoading: false);
        await refresh();
        if (ref.mounted) await ref.read(storageControllerProvider.notifier).refresh();
      }
    }
  }
}
