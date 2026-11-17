import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart' show Variable;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/data/storage_file_operations.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_media_repository.dart';

const kStorageMediaSql = '''
WITH valid_blocks AS (
  SELECT id, message_id,
    CASE WHEN json_valid(data) THEN data ELSE '{}' END AS payload
  FROM message_block_rows
), media AS (
SELECT b.id, t.id AS topic_id,
  CASE WHEN t.id IS NULL THEN '未关联话题' ELSE COALESCE(NULLIF(json_extract(
    CASE WHEN json_valid(t.data) THEN t.data ELSE '{}' END, '\$.name'), ''),
    '未命名话题') END AS topic_title,
  json_extract(CASE WHEN json_valid(t.data) THEN t.data ELSE '{}' END,
    '\$.assistantId') AS assistant_id,
  json_extract(b.payload, '\$.type') AS type,
  json_extract(b.payload, '\$.mimeType') AS mime_type,
  json_extract(b.payload, '\$.createdAt') AS created_at,
  COALESCE(json_extract(b.payload, '\$.updatedAt'),
    json_extract(b.payload, '\$.createdAt')) AS modified_at,
  json_extract(b.payload, '\$.size') AS declared_size,
  json_extract(b.payload, '\$.url') AS url,
  COALESCE(NULLIF(json_extract(b.payload, '\$.base64Data'), ''),
    NULLIF(json_extract(b.payload, '\$.file.base64Data'), '')) AS inline_data,
  COALESCE(json_extract(b.payload, '\$.name'),
    json_extract(b.payload, '\$.file.origin_name'), b.id) AS name
FROM valid_blocks b
LEFT JOIN message_rows m ON m.id = b.message_id
LEFT JOIN topic_rows t ON t.id = m.topic_id
WHERE json_extract(b.payload, '\$.type') IN ('image', 'video', 'file')
), encoded_media AS (
  SELECT *, replace(replace(replace(replace(
    CASE WHEN COALESCE(inline_data, url, '') LIKE 'data:%'
      THEN substr(COALESCE(inline_data, url), instr(COALESCE(inline_data, url), ',') + 1)
      ELSE COALESCE(inline_data, '') END,
    char(10), ''), char(13), ''), char(9), ''), ' ', '') AS encoded
  FROM media
)
SELECT id, topic_id, topic_title, assistant_id, type, mime_type,
  created_at, modified_at, declared_size, name,
  CASE WHEN url LIKE 'data:%' THEN '' ELSE url END AS url,
  CASE WHEN encoded != '' AND length(encoded) % 4 != 1
    AND encoded NOT GLOB '*[^A-Za-z0-9+/_=-]*'
    AND instr(rtrim(encoded, '='), '=') = 0
    AND length(encoded) - length(rtrim(encoded, '=')) <= 2 THEN
  length(encoded) * 3 / 4 - CASE
    WHEN substr(encoded, -2) = '==' THEN 2
    WHEN substr(encoded, -1) = '=' THEN 1 ELSE 0 END
  ELSE NULL END AS inline_bytes
FROM encoded_media
''';

const kStorageReferencesSql = '''
SELECT data AS value FROM message_block_rows
UNION ALL SELECT data FROM message_rows
UNION ALL SELECT data FROM assistant_rows
UNION ALL SELECT data FROM topic_rows
UNION ALL SELECT payload_json FROM agent_event_rows
UNION ALL SELECT data FROM agent_task_rows
UNION ALL SELECT data FROM agent_profile_rows
UNION ALL SELECT data FROM provider_rows
UNION ALL SELECT data FROM group_rows
UNION ALL SELECT data FROM memory_rows
UNION ALL SELECT previous_value FROM memory_history_rows
UNION ALL SELECT new_value FROM memory_history_rows
UNION ALL SELECT source FROM knowledge_item_rows
UNION ALL SELECT source_fingerprint FROM knowledge_item_rows
UNION ALL SELECT content FROM knowledge_content_rows
UNION ALL SELECT content FROM kb_chunk_rows
UNION ALL SELECT value FROM app_setting_rows
UNION ALL SELECT key FROM app_setting_rows
''';

class StorageMediaRepositoryImpl implements StorageMediaRepository {
  StorageMediaRepositoryImpl(this._db, {
    Future<Directory> Function()? documentsDirectory,
    List<String> Function()? activeReferences,
  }) : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory,
       _activeReferences = activeReferences;

