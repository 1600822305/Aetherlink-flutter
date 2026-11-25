import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';

abstract interface class StorageMediaRepository {
  Future<List<StorageMedia>> load();
  Future<String> blockPayload(String id);
  Future<StorageMediaDeletion> deleteUnused(Set<String> ids);
}

/// 秒开路径（可选能力）：上次结果的缓存文件 → 快速扫描（不查引用）→
/// 后台一次遍历核对「是否在用」并写回缓存。实现了它的仓库由控制器走
/// 三段式加载；没实现的仍走 [StorageMediaRepository.load]。
abstract interface class CachedStorageMediaSource {
  /// 上次的结果；没有缓存或缓存损坏时为 null。
  Future<List<StorageMedia>?> loadCached();

  /// 只列元数据：对话媒体走轻量 SQL，磁盘文件只读目录与 stat。磁盘文件
  /// 先标 [StorageMedia.usagePending]（沿用 [previous] 里的旧状态展示）。
  Future<List<StorageMedia>> scanQuick({List<StorageMedia> previous});

  /// 一次遍历全部引用来源，定下磁盘文件的「是否在用」，并写回缓存。
  Future<List<StorageMedia>> resolveUsage(List<StorageMedia> items);
}
