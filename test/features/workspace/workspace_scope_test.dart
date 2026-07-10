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

  group('isolatedHome（L2 语言级隔离，设计稿 §4 P5）', () {
    Workspace make({required bool isolatedHome, String root = '/root/projects/demo'}) =>
        Workspace(
          id: 'ws1',
          name: 'demo',
          backendType: WorkspaceBackendType.prootLocal,
          scope: WorkspaceScope.project,
          isolatedHome: isolatedHome,
          root: root,
          lastOpenedAt: DateTime(2026),
        );

    test('写入 JSON 并原样读回', () {
      expect(Workspace.fromJson(make(isolatedHome: true).toJson()).isolatedHome,
          isTrue);
      expect(
          Workspace.fromJson(make(isolatedHome: false).toJson()).isolatedHome,
          isFalse);
    });

    test('旧记录（无 isolatedHome 字段）→ false', () {
      final ws = Workspace.fromJson({
        'id': 'ws1',
        'name': 'demo',
        'backendType': 'prootLocal',
        'scope': 'project',
        'root': '/root/projects/demo',
        'lastOpenedAt': '2026-01-01T00:00:00.000',
      });
      expect(ws.isolatedHome, isFalse);
      expect(ws.isolatedHomePath, isNull);
    });

    test('isolatedHomePath = <root>/.home（root 末尾斜杠归一化）', () {
      expect(make(isolatedHome: true).isolatedHomePath,
          '/root/projects/demo/.home');
      expect(
        make(isolatedHome: true, root: '/root/projects/demo/').isolatedHomePath,
        '/root/projects/demo/.home',
      );
      expect(make(isolatedHome: false).isolatedHomePath, isNull);
    });

    test('copyWith 保留 isolatedHome', () {
      expect(
        make(isolatedHome: true).copyWith(name: 'x').isolatedHome,
        isTrue,
      );
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
