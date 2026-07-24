import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/config/builtin_skills.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/settings/mcp_manage_tool.dart';

void main() {
  test('内置技能「MCP 服务器管理」存在且正文完整', () {
    final skill = kBuiltinSkills
        .where((s) => s.id == 'builtin-mcp-manage')
        .single;
    expect(skill.name, 'MCP 服务器管理');
    expect(skill.enabled, isTrue);
    expect(skill.content, contains('mcp_manage'));
    expect(skill.content, contains('stdio'));
    expect(skill.content, contains('mcpServers 条目'));
    expect(skill.content, contains('workspaces'));
  });

  test('mcp_manage 工具定义指向技能，schema 含五个 action', () {
    expect(kMcpManageToolDefinition.name, kMcpManageToolName);
    expect(kMcpManageToolDefinition.description, contains('MCP 服务器管理'));
    final props =
        kMcpManageToolDefinition.inputSchema['properties']
            as Map<String, Object?>;
    final action = props['action'] as Map<String, Object?>;
    expect(action['enum'], [
      'list',
      'add',
      'remove',
      'toggle',
      'workspaces',
    ]);
    expect(props.containsKey('workspace'), isTrue);
  });

  test('审批分级：list/workspaces 免审，add/remove/toggle 需确认', () {
    expect(mcpManageNeedsConfirmation({'action': 'list'}), isFalse);
    expect(mcpManageNeedsConfirmation({'action': 'workspaces'}), isFalse);
    expect(mcpManageNeedsConfirmation({'action': 'add'}), isTrue);
    expect(mcpManageNeedsConfirmation({'action': 'remove'}), isTrue);
    expect(mcpManageNeedsConfirmation({'action': 'toggle'}), isTrue);
    expect(mcpManageNeedsConfirmation({}), isTrue);
  });

  test('审批摘要按 action 生成', () {
    expect(
      mcpManageConfirmSummary({'action': 'add', 'name': 'fs'}),
      contains('添加 MCP 服务器「fs」'),
    );
    expect(
      mcpManageConfirmSummary({'action': 'remove', 'id': 'mcp_1'}),
      contains('删除 MCP 服务器「mcp_1」'),
    );
    expect(
      mcpManageConfirmSummary({
        'action': 'toggle',
        'name': 'fs',
        'enabled': false,
      }),
      contains('停用 MCP 服务器「fs」'),
    );
  });
}
