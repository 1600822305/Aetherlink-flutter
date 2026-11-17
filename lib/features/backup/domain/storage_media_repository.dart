import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';

abstract interface class StorageMediaRepository {
  Future<List<StorageMedia>> load();
  Future<String> blockPayload(String id);
  Future<StorageMediaDeletion> deleteUnused(Set<String> ids);
}
