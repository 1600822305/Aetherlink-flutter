// 工作区列表体验：pinned/hidden 序列化（含旧记录回退）与展示排序。

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

Workspace _ws(
  String id, {
  bool pinned = false,
  bool hidden = false,
  DateTime? openedAt,
}) =>
    Workspace(
      id: id,
      name: id,
      backendType: WorkspaceBackendType.localSaf,
      root: '/ws/$id',
      lastOpenedAt: openedAt ?? DateTime(2026),
      pinned: pinned,
      hidden: hidden,
    );

void main() {
  group('pinned/hidden 序列化', () {
    test('round-trips through JSON', () {
      final decoded = Workspace.fromJson(
        _ws('a', pinned: true, hidden: true).toJson(),
      );
      expect(decoded.pinned, isTrue);
      expect(decoded.hidden, isTrue);
    });

    test('absent in old records defaults to false', () {
      final json = _ws('a').toJson()
        ..remove('pinned')
        ..remove('hidden');
      final decoded = Workspace.fromJson(json);
      expect(decoded.pinned, isFalse);
      expect(decoded.hidden, isFalse);
    });

    test('copyWith preserves and overrides the flags', () {
      final w = _ws('a', pinned: true, hidden: true);
      expect(w.copyWith(name: 'b').pinned, isTrue);
      expect(w.copyWith(name: 'b').hidden, isTrue);
      expect(w.copyWith(pinned: false).pinned, isFalse);
      expect(w.copyWith(hidden: false).hidden, isFalse);
    });
  });

  group('sortWorkspacesForDisplay', () {
    test('pinned first, then by lastOpenedAt desc', () {
      final sorted = sortWorkspacesForDisplay([
        _ws('old', openedAt: DateTime(2026, 1, 1)),
        _ws('new', openedAt: DateTime(2026, 3, 1)),
        _ws('pin-old', pinned: true, openedAt: DateTime(2025, 1, 1)),
        _ws('pin-new', pinned: true, openedAt: DateTime(2025, 6, 1)),
      ]);
      expect(
        sorted.map((w) => w.id),
        ['pin-new', 'pin-old', 'new', 'old'],
      );
    });

    test('equal timestamps keep the original order', () {
      final t = DateTime(2026);
      final sorted = sortWorkspacesForDisplay(
        [_ws('a', openedAt: t), _ws('b', openedAt: t), _ws('c', openedAt: t)],
      );
      expect(sorted.map((w) => w.id), ['a', 'b', 'c']);
    });
  });
}
