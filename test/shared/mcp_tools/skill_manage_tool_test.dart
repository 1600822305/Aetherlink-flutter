import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/mcp_tools/settings/skill_manage_tool.dart';

void main() {
  test('skill_manage 工具定义：schema 含五个 action', () {
    expect(kSkillManageToolDefinition.name, kSkillManageToolName);
    expect(kSkillManageToolDefinition.description, contains('管理技能库'));
    final props =
        kSkillManageToolDefinition.inputSchema['properties']
            as Map<String, Object?>;
    final action = props['action'] as Map<String, Object?>;
    expect(action['enum'], ['list', 'add', 'update', 'remove', 'toggle']);
    expect(props.containsKey('content'), isTrue);
    expect(props.containsKey('enabled'), isTrue);
  });

  test('审批分级：list 免审，add/update/remove/toggle 需确认', () {
    expect(skillManageNeedsConfirmation({'action': 'list'}), isFalse);
    expect(skillManageNeedsConfirmation({'action': 'add'}), isTrue);
    expect(skillManageNeedsConfirmation({'action': 'update'}), isTrue);
    expect(skillManageNeedsConfirmation({'action': 'remove'}), isTrue);
    expect(skillManageNeedsConfirmation({'action': 'toggle'}), isTrue);
    expect(skillManageNeedsConfirmation({}), isTrue);
  });

  test('审批摘要按 action 生成', () {
    expect(
      skillManageConfirmSummary({'action': 'add', 'name': '代码审查'}),
      contains('新建技能「代码审查」'),
    );
    expect(
      skillManageConfirmSummary({'action': 'remove', 'id': 'skill_1'}),
      contains('删除技能「skill_1」'),
    );
    expect(
      skillManageConfirmSummary({
        'action': 'toggle',
        'name': '代码审查',
        'enabled': false,
      }),
      contains('停用技能「代码审查」'),
    );
  });
}
