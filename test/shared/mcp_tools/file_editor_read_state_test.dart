import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_read_state.dart';

void main() {
  group('isDuplicateRead', () {
    const rec = FileReadRecord(mtime: 100, size: 10, startLine: 1, endLine: 5);

    test('命中：同范围且 mtime/size 未变', () {
      expect(
        isDuplicateRead(rec, mtime: 100, size: 10, startLine: 1, endLine: 5),
        isTrue,
      );
    });

    test('无记录不去重', () {
      expect(isDuplicateRead(null, mtime: 100, size: 10), isFalse);
    });

    test('mtime 变化不去重', () {
      expect(
        isDuplicateRead(rec, mtime: 101, size: 10, startLine: 1, endLine: 5),
        isFalse,
      );
    });

    test('size 变化不去重（mtime 精度兜底）', () {
      expect(
        isDuplicateRead(rec, mtime: 100, size: 11, startLine: 1, endLine: 5),
        isFalse,
      );
    });

    test('范围不同不去重', () {
      expect(
        isDuplicateRead(rec, mtime: 100, size: 10, startLine: 1, endLine: 6),
        isFalse,
      );
      expect(isDuplicateRead(rec, mtime: 100, size: 10), isFalse);
    });

    test('行号开关不同不去重', () {
      expect(
        isDuplicateRead(
          rec,
          mtime: 100,
          size: 10,
          startLine: 1,
          endLine: 5,
          withLineNumbers: false,
        ),
        isFalse,
      );
    });

    test('后端不提供 mtime（0）不去重', () {
      const noMtime = FileReadRecord(mtime: 0, size: 10);
      expect(isDuplicateRead(noMtime, mtime: 0, size: 10), isFalse);
    });

    test('本会话写入后（dedupEligible=false）不去重', () {
      const written = FileReadRecord(mtime: 100, size: 10, dedupEligible: false);
      expect(isDuplicateRead(written, mtime: 100, size: 10), isFalse);
    });
  });

  group('isStaleForEdit', () {
    test('mtime 变化 → 陈旧', () {
      const rec = FileReadRecord(mtime: 100, size: 10);
      expect(isStaleForEdit(rec, mtime: 200), isTrue);
    });

    test('mtime 未变 → 不陈旧', () {
      const rec = FileReadRecord(mtime: 100, size: 10);
      expect(isStaleForEdit(rec, mtime: 100), isFalse);
    });

    test('未读过（无记录）不拦', () {
      expect(isStaleForEdit(null, mtime: 200), isFalse);
    });

    test('任一侧 mtime 为 0（后端不提供）不拦', () {
      const rec = FileReadRecord(mtime: 0, size: 10);
      expect(isStaleForEdit(rec, mtime: 200), isFalse);
      const rec2 = FileReadRecord(mtime: 100, size: 10);
      expect(isStaleForEdit(rec2, mtime: 0), isFalse);
    });
  });

  group('FileReadStateStore', () {
    test('record / lookup 按会话隔离', () {
      final store = FileReadStateStore();
      store.record('a', '/f', const FileReadRecord(mtime: 1, size: 2));
      expect(store.lookup('a', '/f')?.mtime, 1);
      expect(store.lookup('b', '/f'), isNull);
    });

    test('refreshAfterWrite 更新 mtime 并禁用去重；未读过时是 no-op', () {
      final store = FileReadStateStore();
      store.refreshAfterWrite('a', '/f', mtime: 9, size: 9);
      expect(store.lookup('a', '/f'), isNull);

      store.record(
        'a',
        '/f',
        const FileReadRecord(mtime: 1, size: 2, startLine: 3, endLine: 4),
      );
      store.refreshAfterWrite('a', '/f', mtime: 9, size: 9);
      final rec = store.lookup('a', '/f')!;
      expect(rec.mtime, 9);
      expect(rec.size, 9);
      expect(rec.dedupEligible, isFalse);
      // 原范围保留（仅元数据刷新）。
      expect(rec.startLine, 3);
      expect(rec.endLine, 4);
    });

    test('每会话路径数 LRU 封顶', () {
      final store = FileReadStateStore();
      for (var i = 0; i <= FileReadStateStore.kMaxPathsPerSession; i++) {
        store.record('a', '/f$i', const FileReadRecord(mtime: 1, size: 1));
      }
      expect(store.lookup('a', '/f0'), isNull); // 最老的被逐出
      expect(
        store.lookup('a', '/f${FileReadStateStore.kMaxPathsPerSession}'),
        isNotNull,
      );
    });

    test('会话数 LRU 封顶', () {
      final store = FileReadStateStore();
      for (var i = 0; i <= FileReadStateStore.kMaxSessions; i++) {
        store.record('s$i', '/f', const FileReadRecord(mtime: 1, size: 1));
      }
      expect(store.lookup('s0', '/f'), isNull);
      expect(
        store.lookup('s${FileReadStateStore.kMaxSessions}', '/f'),
        isNotNull,
      );
    });
  });
}
