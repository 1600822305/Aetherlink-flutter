import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/domain/assistant_regex.dart';
import 'package:aetherlink_flutter/shared/utils/silly_tavern_regex_import.dart';

void main() {
  group('isSillyTavernRegexFormat', () {
    test('accepts a single script object', () {
      expect(
        isSillyTavernRegexFormat({'scriptName': 'a', 'findRegex': 'x'}),
        isTrue,
      );
    });

    test('accepts an array of scripts', () {
      expect(
        isSillyTavernRegexFormat([
          {'findRegex': 'x'},
        ]),
        isTrue,
      );
    });

    test('rejects scripts without name or regex', () {
      expect(isSillyTavernRegexFormat({'replaceString': 'y'}), isFalse);
    });

    test('rejects non-list placement', () {
      expect(
        isSillyTavernRegexFormat({'findRegex': 'x', 'placement': 0}),
        isFalse,
      );
    });

    test('rejects null and empty list', () {
      expect(isSillyTavernRegexFormat(null), isFalse);
      expect(isSillyTavernRegexFormat([]), isFalse);
    });
  });

  group('importSillyTavernRegexScripts', () {
    test('converts placement, {{match}} macro and flags', () {
      final json = jsonEncode([
        {
          'scriptName': '强调',
          'findRegex': r'\*(.+?)\*',
          'replaceString': '<b>{{match}}</b>',
          'placement': [0, 1],
          'markdownOnly': true,
          'disabled': false,
        },
      ]);
      final rules = importSillyTavernRegexScripts(json);
      expect(rules, hasLength(1));
      final rule = rules.single;
      expect(rule.name, '强调');
      expect(rule.pattern, r'\*(.+?)\*');
      expect(rule.replacement, r'<b>$&</b>');
      expect(rule.scopes, [
        AssistantRegexScope.user,
        AssistantRegexScope.assistant,
      ]);
      expect(rule.visualOnly, isTrue);
      expect(rule.enabled, isTrue);
    });

    test('disabled flag inverts enabled and defaults scope to assistant', () {
      final json = jsonEncode({
        'findRegex': 'x',
        'replaceString': 'y',
        'disabled': true,
      });
      final rule = importSillyTavernRegexScripts(json).single;
      expect(rule.enabled, isFalse);
      expect(rule.scopes, [AssistantRegexScope.assistant]);
      expect(rule.name, '未命名规则');
    });

    test('skips invalid entries but keeps valid ones', () {
      final json = jsonEncode([
        {'replaceString': 'orphan'},
        {'findRegex': 'keep'},
      ]);
      expect(importSillyTavernRegexScripts(json), hasLength(1));
    });

    test('invalid JSON throws SillyTavernImportException', () {
      expect(
        () => importSillyTavernRegexScripts('not json'),
        throwsA(isA<SillyTavernImportException>()),
      );
    });
  });
}
