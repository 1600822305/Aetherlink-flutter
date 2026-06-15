import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/chat/data/datasources/local/model_converters.dart';
import 'package:aetherlink_flutter/shared/domain/assistant.dart';

/// Drift table for assistants. Mirrors the original IndexedDB `assistants`
/// store (v9 index `id`): primary key [id] and the full [Assistant] as a JSON
/// blob.
@DataClassName('AssistantRow')
class AssistantRows extends Table {
  TextColumn get id => text()();
  TextColumn get data => text().map(const AssistantConverter())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
