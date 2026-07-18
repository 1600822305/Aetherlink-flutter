import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_approval_registry.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';

void main() {
  test('once / whitelist 不落规则', () {
    for (final scope in [AgentApprovalScope.once, AgentApprovalScope.whitelist]) {
      expect(
        approvalGrantRules(
          scope: scope,
          approved: true,
          permission: 'terminal_execute',
          patterns: const ['git status *'],
        ),
        isEmpty,
      );
    }
  });

  test('taskTool → 整工具 session allow', () {
    final rules = approvalGrantRules(
      scope: AgentApprovalScope.taskTool,
      approved: true,
      permission: 'terminal_execute',
      patterns: const ['git status *'],
    );
    expect(rules.single.pattern, '*');
    expect(rules.single.action, PermissionAction.allow);
    expect(rules.single.layer, PermissionRuleLayer.session);
  });

  test('taskPatterns / alwaysPatterns → 每个 pattern 一条 allow', () {
    final session = approvalGrantRules(
      scope: AgentApprovalScope.taskPatterns,
      approved: true,
      permission: 'terminal_execute',
      patterns: const ['git status *', 'npm run dev *'],
    );
    expect(session.map((r) => r.pattern), ['git status *', 'npm run dev *']);
    expect(session.every((r) => r.layer == PermissionRuleLayer.session), isTrue);

    final global = approvalGrantRules(
      scope: AgentApprovalScope.alwaysPatterns,
      approved: true,
      permission: 'terminal_execute',
      patterns: const ['npm run dev *'],
    );
    expect(global.single.layer, PermissionRuleLayer.userGlobal);
    expect(global.single.action, PermissionAction.allow);
  });

  test('denyPatterns → 拒绝时落 userGlobal deny，批准时不落', () {
    final rules = approvalGrantRules(
      scope: AgentApprovalScope.denyPatterns,
      approved: false,
      permission: 'mcp:srv/tool',
      patterns: const [],
    );
    expect(rules.single.pattern, '*');
    expect(rules.single.action, PermissionAction.deny);
    expect(rules.single.layer, PermissionRuleLayer.userGlobal);

    expect(
      approvalGrantRules(
        scope: AgentApprovalScope.denyPatterns,
        approved: true,
        permission: 'mcp:srv/tool',
        patterns: const [],
      ),
      isEmpty,
    );
  });

  test('批准类 scope 在拒绝时不落规则', () {
    for (final scope in [
      AgentApprovalScope.taskTool,
      AgentApprovalScope.taskPatterns,
      AgentApprovalScope.alwaysPatterns,
    ]) {
      expect(
        approvalGrantRules(
          scope: scope,
          approved: false,
          permission: 't',
          patterns: const ['*'],
        ),
        isEmpty,
      );
    }
  });
}
