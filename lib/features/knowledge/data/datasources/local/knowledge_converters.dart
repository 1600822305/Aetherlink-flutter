import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:aetherlink_flutter/features/knowledge/domain/knowledge_scope.dart';

/// Persists a [KnowledgeScope] as its JSON string in a single text column
/// (设计文档 §4.1 的 `scope` 列)。
class KnowledgeScopeConverter extends TypeConverter<KnowledgeScope, String> {
  const KnowledgeScopeConverter();

  @override
  KnowledgeScope fromSql(String fromDb) {
    if (fromDb.isEmpty) return const KnowledgeScope();
    final decoded = jsonDecode(fromDb);
    if (decoded is! Map) return const KnowledgeScope();
    return KnowledgeScope.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  String toSql(KnowledgeScope value) => jsonEncode(value.toJson());
}
