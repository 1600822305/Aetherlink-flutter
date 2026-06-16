import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/models/domain/repositories/model_repository.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Drift-backed [ModelRepository]. Delegates to [ProviderDao], which stores
/// each [ModelProvider] as a JSON blob and reads it back — so the repository
/// deals purely in domain models and never leaks Drift row types upward.
class ModelRepositoryImpl implements ModelRepository {
  ModelRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<ModelProvider>> getProviders() => _db.providerDao.getAll();

  @override
  Future<ModelProvider?> getProvider(String id) => _db.providerDao.getById(id);

  @override
  Future<void> saveProvider(ModelProvider provider) =>
      _db.providerDao.upsert(provider);

  @override
  Future<void> deleteProvider(String id) => _db.providerDao.deleteById(id);

  @override
  Future<void> reorderProviders(List<String> orderedIds) =>
      _db.providerDao.reorder(orderedIds);

  @override
  Future<void> setDefaultModel({
    required String providerId,
    required String modelId,
  }) =>
      _db.providerDao.setDefaultModel(providerId: providerId, modelId: modelId);
}
