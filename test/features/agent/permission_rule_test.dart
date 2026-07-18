import 'package:aetherlink_flutter/features/agent/domain/permission_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('permissionWildcardMatch', () {
    test('* 匹配任意串', () {
      expect(permissionWildcardMatch('anything', '*'), isTrue);
      expect(permissionWildcardMatch('', '*'), isTrue);
    });

    test('前缀通配（尾部 ` *` 含裸前缀本身）', () {
      expect(permissionWildcardMatch('npm run dev', 'npm run *'), isTrue);
      expect(permissionWildcardMatch('npm run', 'npm run *'), isTrue);
      expect(permissionWildcardMatch('npm runx', 'npm run *'), isFalse);
      expect(permissionWildcardMatch('npm install', 'npm run *'), isFalse);
    });

    test('中缀通配与大小写不敏感', () {
      expect(permissionWildcardMatch('src/foo/bar.dart', 'src/*.dart'), isTrue);
      expect(permissionWildcardMatch('NPM RUN DEV', 'npm run *'), isTrue);
    });

    test('正则元字符按字面匹配', () {
      expect(permissionWildcardMatch('a.b', 'a.b'), isTrue);
      expect(permissionWildcardMatch('axb', 'a.b'), isFalse);
      expect(permissionWildcardMatch('f(x)', 'f(x)'), isTrue);
    });
  });

  group('evaluatePermissionRule', () {
    test('无命中默认 ask', () {
      final rule = evaluatePermissionRule('terminal', 'rm x', const []);
      expect(rule.action, PermissionAction.ask);
    });

    test('后层覆盖前层（最后命中者胜）', () {
      const low = [
        PermissionRule(permission: 'terminal', action: PermissionAction.ask),
      ];
      const high = [
        PermissionRule(
          permission: 'terminal',
          pattern: 'git *',
          action: PermissionAction.allow,
          layer: PermissionRuleLayer.userGlobal,
        ),
      ];
      final rule = evaluatePermissionRule('terminal', 'git status', [low, high]);
      expect(rule.action, PermissionAction.allow);
      expect(rule.layer, PermissionRuleLayer.userGlobal);
    });

    test('同层内后写的规则覆盖先写的', () {
      const layer = [
        PermissionRule(
          permission: 'edit',
          pattern: '*',
          action: PermissionAction.allow,
        ),
        PermissionRule(
          permission: 'edit',
          pattern: '*.env',
          action: PermissionAction.deny,
        ),
      ];
      expect(
        evaluatePermissionRule('edit', 'config.env', [layer]).action,
        PermissionAction.deny,
      );
      expect(
        evaluatePermissionRule('edit', 'main.dart', [layer]).action,
        PermissionAction.allow,
      );
    });

    test('permission 域本身支持通配', () {
      const layer = [
        PermissionRule(
          permission: 'mcp:*',
          action: PermissionAction.ask,
        ),
      ];
      expect(
        evaluatePermissionRule('mcp:github/create_issue', 'x', [layer]).action,
        PermissionAction.ask,
      );
    });
  });

  group('evaluatePermissionRequest', () {
    const layers = [
      [
        PermissionRule(
          permission: 'terminal',
          pattern: 'git *',
          action: PermissionAction.allow,
        ),
        PermissionRule(
          permission: 'terminal',
          pattern: 'rm *',
          action: PermissionAction.deny,
        ),
      ],
    ];

    test('全部 allow → allow', () {
      final d = evaluatePermissionRequest(
          'terminal', ['git status', 'git diff'], layers);
      expect(d.action, PermissionAction.allow);
    });

    test('任一 deny → deny（即使其它 allow）', () {
      final d = evaluatePermissionRequest(
          'terminal', ['git status', 'rm -rf build'], layers);
      expect(d.action, PermissionAction.deny);
      expect(d.matched.pattern, 'rm *');
    });

    test('部分无规则 → ask，askPatterns 只含未放行的', () {
      final d = evaluatePermissionRequest(
          'terminal', ['git status', 'npm install'], layers);
      expect(d.action, PermissionAction.ask);
      expect(d.askPatterns, ['npm install']);
    });

    test('patterns 为空按 * 判定', () {
      final d = evaluatePermissionRequest('terminal', const [], layers);
      expect(d.action, PermissionAction.ask);
      expect(d.askPatterns, ['*']);
    });
  });
}
