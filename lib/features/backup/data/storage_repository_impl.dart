import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:aetherlink_flutter/core/database/app_database.dart';
import 'package:aetherlink_flutter/features/backup/data/storage_file_operations.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_report.dart';
import 'package:aetherlink_flutter/features/backup/domain/storage_repository.dart';
import 'package:aetherlink_flutter/features/backup/domain/topic_storage_usage.dart';

class StorageRepositoryImpl implements StorageRepository {
  StorageRepositoryImpl(
    this._db, {
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? notesDirectory,
    Future<Directory> Function()? supportDirectory,
    Future<Map<String, String>> Function()? workspaceNames,
    Future<void> Function()? clearImageCache,
    bool? canCleanCache,
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _notesDirectory = notesDirectory,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _workspaceNames = workspaceNames,
       _clearImageCache = clearImageCache,
       _canCleanCache =
           canCleanCache ??
           (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  final AppDatabase _db;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<Directory> Function()? _notesDirectory;
  final Future<Directory> Function() _supportDirectory;
  final Future<Map<String, String>> Function()? _workspaceNames;
  final Future<void> Function()? _clearImageCache;
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
    final paths = await _paths();
    final canCleanCache = _canCleanCache;
    return Isolate.run(
      () => scanStoragePaths(paths, canCleanCache: canCleanCache),
    );
  }

  Future<List<StoragePathSpec>> _paths({bool isCleanup = false}) async {
    final documents = (await _documentsDirectory()).path;
    final support = (await _supportDirectory()).path;
    final notesDirectory = _notesDirectory;
    final notes = notesDirectory == null || isCleanup
        ? p.join(documents, 'notes')
        : (await notesDirectory()).path;
    final temporary = _canCleanCache ? (await _temporaryDirectory()).path : null;
    final networkCache = temporary == null
        ? null
        : p.join(temporary, 'libCachedImageData');
    var names = const <String, String>{};
    if (!isCleanup) {
      try {
        names = await _workspaceNames?.call() ?? const <String, String>{};
      } catch (_) {
        names = const {};
      }
    }
    StoragePathSpec entry(
      String id,
      StorageCategory category,
      String name,
      String root,
      String path, {
      bool canClean = false,
    }) => StoragePathSpec(
      id: id,
      category: category,
      name: name,
      root: root,
      path: path,
      canClean: canClean,
    );
    return [
      for (final suffix in ['', '-wal', '-shm'])
        entry(
          'database$suffix',
          StorageCategory.chat,
          'aetherlink.sqlite$suffix',
          documents,
          p.join(documents, 'aetherlink.sqlite$suffix'),
        ),
      entry(
        'backups', StorageCategory.backups, '本地备份', documents,
        p.join(documents, 'backups'),
      ),
      for (final item in const {
        'agent_tool_outputs': '工具执行结果',
        'browser_screenshots': '浏览器截图',
        'pptx_snapshots': '演示文稿快照',
      }.entries)
        entry(
          item.key, StorageCategory.tools, item.value, documents,
          p.join(documents, item.key),
        ),
      entry(
        'avatars', StorageCategory.avatars, '头像文件', documents,
        p.join(documents, 'avatars'),
      ),
      entry(
        'fonts', StorageCategory.fonts, '导入的字体', documents,
        p.join(documents, 'fonts'),
      ),
      entry(
        'notes', StorageCategory.notes, '笔记文件',
        p.isWithin(documents, notes) ? documents : notes, notes,
      ),
      entry(
        'fontCache', StorageCategory.cache, '在线字体缓存', documents,
        p.join(documents, 'google_fonts_cache'), canClean: true,
      ),
      if (temporary != null && networkCache != null) ...[
        StoragePathSpec(
          id: 'temporary',
          category: StorageCategory.cache,
          name: '临时目录',
          root: temporary,
          path: temporary,
          canClean: true,
          excludedPaths: [networkCache],
        ),
        entry(
          'imageCache', StorageCategory.cache, '网络图片缓存', temporary,
          networkCache, canClean: true,
        ),
      ],
      entry(
        'pdfium', StorageCategory.other, 'PDF 引擎', support,
        p.join(support, 'pdfium'),
      ),
      entry(
        'buddySkins', StorageCategory.other, '伙伴皮肤', support,
        p.join(support, 'buddy_skins'),
      ),
      StoragePathSpec(
        id: 'history',
        category: StorageCategory.workspaceHistory,
        name: '工作区历史',
        root: support,
        path: p.join(support, 'file_history'),
        canClean: true,
        isContainer: true,
        childNames: names,
      ),
      entry(
        'terminalRootfs', StorageCategory.terminal, 'rootfs', support,
        p.join(support, 'terminal', 'rootfs'),
      ),
      entry(
        'terminalTmp', StorageCategory.terminal, '终端临时文件', support,
        p.join(support, 'terminal', 'tmp'), canClean: true,
      ),
    ];
  }

  @override
  Future<void> clean(StorageCleanup target) async {
    if (target == StorageCleanup.tools) {
      throw StateError('请进入图片或文件管理，按引用状态清理工具文件');
    }
    final allPaths = await _paths(isCleanup: true);
    final paths = allPaths.where((spec) => switch (target) {
      StorageCleanup.cache => spec.category == StorageCategory.cache,
      StorageCleanup.tools => spec.category == StorageCategory.tools,
      StorageCleanup.fontCache => spec.id == 'fontCache',
      StorageCleanup.workspaceHistory => spec.id == 'history',
    }).toList();
    await Isolate.run(() => clearStoragePaths(paths));
    if (paths.any((spec) => spec.id == 'imageCache')) {
      await _clearImageCache?.call();
    }
  }

  @override
  Future<void> cleanItem(String id) async {
    final paths = await _paths(isCleanup: true);
    await Isolate.run(() => cleanStorageItem(paths, id));
    if (id == 'imageCache') {
      await _clearImageCache?.call();
    }
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
