import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

const _kDataFileStatKeys = {
  'topics.json': 'topics',
  'messages.json': 'messages',
  'message_blocks.json': 'messageBlocks',
  'assistants.json': 'assistants',
  'providers.json': 'providers',
  'groups.json': 'groups',
  'settings.json': 'settings',
  'knowledge.json': 'knowledge',
  'world_books.json': 'worldBooks',
};

/// 手工拼一个 Flutter ZIP 备份（跳过 createBackup 对 path_provider 的依赖）。
/// [data] 里没给的数据文件写成空数组（模拟精细化备份未勾选的类别），[omit] 里的
/// 文件不写入（模拟缺少该文件的旧备份）。checksum 留空跳过校验，与真实旧备份的
/// 兼容路径一致。
Future<File> writeZipBackup(
  Directory dir, {
  Map<String, List<Map<String, dynamic>>> data = const {},
  Set<String> omit = const {},
}) async {
  final manifest = {
    'version': 1,
    'appVersion': '0.0.0',
    'platform': 'test',
    'schemaVersion': 12,
    'createdAt': DateTime.now().toIso8601String(),
    'deviceInfo': '',
    'checksum': '',
    'stats': {
      for (final e in _kDataFileStatKeys.entries)
        e.value: data[e.key]?.length ?? 0,
    },
    'options': const {
      'includeMessages': true,
      'includeProviders': true,
      'includeSettings': true,
    },
  };

  final archive = Archive();
  void add(String name, Object json) {
    final bytes = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('manifest.json', manifest);
  for (final name in _kDataFileStatKeys.keys) {
    if (omit.contains(name)) continue;
    add(name, data[name] ?? const <Map<String, dynamic>>[]);
  }

  final file = File('${dir.path}/backup.zip');
  await file.writeAsBytes(ZipEncoder().encode(archive));
  return file;
}

/// 把 path_provider 的目录指向测试专用目录，让 BackupService 在纯 Dart 测试里
/// 也能解包、写备份（无真实平台通道）。
class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}
