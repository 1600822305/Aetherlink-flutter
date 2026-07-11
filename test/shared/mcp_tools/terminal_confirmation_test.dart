import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/workspace/domain/workspace.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/terminal/terminal_tools.dart';

void main() {
  final projectWs = Workspace(
    id: 'ws-proj',
    name: 'demo',
    backendType: WorkspaceBackendType.prootLocal,
    root: '/root/projects/demo',
    lastOpenedAt: DateTime(2026),
  );
  final fullWs = Workspace(
    id: 'ws-full',
    name: '内置终端',
    backendType: WorkspaceBackendType.prootLocal,
    scope: WorkspaceScope.full,
    root: '/root',
    lastOpenedAt: DateTime(2026),
  );
  final workspaces = [projectWs, fullWs];

  group('terminalToolNeedsConfirmation（双作用域设计稿 §3.2）', () {
    test('非执行类工具不需要审批', () {
      expect(
        terminalToolNeedsConfirmation('terminal_session', const {
          'action': 'list',
        }),
        isFalse,
      );
    });

    test('stdin 写入全量审批（无法静态评级）', () {
      expect(
        terminalToolNeedsConfirmation('terminal_session', const {
          'action': 'write',
          'session_id': 's1',
          'input': 'y',
        }),
        isTrue,
      );
    });

    test('未指定工作区：纯只读命令免审批，其余全量审批', () {
      expect(
        terminalToolNeedsConfirmation('terminal_execute', const {
          'command': 'ls',
        }),
        isFalse,
      );
      expect(
        terminalToolNeedsConfirmation('terminal_execute', const {
          'command': 'cat a.txt | grep foo',
        }),
        isFalse,
      );
      expect(
        terminalToolNeedsConfirmation('terminal_execute', const {
          'command': 'npm install',
        }),
        isTrue,
      );
      expect(
        terminalToolNeedsConfirmation('terminal_execute', const {
          'command': 'echo hi > a.txt',
        }),
        isTrue,
      );
      expect(
        terminalToolNeedsConfirmation('terminal_execute', const {
          'command': 'sudo ls',
        }),
        isTrue,
      );
      expect(
        terminalToolNeedsConfirmation('terminal_execute', const {
          'command': 'find . -name "*.log" -delete',
        }),
        isTrue,
      );
    });

    test('full 模式：纯只读命令免审批，其余全量审批', () {
      expect(
        terminalToolNeedsConfirmation(
          'terminal_execute',
          const {'command': 'ls', 'workspace': 'ws-full'},
          workspaces: workspaces,
        ),
        isFalse,
      );
      expect(
        terminalToolNeedsConfirmation(
          'terminal_execute',
          const {'command': 'rm -rf build', 'workspace': 'ws-full'},
          workspaces: workspaces,
        ),
        isTrue,
      );
    });

    test('project 模式 root 内只读命令免审批', () {
      expect(
        terminalToolNeedsConfirmation(
          'terminal_execute',
          const {'command': 'ls -la', 'workspace': 'ws-proj'},
          workspaces: workspaces,
        ),
        isFalse,
      );
      // 按名称 / 编号解析同样生效。
      expect(
        terminalToolNeedsConfirmation(
          'terminal_execute',
          const {'command': 'cat pubspec.yaml', 'workspace': 'demo'},
          workspaces: workspaces,
        ),
        isFalse,
      );
      expect(
        terminalToolNeedsConfirmation(
          'terminal_execute',
          const {'command': 'pwd', 'workspace': '1'},
          workspaces: workspaces,
        ),
        isFalse,
      );
    });

    test('project 模式写操作与越界命令仍需审批', () {
      expect(
        terminalToolNeedsConfirmation(
          'terminal_execute',
          const {'command': 'npm install', 'workspace': 'ws-proj'},
          workspaces: workspaces,
        ),
        isTrue,
      );
      expect(
        terminalToolNeedsConfirmation(
          'terminal_execute',
          const {'command': 'cat /etc/passwd', 'workspace': 'ws-proj'},
          workspaces: workspaces,
        ),
        isTrue,
      );
    });
  });

  group('terminalCommandEscapesRoot（免确认窗口不覆盖越界，§4.1）', () {
    test('project 模式越界命令 → true', () {
      expect(
        terminalCommandEscapesRoot(
          'terminal_execute',
          const {'command': 'cat /etc/passwd', 'workspace': 'ws-proj'},
          workspaces: workspaces,
        ),
        isTrue,
      );
      expect(
        terminalCommandEscapesRoot(
          'terminal_execute',
          const {'command': 'cd ..', 'workspace': 'ws-proj'},
          workspaces: workspaces,
        ),
        isTrue,
      );
    });

    test('root 内命令 / full 模式 / 未指定工作区 → false', () {
      expect(
        terminalCommandEscapesRoot(
          'terminal_execute',
          const {'command': 'npm install', 'workspace': 'ws-proj'},
          workspaces: workspaces,
        ),
        isFalse,
      );
      expect(
        terminalCommandEscapesRoot(
          'terminal_execute',
          const {'command': 'cat /etc/passwd', 'workspace': 'ws-full'},
          workspaces: workspaces,
        ),
        isFalse,
      );
      expect(
        terminalCommandEscapesRoot('terminal_execute', const {
          'command': 'cat /etc/passwd',
        }),
        isFalse,
      );
    });
  });
}
