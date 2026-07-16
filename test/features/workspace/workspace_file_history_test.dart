// workspace_file_history.dart 的单测：索引编解码、按文件裁剪、
// 快照记录（去重/上限/孤儿回收）与恢复读取。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/application/workspace_file_history.dart';

void main() {
  group('index codec', () {
    test('round-trips snapshots and tolerates malformed input', () {
      final snapshots = [
        FileHistorySnapshot(
          path: '/ws/a.txt',
          savedAt: DateTime.utc(2026, 7, 16, 10),
          size: 5,
          source: '编辑器保存',
          hash: 'abc',
        ),
      ];
      final decoded = decodeFileHistoryIndex(
        encodeFileHistoryIndex(snapshots),
      );
      expect(decoded, hasLength(1));
      expect(decoded.first.path, '/ws/a.txt');
      expect(decoded.first.hash, 'abc');
      expect(decoded.first.savedAt, DateTime.utc(2026, 7, 16, 10));

      expect(decodeFileHistoryIndex('not json'), isEmpty);
      expect(decodeFileHistoryIndex('{"a":1}'), isEmpty);
    });
  });

  group('pruneFileHistory', () {
    test('keeps only the newest N per path, preserving other paths', () {
      FileHistorySnapshot snap(String path, int hour) => FileHistorySnapshot(
            path: path,
            savedAt: DateTime.utc(2026, 1, 1, hour),
            size: 1,
            source: 's',
            hash: '$path-$hour',
          );
      final pruned = pruneFileHistory(
        [snap('/a', 1), snap('/a', 2), snap('/a', 3), snap('/b', 1)],
        maxPerFile: 2,
      );
      expect(pruned.map((s) => s.hash),
          ['/a-2', '/a-3', '/b-1']); // /a-1 被裁掉，顺序保留
    });
  });

  group('WorkspaceFileHistoryStore', () {
    late Directory tmp;
    late WorkspaceFileHistoryStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('file_history_test');
      store = WorkspaceFileHistoryStore(baseDir: tmp);
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('records, dedups identical latest content, and reads back', () async {
      await store.record('/ws/a.txt', 'v1', source: '编辑器保存');
      await store.record('/ws/a.txt', 'v1', source: '编辑器保存'); // dedup
      await store.record('/ws/a.txt', 'v2', source: '智能体写入');

      final snapshots = await store.snapshotsFor('/ws/a.txt');
      expect(snapshots, hasLength(2));
      expect(snapshots.first.source, '智能体写入'); // newest first
      expect(await store.read(snapshots.first), 'v2');
      expect(await store.read(snapshots.last), 'v1');
    });

    test('remove drops the record and sweeps its orphan object', () async {
      await store.record('/ws/a.txt', 'v1', source: 's');
      final snapshots = await store.snapshotsFor('/ws/a.txt');
      await store.remove(snapshots.single);

      expect(await store.snapshotsFor('/ws/a.txt'), isEmpty);
      final objects = Directory('${tmp.path}/objects');
      expect(
        objects.existsSync() ? objects.listSync() : const <FileSystemEntity>[],
        isEmpty,
      );
    });

    test('skips oversized content', () async {
      final big = 'x' * (kFileHistoryMaxBytes + 1);
      await store.record('/ws/big.txt', big, source: 's');
      expect(await store.snapshotsFor('/ws/big.txt'), isEmpty);
    });
  });
}