  final AppDatabase _db;
  final Future<Directory> Function() _documentsDirectory;
  final List<String> Function()? _activeReferences;

  @override
  Future<List<StorageMedia>> load() async {
    final documents = (await _documentsDirectory()).path;
    final references = _activeReferences?.call() ?? const <String>[];
    await _db.customSelect('SELECT 1').get();
    return Isolate.run(() => loadStorageMedia(documents, references));
  }

  @override
  Future<String> blockPayload(String id) async {
    if (!id.startsWith('block:')) throw ArgumentError.value(id, 'id');
    final rows = await _db.customSelect(
      'SELECT data FROM message_block_rows WHERE id = ?',
      variables: [Variable.withString(id.substring(6))],
    ).get();
    if (rows.length != 1) throw StateError('该媒体块已经不存在');
    return rows.single.read<String>('data');
  }

  @override
  Future<StorageMediaDeletion> deleteUnused(Set<String> ids) async {
    final documents = (await _documentsDirectory()).path;
    final references = _activeReferences?.call() ?? const <String>[];
    await _db.customSelect('SELECT 1').get();
    return Isolate.run(() => deleteStorageMedia(documents, ids, references));
  }
}

String storageMediaMime(String name) => switch (p.extension(name).toLowerCase()) {
  '.png' => 'image/png',
  '.jpg' || '.jpeg' => 'image/jpeg',
  '.webp' => 'image/webp',
  '.gif' => 'image/gif',
  '.bmp' => 'image/bmp',
  '.heic' => 'image/heic',
  '.mp4' => 'video/mp4',
  '.webm' => 'video/webm',
  '.txt' || '.md' || '.json' || '.log' => 'text/plain',
  '.pdf' => 'application/pdf',
  _ => 'application/octet-stream',
};

String? storageLocalPath(String source) {
  if (source.startsWith('file:')) {
    try { return Uri.parse(source).toFilePath(); } on FormatException { return null; }
  }
  return p.isAbsolute(source) ? source : null;
}

String _referenceText(String value) {
  final buffer = StringBuffer(value);
  void visit(Object? node) {
    if (node is String) {
      buffer.write('\n$node');
      try { buffer.write('\n${Uri.decodeFull(node)}'); } on FormatException { /* Keep the original. */ }
    } else if (node is Map) {
      for (final entry in node.entries) {
        visit(entry.key);
        visit(entry.value);
      }
    } else if (node is List) {
      for (final child in node) { visit(child); }
    }
  }
  try { visit(jsonDecode(value)); } on FormatException { visit(value); }
  return buffer.toString().replaceAll('\\', '/').toLowerCase();
}

bool isStorageMediaReferenced(String path, Iterable<String> references) {
  return _StorageReferences(references).contains(path);
}

class _StorageReferences {
  _StorageReferences(Iterable<String> values)
      : values = values.map(_referenceText).toList();
  final List<String> values;

  bool contains(String path) {
    final normalized = p.normalize(path).replaceAll('\\', '/').toLowerCase();
    final name = p.basename(path).toLowerCase();
    return values.any((reference) => reference.contains(normalized) ||
        (name.isNotEmpty && reference.contains(name)));
  }
}

Map<String, StorageMediaFilter> _roots(String documents) => {
  p.join(documents, 'avatars'): StorageMediaFilter.avatars,
  p.join(documents, 'browser_screenshots'): StorageMediaFilter.tools,
  p.join(documents, 'agent_tool_outputs'): StorageMediaFilter.tools,
  p.join(documents, 'pptx_snapshots'): StorageMediaFilter.tools,
};

