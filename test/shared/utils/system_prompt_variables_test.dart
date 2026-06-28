import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/domain/system_prompt_variables.dart';
import 'package:aetherlink_flutter/shared/utils/system_prompt_variables.dart';

void main() {
  group('injectSystemPromptVariables (append-only)', () {
    test('returns empty prompt unchanged', () {
      expect(
        injectSystemPromptVariables('', const SystemPromptVariables()),
        '',
      );
    });

    test('returns prompt unchanged when no variable is enabled', () {
      expect(
        injectSystemPromptVariables('hi', const SystemPromptVariables()),
        'hi',
      );
    });

    test('appends the custom location when location is enabled', () {
      final out = injectSystemPromptVariables(
        'base',
        const SystemPromptVariables(
          enableLocationVariable: true,
          customLocation: '北京市朝阳区',
        ),
      );
      expect(out, 'base\n\n当前位置：北京市朝阳区');
    });

    test('appends the locale line when locale is enabled', () {
      final out = injectSystemPromptVariables(
        'base',
        const SystemPromptVariables(enableLocaleVariable: true),
      );
      expect(out, startsWith('base\n\n当前语言：'));
      expect(out, isNot('base'));
    });

    test('appends multiple variables in order (time → os → locale)', () {
      final out = injectSystemPromptVariables(
        'base',
        const SystemPromptVariables(
          enableTimeVariable: true,
          enableOSVariable: true,
          enableLocaleVariable: true,
        ),
      );
      final timeIdx = out.indexOf('当前时间：');
      final osIdx = out.indexOf('操作系统：');
      final localeIdx = out.indexOf('当前语言：');
      expect(timeIdx, isNonNegative);
      expect(osIdx, greaterThan(timeIdx));
      expect(localeIdx, greaterThan(osIdx));
    });
  });

  group('replaceSystemPromptPlaceholders (inline substitution)', () {
    String run(String text) => replaceSystemPromptPlaceholders(
      text,
      modelName: 'GPT-Test',
      modelId: 'gpt-test-1',
      assistantName: '小助手',
      providerName: 'OpenAI',
    );

    test('returns empty / brace-less text unchanged (fast path)', () {
      expect(run(''), '');
      expect(run('no placeholders here'), 'no placeholders here');
    });

    test('substitutes model, assistant and provider tokens', () {
      expect(
        run('你是{assistant_name}，由{provider_name}的{model_name}（{model_id}）驱动'),
        '你是小助手，由OpenAI的GPT-Test（gpt-test-1）驱动',
      );
    });

    test('replaces every occurrence of a token', () {
      expect(run('{model_name} {model_name}'), 'GPT-Test GPT-Test');
    });

    test('leaves unknown placeholders untouched', () {
      expect(run('hello {unknown}'), 'hello {unknown}');
    });

    test('resolves date/time tokens to the expected ISO-ish shapes', () {
      final out = run('{cur_date} | {cur_time} | {cur_datetime}');
      final parts = out.split(' | ');
      expect(parts[0], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(parts[1], matches(RegExp(r'^\d{2}:\d{2}$')));
      expect(parts[2], matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
    });
  });
}
