import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/models/data/datasources/local/model_provider_converters.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Drift table for model providers. Primary key [id], a derived [sortOrder]
/// column for the user-defined provider order, and the full [ModelProvider] as
/// a JSON blob ([data]) — mirroring the document-storage layout of the chat
/// tables. The `idx_providers_sort_order` index backs the ordered list query.
@DataClassName('ProviderRow')
@TableIndex(name: 'idx_providers_sort_order', columns: {#sortOrder})
class ProviderRows extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder => integer()();
  TextColumn get data => text().map(const ModelProviderConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
