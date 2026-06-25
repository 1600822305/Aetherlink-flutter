import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/utils/regex_replacement.dart';

AssistantRegex _rule({
  String pattern = 'foo',
  String replacement = 'bar',
  List<AssistantRegexScope> scopes = const [AssistantRegexScope.user],
  bool visualOnly = false,
  bool enabled = true,
}) => AssistantRegex(
  id: 'r',
  name: 'r',
  pattern: pattern,
  replacement: replacement,
  scopes: scopes,
  visualOnly: visualOnly,
  enabled: enabled,
);

void main() {
  group('applyRegexRule', () {
    test('replaces all matches', () {
      expect(applyRegexRule('foo foo', _rule()), 'bar bar');
    });

    test(r'expands $1 capture group', () {
      final rule = _rule(pattern: r'(\w+)@(\w+)', replacement: r'$2.$1');
      expect(applyRegexRule('a@b', rule), 'b.a');
    });

    test(r'expands $& full match', () {
      final rule = _rule(pattern: r'\d+', replacement: r'[$&]');
      expect(applyRegexRule('x12y', rule), 'x[12]y');
    });

    test(r'expands $$ to literal dollar', () {
      final rule = _rule(pattern: 'a', replacement: r'$$');
      expect(applyRegexRule('a', rule), r'$');
    });

    test('expands named group', () {
      final rule = _rule(pattern: r'(?<word>\w+)', replacement: r'<${word}>');
      expect(applyRegexRule('hi', rule), '<hi>');
    });

    test('invalid pattern returns text unchanged', () {
      final rule = _rule(pattern: '(unclosed');
      expect(applyRegexRule('keep', rule), 'keep');
    });

    test('disabled rule is a no-op', () {
      expect(applyRegexRule('foo', _rule(enabled: false)), 'foo');
    });
  });

  group('applyRegexRules scope & order', () {
    test('only applies rules matching the scope', () {
      final rules = [
        _rule(
          pattern: 'a',
          replacement: 'X',
          scopes: const [AssistantRegexScope.user],
        ),
        _rule(
          pattern: 'b',
          replacement: 'Y',
          scopes: const [AssistantRegexScope.assistant],
        ),
      ];
      expect(applyRegexRules('ab', rules, AssistantRegexScope.user), 'Xb');
    });

    test('applies rules sequentially in order', () {
      final rules = [
        _rule(pattern: 'a', replacement: 'b'),
        _rule(pattern: 'b', replacement: 'c'),
      ];
      expect(applyRegexRules('a', rules, AssistantRegexScope.user), 'c');
    });
  });

  group('sending vs display visualOnly filtering', () {
    final rules = [
      _rule(pattern: 'x', replacement: 'normal', visualOnly: false),
      _rule(pattern: 'y', replacement: 'visual', visualOnly: true),
    ];

    test('sending skips visualOnly rules', () {
      expect(
        applyRegexRulesForSending('x y', rules, AssistantRegexScope.user),
        'normal y',
      );
    });

    test('display applies all rules', () {
      expect(
        applyRegexRulesForDisplay('x y', rules, AssistantRegexScope.user),
        'normal visual',
      );
    });
  });

  group('hasApplicableRules', () {
    test('false for null/empty', () {
      expect(hasApplicableRules(null, AssistantRegexScope.user), isFalse);
      expect(hasApplicableRules(const [], AssistantRegexScope.user), isFalse);
    });

    test('respects scope, enabled and visualOnly filters', () {
      final rules = [_rule(visualOnly: true)];
      expect(hasApplicableRules(rules, AssistantRegexScope.user), isTrue);
      expect(
        hasApplicableRules(rules, AssistantRegexScope.user, visualOnly: false),
        isFalse,
      );
      expect(hasApplicableRules(rules, AssistantRegexScope.assistant), isFalse);
    });
  });
}
