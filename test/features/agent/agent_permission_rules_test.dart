import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_permission_rules.dart';
import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';

void main() {
  test('encode/decode round-trips rules as userGlobal layer', () {
    const rules = [
      PermissionRule(
        permission: 'terminal_execute',
        pattern: 'npm run *',
        action: PermissionAction.allow,
      ),
      PermissionRule(
        permission: 'terminal_*',
        pattern: 'rm -rf *',
        action: PermissionAction.deny,
      ),
    ];
    final decoded = decodeAgentPermissionRules(encodeAgentPermissionRules(rules))!;
    expect(decoded.length, 2);
    expect(decoded[0].permission, 'terminal_execute');
    expect(decoded[0].pattern, 'npm run *');
    expect(decoded[0].action, PermissionAction.allow);
    expect(decoded[0].layer, PermissionRuleLayer.userGlobal);
    expect(decoded[1].action, PermissionAction.deny);
  });

  test('decode rejects bad input and drops malformed entries', () {
    expect(decodeAgentPermissionRules(null), null);
    expect(decodeAgentPermissionRules(''), null);
    expect(decodeAgentPermissionRules('not json'), null);
    expect(decodeAgentPermissionRules('{"a":1}'), null);
    final decoded = decodeAgentPermissionRules(
      '[{"permission":"t","pattern":"*","action":"allow"},'
      '{"permission":"t","pattern":"*","action":"nope"},'
      '{"permission":"","pattern":"*","action":"deny"},'
      '"junk"]',
    )!;
    expect(decoded.length, 1);
    expect(decoded.single.action, PermissionAction.allow);
  });
}
