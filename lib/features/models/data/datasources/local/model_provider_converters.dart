import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Drift [TypeConverter] that stores a whole [ModelProvider] as a JSON blob in
/// a single text column — the same document-storage strategy the chat tables
/// use (see `docs/adr/0003-drift-for-persistence.md`). Round-trips through the
/// entity's own `toJson` / `fromJson`, so the persisted shape (including the
/// nested `models` list) stays identical to the original web records.
class ModelProviderConverter extends TypeConverter<ModelProvider, String> {
  const ModelProviderConverter();

  @override
  ModelProvider fromSql(String fromDb) =>
      ModelProvider.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(ModelProvider value) => jsonEncode(value.toJson());
}