List<StorageMedia> scanStorageMedia(String documents,
    List<Map<String, Object?>> rows, List<String> rawReferences, {
    bool Function(String)? isReferenced,
}) {
  final references = _StorageReferences(rawReferences);
  final items = <StorageMedia>[];
  for (final row in rows) {
    final url = row['url'] as String? ?? '';
    final source = url;
    final isInline = row['inline_bytes'] != null;
    var bytes = isInline
        ? (row['inline_bytes'] as num).toInt()
        : (row['declared_size'] as num?)?.toInt() ?? 0;
    final local = storageLocalPath(source);
    if (local != null) {
      bytes = 0;
      try {
        if (FileSystemEntity.typeSync(local, followLinks: false) == FileSystemEntityType.file) {
          bytes = File(local).lengthSync();
        }
      } on FileSystemException { bytes = 0; }
    }
    items.add(StorageMedia(
      id: 'block:${row['id']}', name: row['name'] as String? ?? '${row['id']}',
      source: local ?? source, isInline: isInline,
      mimeType: row['mime_type'] as String? ?? '${row['type']}/unknown',
      bytes: bytes < 0 ? 0 : bytes,
      modifiedAt: DateTime.tryParse('${row['modified_at'] ?? row['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      filter: StorageMediaFilter.chat, isInUse: true,
      topicId: row['topic_id'] as String?, topicTitle: row['topic_title'] as String?,
      assistantId: row['assistant_id'] as String?,
    ));
  }
  void visit(String root, String path, StorageMediaFilter filter) {
    try {
      if (!isStoragePathSafe(documents, path)) return;
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        for (final child in Directory(path).listSync(followLinks: false)) {
          visit(root, child.path, filter);
        }
      } else if (type == FileSystemEntityType.file) {
        final mime = storageMediaMime(path);
        if ((filter == StorageMediaFilter.avatars || p.basename(root) == 'browser_screenshots') &&
            !mime.startsWith('image/')) {
          return;
        }
        final stat = File(path).statSync();
        items.add(StorageMedia(
          id: 'disk:$path', name: p.basename(path), source: path,
          mimeType: mime, bytes: stat.size, modifiedAt: stat.modified,
          filter: filter, isInUse: references.contains(path) || (isReferenced?.call(path) ?? false),
        ));
      }
    } on FileSystemException { return; }
  }
  for (final root in _roots(documents).entries) {
    visit(root.key, root.key, root.value);
  }
  return items;
}

bool isStorageMediaReferencedInDatabase(Database db, String path) {
  final name = p.basename(path);
  final needles = {
    name.toLowerCase(),
    Uri.encodeComponent(name).toLowerCase(),
  };
  for (final needle in needles) {
    if (db.select('''
SELECT 1 FROM ($kStorageReferencesSql) AS reference
WHERE instr(lower(reference.value), ?) > 0 OR EXISTS (
  SELECT 1 FROM json_tree(
    CASE WHEN json_valid(reference.value) THEN reference.value ELSE 'null' END
  ) AS node
  WHERE (node.type = 'text' AND instr(lower(CAST(node.atom AS TEXT)), ?) > 0)
    OR instr(lower(CAST(node.key AS TEXT)), ?) > 0
)
LIMIT 1
''', [needle, needle, needle]).isNotEmpty) {
      return true;
    }
  }
  return false;
}

Database _openStorageDatabase(String documents, OpenMode mode) {
  final path = p.join(documents, 'aetherlink.sqlite');
  if (!isStoragePathSafe(documents, path)) {
    throw FileSystemException('数据库路径不安全', path);
  }
  final db = sqlite3.open(path, mode: mode);
  db.execute('PRAGMA busy_timeout = 5000');
  return db;
}

List<StorageMedia> loadStorageMedia(String documents, List<String> activeReferences) {
  final db = _openStorageDatabase(documents, OpenMode.readOnly);
  try {
    final rows = db.select(kStorageMediaSql)
        .map((row) => Map<String, Object?>.from(row)).toList();
    return scanStorageMedia(documents, rows, activeReferences,
      isReferenced: (path) => isStorageMediaReferencedInDatabase(db, path));
  } finally { db.dispose(); }
}

StorageMediaDeletion deleteStorageMedia(
    String documents, Set<String> ids, List<String> activeReferences) {
  final db = _openStorageDatabase(documents, OpenMode.readWrite);
  try {
    db.execute('BEGIN IMMEDIATE');
    try {
      final references = _StorageReferences(activeReferences);
      var deleted = 0;
      for (final id in ids) {
        if (!id.startsWith('disk:')) continue;
        final path = id.substring(5);
        final roots = _roots(documents);
        final root = roots.keys.where((root) => p.isWithin(root, path)).firstOrNull;
        if (root == null || !isStoragePathSafe(documents, path) ||
            references.contains(path) || isStorageMediaReferencedInDatabase(db, path)) {
          continue;
        }
        final mime = storageMediaMime(path);
        if ((p.basename(root) == 'avatars' || p.basename(root) == 'browser_screenshots') &&
            !mime.startsWith('image/')) {
          continue;
        }
        try {
          if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.file) continue;
          File(path).deleteSync();
          deleted++;
        } on FileSystemException { continue; }
      }
      db.execute('COMMIT');
      return StorageMediaDeletion(deleted: deleted, kept: ids.length - deleted);
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  } finally { db.dispose(); }
}
