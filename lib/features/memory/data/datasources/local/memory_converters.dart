import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/memory/domain/memory_item.dart';

/// Stores a [MemoryItem] as a JSON blob, mirroring the document-storage
/// strategy used across the app (see `model_converters.dart`).
class MemoryItemConverter extends TypeConverter<MemoryItem, String> {
  const MemoryItemConverter();

  @override
  MemoryItem fromSql(String fromDb) =>
      MemoryItem.fromJson(jsonDecode(fromDb) as Map<String, dynamic>);

  @override
  String toSql(MemoryItem value) => jsonEncode(value.toJson());
}
