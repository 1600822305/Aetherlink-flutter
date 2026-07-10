import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';

void main() {
  group('WorkspaceScope 序列化', () {
    test('scope 写入 JSON 并原样读回', () {
      final ws = Workspace(
        id: 'ws1',
        name: 'demo',
        backendType: WorkspaceBackendType.prootLocal,
        scope: WorkspaceScope.project,
        root: '/root/projects/demo',
        lastOpenedAt: DateTime(2026),
      );
      final decoded = Workspace.fromJson(ws.toJson());
      expect(decoded.scope, WorkspaceScope.project);
      expect(decoded.root, '/root/projects/demo');
    });

    test('未知 scope 名回退 project', () {
      expect(WorkspaceScope.fromName('bogus'), WorkspaceScope.project);
      expect(WorkspaceScope.fromName(null), WorkspaceScope.project);
    });
  });

  group('旧记录（无 scope 字段）的推断', () {
    Map<String, dynamic> legacy(String backendType, String root) => {
          'id': 'ws1',
          'name': 'demo',
          'backendType': backendType,
          'root': root,
          'lastOpenedAt': '2026-01-01T00:00:00.000',
        };

    test('旧内置终端记录 → full（整机即工作区的现状行为）', () {
      final ws = Workspace.fromJson(legacy('prootLocal', '/root'));
      expect(ws.scope, WorkspaceScope.full);
    });

    test('SAF / SSH / Termux 旧记录 → project（目录即工作区）', () {
      expect(
        Workspace.fromJson(legacy('localSaf', 'content://tree/x')).scope,
        WorkspaceScope.project,
      );
      expect(
        Workspace.fromJson(legacy('ssh', '/home/dev/app')).scope,
        WorkspaceScope.project,
      );
      expect(
        Workspace.fromJson(legacy('termux', '/data/data/com.termux/home')).scope,
        WorkspaceScope.project,
      );
    });
  });
}
