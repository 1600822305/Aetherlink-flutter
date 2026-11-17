import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/storage_access.dart';
import 'package:aetherlink_flutter/features/backup/application/backup_controller.dart';
import 'package:aetherlink_flutter/features/backup/application/storage_media_controller.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/domain/topic_storage_usage.dart';

class StorageState {
  const StorageState({
    this.report,
    this.topics = const [],
    this.isBusy = false,
    this.isLoading = true,
    this.error,
  });

  final StorageReport? report;
  final List<TopicStorageUsage> topics;
  final bool isBusy;
  final bool isLoading;
  final String? error;
}

final storageControllerProvider =
    NotifierProvider<StorageController, StorageState>(StorageController.new);

class StorageController extends Notifier<StorageState> {
  Future<void>? _refreshFuture;

  @override
  StorageState build() => const StorageState();

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
    state = StorageState(
      report: state.report,
      topics: state.topics,
      isBusy: state.isBusy,
      isLoading: state.report == null,
    );
    try {
      final repository = ref.read(storageRepositoryProvider);
      final report = await repository.scan();
      final topics = await repository.topicUsage();
      if (!ref.mounted) return;
      state = StorageState(
        report: report,
        topics: topics,
        isBusy: state.isBusy,
        isLoading: false,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = StorageState(
        report: state.report,
        topics: state.topics,
        isBusy: state.isBusy,
        isLoading: false,
        error: '$error',
      );
    }
  }

  Future<void> clean(StorageCleanup target) =>
      _run(() => ref.read(storageRepositoryProvider).clean(target));

  Future<void> cleanItem(String id) =>
      _run(() => ref.read(storageRepositoryProvider).cleanItem(id));

  Future<void> vacuum() =>
      _run(() => ref.read(storageRepositoryProvider).vacuum());

  Future<void> deleteTopics(Set<String> ids) => _run(() async {
    final delete = ref.read(storageTopicDeletionProvider);
    for (final id in ids) {
      await delete(id);
    }
  });

  Future<void> _run(Future<void> Function() action) async {
    if (state.isBusy || state.isLoading) throw StateError('请等待当前统计或维护结束');
    if (ref.read(storageMediaControllerProvider).isBusy) {
      throw StateError('请等待媒体文件操作结束');
    }
    if (ref.read(backupControllerProvider).status == BackupStatus.working) {
      throw StateError('备份或恢复正在进行，请稍后操作');
    }
    state = StorageState(
      report: state.report,
      topics: state.topics,
      isBusy: true,
      isLoading: false,
    );
    Object? failure;
    try {
      await _refreshFuture;
      if (!ref.mounted) return;
      await action();
    } catch (error) {
      failure = error;
    } finally {
      if (ref.mounted) {
        await _startRefresh();
        if (ref.mounted) {
          final media = ref.read(storageMediaControllerProvider.notifier);
          if (ref.read(storageMediaControllerProvider).hasLoaded || media.isRefreshing) {
            await media.refresh(force: true);
          }
        }
        if (ref.mounted) {
          state = StorageState(
            report: state.report,
            topics: state.topics,
            isLoading: false,
            error: state.error,
          );
        }
      }
    }
    if (failure != null) throw failure;
  }
}
