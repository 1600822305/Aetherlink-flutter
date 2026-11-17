import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:aetherlink_flutter/features/backup/data/storage_media_repository_impl.dart';

void main() {
  late Directory documents;
  late Database db;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('storage_media_');
    db = sqlite3.open(p.join(documents.path, 'aetherlink.sqlite'));
    db.execute('CREATE TABLE message_block_rows (id TEXT, message_id TEXT, data TEXT)');
    db.execute('CREATE TABLE message_rows (id TEXT, topic_id TEXT)');
    db.execute("ALTER TABLE message_rows ADD COLUMN data TEXT DEFAULT '{}'");
    db.execute('CREATE TABLE topic_rows (id TEXT, data TEXT)');
    db.execute('CREATE TABLE assistant_rows (id TEXT, data TEXT)');
    db.execute('CREATE TABLE app_setting_rows (key TEXT, value TEXT)');
    db.execute('CREATE TABLE agent_event_rows (id TEXT, payload_json TEXT)');
    for (final table in ['agent_task_rows', 'agent_profile_rows', 'provider_rows', 'group_rows', 'memory_rows']) {
      db.execute('CREATE TABLE $table (id TEXT, data TEXT)');
    }
    db.execute('CREATE TABLE memory_history_rows (previous_value TEXT, new_value TEXT)');
    db.execute('CREATE TABLE knowledge_item_rows (source TEXT, source_fingerprint TEXT)');
    db.execute('CREATE TABLE knowledge_content_rows (content TEXT)');
    db.execute('CREATE TABLE kb_chunk_rows (content TEXT)');
  });

  tearDown(() async {
    db.dispose();
    await documents.delete(recursive: true);
  });

  Future<File> file(String name) async {
    final file = File(p.join(documents.path, name));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3]);
    return file;
  }

  test('references include nested JSON, filename mentions and encoded file URIs', () {
    const path = '/documents/avatars/我的头像.png';
    for (final value in [
      jsonEncode({'avatar': path}),
      jsonEncode({'nested': [{'text': '附件 我的头像.png'}]}),
      Uri.file(path).toString(),
    ]) {
      expect(isStorageMediaReferenced(path, [value]), isTrue);
    }
    expect(isStorageMediaReferenced(path, ['unrelated.json']), isFalse);
  });

  test('SQL base64 lengths handle padding, data URIs, whitespace and invalid input', () {
    for (var length = 0; length < 12; length++) {
      final encoded = base64Encode(List.filled(length, 1));
      for (final source in [encoded, 'data:image/png;base64,$encoded\n']) {
        db.execute('INSERT INTO message_block_rows VALUES (?, ?, ?)',
          ['image', 'm', jsonEncode({'type': 'image', 'base64Data': source})]);
        expect(db.select(kStorageMediaSql).single['inline_bytes'] ?? 0, length);
        db.execute('DELETE FROM message_block_rows');
      }
    }
    for (final source in ['%%%', 'A', '', 'AA=A']) {
      db.execute('INSERT INTO message_block_rows VALUES (?, ?, ?)',
        ['image', 'm', jsonEncode({'type': 'image', 'base64Data': source})]);
      expect(db.select(kStorageMediaSql).single['inline_bytes'] ?? 0, 0);
      db.execute('DELETE FROM message_block_rows');
    }
  });

  test('SQL includes orphan blocks, nested file bytes, URLs and malformed rows safely', () async {
    final local = await file('agent_tool_outputs/local.txt');
    final payloads = [
      {'id': 'image', 'type': 'image', 'mimeType': 'image/png',
        'url': '', 'base64Data': 'AQIDBA==', 'createdAt': '2026-01-02T03:04:00Z'},
      {'id': 'file', 'type': 'file', 'mimeType': 'text/plain', 'url': '',
        'file': {'base64Data': 'data:text/plain;base64,AQI='}},
      {'id': 'local', 'type': 'file', 'mimeType': 'text/plain', 'url': local.uri.toString()},
      {'id': 'video', 'type': 'video', 'mimeType': 'video/mp4', 'url': 'https://example.com/v', 'size': 77},
    ];
    for (final payload in payloads) {
      db.execute('INSERT INTO message_block_rows VALUES (?, ?, ?)',
        [payload['id'], 'message', jsonEncode(payload)]);
    }
    db.execute("INSERT INTO message_block_rows VALUES ('bad', 'orphan', 'invalid-json')");
    db.execute("INSERT INTO message_rows (id, topic_id) VALUES ('message', 'topic')");
    db.execute('INSERT INTO topic_rows VALUES (?, ?)', ['topic', jsonEncode({'name': '测试', 'assistantId': 'assistant'})]);
    final rows = db.select(kStorageMediaSql).map((row) => Map<String, Object?>.from(row)).toList();
    expect(rows.every((row) => !row.containsKey('block_json') && !row.containsKey('inline_data')), isTrue);
    expect(rows.length, 4);
    expect(rows.firstWhere((row) => row['id'] == 'image')['inline_bytes'], 4);
    expect(rows.firstWhere((row) => row['id'] == 'file')['inline_bytes'], 2);
    final items = scanStorageMedia(documents.path, rows, []);
    final blocks = {for (final item in items.where((item) => item.isChat)) item.id: item};
    expect(blocks['block:image']!.bytes, 4);
    expect(blocks['block:file']!.bytes, 2);
    expect(blocks['block:local']!.bytes, 3);
    expect(blocks['block:video']!.bytes, 77);
    expect(blocks.values.every((item) => item.isInUse && !item.canDelete), isTrue);
    expect(blocks['block:image']!.topicTitle, '测试');
    expect(blocks['block:image']!.assistantId, 'assistant');
    db.execute('DELETE FROM message_rows');
    final orphanRows = db.select(kStorageMediaSql).map((row) => Map<String, Object?>.from(row)).toList();
    expect(scanStorageMedia(documents.path, orphanRows, []).first.isInUse, isTrue);
  });

  test('deletion rechecks each persisted reference source after the list was loaded', () async {
    final target = await file('browser_screenshots/keep.png');
    final id = 'disk:${target.path}';
    for (final table in ['message_block_rows', 'assistant_rows', 'topic_rows', 'app_setting_rows']) {
      expect(loadStorageMedia(documents.path, []).single.canDelete, isTrue);
      final value = jsonEncode({'mention': p.basename(target.path)});
      if (table == 'message_block_rows') {
        db.execute('INSERT INTO $table VALUES (?, ?, ?)', ['new', 'm', value]);
      } else {
        db.execute('INSERT INTO $table VALUES (?, ?)', ['new', value]);
      }
      expect(loadStorageMedia(documents.path, []).single.isInUse, isTrue);
      final result = deleteStorageMedia(documents.path, {id}, []);
      expect(result.deleted, 0);
      expect(result.kept, 1);
      expect(await target.exists(), isTrue);
      db.execute('DELETE FROM $table');
    }
    final result = deleteStorageMedia(documents.path, {id}, []);
    expect(result.deleted, 1);
    expect(result.kept, 0);
    expect(await target.exists(), isFalse);
  });

  test('live avatar references are protected even before they reach settings', () async {
    final avatar = await file('avatars/current.png');
    final items = scanStorageMedia(documents.path, [], [avatar.path]);
    expect(items.single.isInUse, isTrue);
    final result = deleteStorageMedia(documents.path, {'disk:${avatar.path}'}, [avatar.path]);
    expect(result.kept, 1);
    expect(await avatar.exists(), isTrue);
  });

  test('agent-only screenshot and overflow references protect listing and deletion', () async {
    final screenshot = await file('browser_screenshots/agent-only.png');
    final overflow = await file('agent_tool_outputs/agent-only.txt');
    final ids = {'disk:${screenshot.path}', 'disk:${overflow.path}'};
    expect(loadStorageMedia(documents.path, []).every((item) => item.canDelete), isTrue);
    db.execute('INSERT INTO agent_event_rows VALUES (?, ?)', ['tool-call', jsonEncode({
      'imagePath': screenshot.path,
      'resultOverflowPath': overflow.path,
    })]);
    final listed = loadStorageMedia(documents.path, []);
    expect(listed.length, 2);
    expect(listed.every((item) => item.isInUse && !item.canDelete), isTrue);
    final result = deleteStorageMedia(documents.path, ids, []);
    expect(result.deleted, 0);
    expect(result.kept, 2);
    expect(await screenshot.exists(), isTrue);
    expect(await overflow.exists(), isTrue);
    db.execute('DELETE FROM agent_event_rows');
    expect(deleteStorageMedia(documents.path, ids, []).deleted, 2);
  });

  test('other persisted payloads, knowledge sources and workspace settings protect files', () async {
    final target = await file('agent_tool_outputs/persisted.txt');
    final sources = {
      'message_rows': 'data',
      'agent_task_rows': 'data',
      'agent_profile_rows': 'data',
      'provider_rows': 'data',
      'group_rows': 'data',
      'memory_rows': 'data',
      'memory_history_rows': 'previous_value',
      'knowledge_item_rows': 'source',
      'knowledge_content_rows': 'content',
      'kb_chunk_rows': 'content',
      'app_setting_rows': 'value',
    };
    for (final entry in sources.entries) {
      expect(loadStorageMedia(documents.path, []).single.canDelete, isTrue);
      db.execute('INSERT INTO ${entry.key} (${entry.value}) VALUES (?)',
        [jsonEncode({'root': target.path})]);
      expect(loadStorageMedia(documents.path, []).single.isInUse, isTrue);
      expect(deleteStorageMedia(documents.path, {'disk:${target.path}'}, []).kept, 1);
      db.execute('DELETE FROM ${entry.key}');
    }
    for (final entry in {'memory_history_rows': 'new_value', 'knowledge_item_rows': 'source_fingerprint'}.entries) {
      db.execute('INSERT INTO ${entry.key} (${entry.value}) VALUES (?)', [target.path]);
      expect(deleteStorageMedia(documents.path, {'disk:${target.path}'}, []).kept, 1);
      db.execute('DELETE FROM ${entry.key}');
    }
    expect(await target.exists(), isTrue);
  });

  test('database references decode JSON keys, escaped unicode and encoded URIs', () async {
    final avatar = await file('avatars/我的头像.png');
    for (final value in [
      Uri.file(avatar.path).toString(),
      r'{"\u6211\u7684\u5934\u50cf.png":true}',
      jsonEncode({'nested': [{'value': avatar.path}]}),
    ]) {
      db.execute('INSERT INTO app_setting_rows VALUES (?, ?)', ['avatar', value]);
      expect(isStorageMediaReferencedInDatabase(db, avatar.path), isTrue);
      expect(deleteStorageMedia(documents.path, {'disk:${avatar.path}'}, []).kept, 1);
      db.execute('DELETE FROM app_setting_rows');
    }
  });

  test('empty selection and missing files report accurate counts', () {
    expect(deleteStorageMedia(documents.path, {}, []).deleted, 0);
    final result = deleteStorageMedia(documents.path,
      {'disk:${p.join(documents.path, 'agent_tool_outputs', 'missing')}', 'block:chat'}, []);
    expect(result.deleted, 0);
    expect(result.kept, 2);
  });

  test('directories, traversal, prefix siblings and symlinks cannot escape roots', () async {
    final keep = await file('agent_tool_outputs_sibling/keep.txt');
    final folder = await Directory(p.join(documents.path, 'agent_tool_outputs')).create();
    final ids = <String>{
      'disk:${keep.path}', 'disk:${folder.path}',
      'disk:${folder.path}${p.separator}..${p.separator}agent_tool_outputs_sibling${p.separator}keep.txt',
    };
    if (!Platform.isWindows) {
      final link = Link(p.join(folder.path, 'linked.txt'));
      await link.create(keep.path);
      ids.add('disk:${link.path}');
      await Link(p.join(documents.path, 'pptx_snapshots')).create(keep.parent.path);
      ids.add('disk:${p.join(documents.path, 'pptx_snapshots', 'keep.txt')}');
    }
    final result = deleteStorageMedia(documents.path, ids, []);
    expect(result.deleted, 0);
    expect(result.kept, ids.length);
    expect(await keep.exists(), isTrue);
    expect(scanStorageMedia(documents.path, [], []), isEmpty);
  });

  test('failed reference queries fail closed without removing files', () async {
    final target = await file('agent_tool_outputs/keep.txt');
    db.execute('DROP TABLE app_setting_rows');
    expect(() => deleteStorageMedia(documents.path, {'disk:${target.path}'}, []), throwsA(isA<SqliteException>()));
    expect(await target.exists(), isTrue);
  });
}
