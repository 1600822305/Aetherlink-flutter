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

  group('terminalCommandIsHighRisk（白名单/免确认窗口/auto 模式不覆盖）', () {
    test('提权/换根、递归强删、黑名单 → true', () {
      expect(
        terminalCommandIsHighRisk('terminal_execute', const {
          'command': 'sudo apk add curl',
        }),
        isTrue,
      );
      expect(
        terminalCommandIsHighRisk('terminal_execute', const {
          'command': 'rm -rf build',
        }),
        isTrue,
      );
      expect(
        terminalCommandIsHighRisk('terminal_execute', const {
          'command': 'mkfs.ext4 /dev/sda1',
        }),
        isTrue,
      );
    });

    test('普通写/执行命令、越界路径 → false（可被预授权覆盖）', () {
      expect(
        terminalCommandIsHighRisk('terminal_execute', const {
          'command': 'npm install',
        }),
        isFalse,
      );
      expect(
        terminalCommandIsHighRisk('terminal_execute', const {
          'command': 'cat /etc/passwd',
        }),
        isFalse,
      );
      expect(
        terminalCommandIsHighRisk('terminal_execute', const {
          'command': 'cd ..',
        }),
        isFalse,
      );
    });

    test('terminal_session：仅 write 且输入高危 → true', () {
      expect(
        terminalCommandIsHighRisk('terminal_session', const {
          'action': 'write',
          'input': 'sudo su -',
        }),
        isTrue,
      );
      expect(
        terminalCommandIsHighRisk('terminal_session', const {
          'action': 'write',
          'input': 'y',
        }),
        isFalse,
      );
      expect(
        terminalCommandIsHighRisk('terminal_session', const {
          'action': 'list',
        }),
        isFalse,
      );
    });
  });
}
