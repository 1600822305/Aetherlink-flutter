import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_repository.dart';
import 'package:aetherlink_flutter/features/backup/domain/topic_storage_usage.dart';

class StorageRepositoryImpl implements StorageRepository {
  StorageRepositoryImpl(
    this._db, {
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? temporaryDirectory,
    bool? canCleanCache,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _canCleanCache =
           canCleanCache ??
           (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  final AppDatabase _db;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final bool _canCleanCache;

  static const topicUsageSql = '''
WITH block_usage AS (
  SELECT message_id,
    SUM(length(CAST(data AS BLOB))) AS bytes,
    SUM(CASE WHEN json_valid(data)
      THEN json_extract(data, '\$.type') = 'image' ELSE 0 END) AS images,
    SUM(CASE WHEN json_valid(data)
      THEN json_extract(data, '\$.type') = 'video' ELSE 0 END) AS videos
  FROM message_block_rows
  GROUP BY message_id
), message_usage AS (
  SELECT m.topic_id, COUNT(*) AS messages,
    COALESCE(SUM(b.bytes), 0) AS bytes,
    COALESCE(SUM(b.images), 0) AS images,
    COALESCE(SUM(b.videos), 0) AS videos
  FROM message_rows m
  LEFT JOIN block_usage b ON b.message_id = m.id
  WHERE COALESCE(m.role, '') != 'root'
  GROUP BY m.topic_id
)
SELECT t.id,
  COALESCE(NULLIF(json_extract(
    CASE WHEN json_valid(t.data) THEN t.data ELSE '{}' END,
    '\$.name'), ''), '未命名话题') AS title,
  COALESCE(NULLIF(json_extract(
    CASE WHEN json_valid(a.data) THEN a.data ELSE '{}' END,
    '\$.name'), ''), '未关联助手') AS assistant_name,
  COALESCE(u.bytes, 0) AS bytes,
  COALESCE(u.messages, 0) AS messages,
  COALESCE(u.images, 0) AS images,
  COALESCE(u.videos, 0) AS videos
FROM topic_rows t
LEFT JOIN assistant_rows a ON a.id = json_extract(
  CASE WHEN json_valid(t.data) THEN t.data ELSE '{}' END, '\$.assistantId')
LEFT JOIN message_usage u ON u.topic_id = t.id
ORDER BY bytes DESC, t.id
''';

  @override
  Future<List<TopicStorageUsage>> topicUsage() async {
    final rows = await _db.customSelect(topicUsageSql).get();
    return [
      for (final row in rows)
        TopicStorageUsage(
          id: row.read<String>('id'),
          title: row.read<String>('title'),
          assistantName: row.read<String>('assistant_name'),
          bytes: row.read<int>('bytes'),
          messageCount: row.read<int>('messages'),
          imageCount: row.read<int>('images'),
          videoCount: row.read<int>('videos'),
        ),
    ];
  }

  @override
  Future<StorageReport> scan() async {
    final documents = (await _documentsDirectory()).path;
    final canCleanCache = _canCleanCache;
    final paths = <StorageCategory, List<String>>{
      StorageCategory.chat: [
        for (final suffix in ['', '-wal', '-shm'])
          p.join(documents, 'aetherlink.sqlite$suffix'),
      ],
      StorageCategory.backups: [p.join(documents, 'backups')],
      StorageCategory.tools: [
        for (final name in [
          'agent_tool_outputs',
          'browser_screenshots',
          'pptx_snapshots',
        ])
          p.join(documents, name),
      ],
      StorageCategory.avatars: [p.join(documents, 'avatars')],
      StorageCategory.fonts: [
        p.join(documents, 'fonts'),
        p.join(documents, 'google_fonts_cache'),
      ],
      StorageCategory.notes: [p.join(documents, 'notes')],
      StorageCategory.cache: [
        if (canCleanCache) (await _temporaryDirectory()).path,
      ],
    };
    return Isolate.run(() => _scan(paths, canCleanCache: canCleanCache));
  }

  @override
  Future<void> clean(StorageCleanup target) async {
    if (target == StorageCleanup.cache && !_canCleanCache) return;
    final documents = (await _documentsDirectory()).path;
    final paths = switch (target) {
      StorageCleanup.cache => [(await _temporaryDirectory()).path],
      StorageCleanup.tools => [
        for (final name in [
          'agent_tool_outputs',
          'browser_screenshots',
          'pptx_snapshots',
        ])
          p.join(documents, name),
      ],
      StorageCleanup.fontCache => [p.join(documents, 'google_fonts_cache')],
    };
    final failures = await Isolate.run(() => _cleanContents(paths));
    if (failures > 0) throw FileSystemException('有 $failures 个项目未能移除，请稍后重试');
  }

  @override
  Future<void> vacuum() async {
    await _db.customStatement('VACUUM');
    final rows = await _db.customSelect('PRAGMA wal_checkpoint(TRUNCATE)').get();
    if (rows.isNotEmpty && rows.first.read<int>('busy') != 0) {
      throw StateError('数据库已整理，但写入日志仍被占用，请稍后再次压缩');
    }
  }
}

StorageReport _scan(
  Map<StorageCategory, List<String>> paths, {
  required bool canCleanCache,
}) {
  StorageUsage measure(String path) {
    try {
      switch (FileSystemEntity.typeSync(path, followLinks: false)) {
        case FileSystemEntityType.file:
          return StorageUsage(bytes: File(path).lengthSync(), fileCount: 1);
        case FileSystemEntityType.directory:
          var total = const StorageUsage();
          for (final child in Directory(path).listSync(followLinks: false)) {
            total += measure(child.path);
          }
          return total;
        default:
          return const StorageUsage();
      }
    } on FileSystemException {
      return const StorageUsage();
    }
  }

  return StorageReport(
    {
      for (final entry in paths.entries)
        entry.key: entry.value.fold(
          const StorageUsage(),
          (total, path) => total + measure(path),
        ),
    },
    canCleanCache: canCleanCache,
  );
}

int _cleanContents(List<String> paths) {
  var failures = 0;
  void remove(String path) {
    try {
      final type = FileSystemEntity.typeSync(path, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        for (final child in Directory(path).listSync(followLinks: false)) {
          remove(child.path);
        }
        Directory(path).deleteSync();
      } else if (type == FileSystemEntityType.file) {
        File(path).deleteSync();
      } else if (type == FileSystemEntityType.link) {
        Link(path).deleteSync();
      }
    } on FileSystemException {
      failures++;
    }
  }

  for (final path in paths) {
    try {
      // 保留根目录，且不沿符号链接清理目录外的数据。
      if (FileSystemEntity.typeSync(path, followLinks: false) !=
          FileSystemEntityType.directory) {
        continue;
      }
      for (final child in Directory(path).listSync(followLinks: false)) {
        remove(child.path);
      }
    } on FileSystemException {
      failures++;
    }
  }
  return failures;
}
