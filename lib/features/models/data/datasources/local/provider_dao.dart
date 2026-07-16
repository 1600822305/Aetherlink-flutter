import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/models/data/datasources/local/providers_table.dart';
import 'package:aetherlink_flutter/features/models/domain/current_model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

part 'provider_dao.g.dart';

/// Data-access object for the [ProviderRows] table. Reads/writes whole
/// [ModelProvider] entities (stored as a JSON blob) and maintains the
/// `sortOrder` column that backs the user-defined provider order.
@DriftAccessor(tables: [ProviderRows])
class ProviderDao extends DatabaseAccessor<AppDatabase>
    with _$ProviderDaoMixin {
  ProviderDao(super.db);

  /// All providers in ascending `sortOrder` (the user-defined order).
  Future<List<ModelProvider>> getAll() async {
    final rows =
        await (select(providerRows)..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.id),
            ]))
            .get();
    return rows.map((row) => row.data).toList();
  }

  Future<ModelProvider?> getById(String id) async {
    final row = await (select(
      providerRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.data;
  }

  /// Inserts or updates a provider. An existing provider keeps its `sortOrder`
  /// (a data update never reorders it); a new provider is appended to the end.
  Future<void> upsert(ModelProvider provider) async {
    final order = await _sortOrderFor(provider.id);
    await into(providerRows).insertOnConflictUpdate(
      ProviderRowsCompanion.insert(
        id: provider.id,
        sortOrder: order,
        data: provider,
      ),
    );
  }

  Future<void> deleteById(String id) =>
      (delete(providerRows)..where((t) => t.id.equals(id))).go();

  /// Reassigns `sortOrder` to match [orderedIds] (position = new order). Ids
  /// not present are left untouched. Runs in a transaction so the list never
  /// observes a half-applied order.
  Future<void> reorder(List<String> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(providerRows)..where((t) => t.id.equals(orderedIds[i])))
            .write(ProviderRowsCompanion(sortOrder: Value(i)));
      }
    });
  }

  /// Marks [modelId] as the default model within provider [providerId] and
  /// clears `isDefault` on the provider's other models. No-op if the provider
  /// is unknown. Scope is intentionally a single provider — picking a global
  /// default across providers is a higher-layer concern.
  Future<void> setDefaultModel({
    required String providerId,
    required String modelId,
  }) async {
    final provider = await getById(providerId);
    if (provider == null) {
      return;
    }
    final updatedModels = [
      for (final model in provider.models)
        model.copyWith(isDefault: model.id == modelId),
    ];
    await upsert(provider.copyWith(models: updatedModels));
  }

  /// Sets the app-level current model in a single transaction: clears
  /// `isDefault` on every model of every provider and sets it on
  /// ([providerId], [modelId]). Only rows whose models actually changed are
  /// rewritten; the transaction guarantees a reader never observes a
  /// half-applied switch (two defaults, or none).
  Future<void> setCurrentModel({
    required String providerId,
    required String modelId,
  }) async {
    await transaction(() async {
      final providers = await getAll();
      final updated = providersWithCurrentModel(
        providers,
        providerId: providerId,
        modelId: modelId,
      );
      for (var i = 0; i < providers.length; i++) {
        if (updated[i] != providers[i]) {
          await upsert(updated[i]);
        }
      }
    });
  }

  /// Existing provider's `sortOrder`, or the next append position for a new id.
  Future<int> _sortOrderFor(String id) async {
    final existing = await (select(
      providerRows,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      return existing.sortOrder;
    }
    final maxOrder = providerRows.sortOrder.max();
    final row = await (selectOnly(
      providerRows,
    )..addColumns([maxOrder])).getSingleOrNull();
    return (row?.read(maxOrder) ?? -1) + 1;
  }
}
