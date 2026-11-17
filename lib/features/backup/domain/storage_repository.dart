import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/domain/topic_storage_usage.dart';

abstract interface class StorageRepository {
  Future<StorageReport> scan();
  Future<List<TopicStorageUsage>> topicUsage();
  Future<void> clean(StorageCleanup target);
  Future<void> cleanItem(String id);
  Future<void> vacuum();
}
