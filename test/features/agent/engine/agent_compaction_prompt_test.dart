import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_compaction_prompt.dart';

void main() {
  group('extractCompactionSummary', () {
    test('剥离 analysis 草稿块，解包 summary 正文', () {
      const raw = '<analysis>逐段梳理……</analysis>\n'
          '<summary>1. 用户请求与意图：修 bug</summary>';
      expect(extractCompactionSummary(raw), '1. 用户请求与意图：修 bug');
    });

    test('只有 summary 标签也能解包', () {
      const raw = '<summary>正文</summary>';
      expect(extractCompactionSummary(raw), '正文');
    });

    test('summary 未闭合时取到结尾', () {
      const raw = '<analysis>a</analysis><summary>未闭合的正文';
      expect(extractCompactionSummary(raw), '未闭合的正文');
    });

    test('analysis 未闭合时剥掉其后全部（草稿不落库）', () {
      const raw = '前置文字<analysis>没闭合的草稿';
      expect(extractCompactionSummary(raw), '前置文字');
    });

    test('无标签时原样返回修剪后的全文（格式失败不丢摘要）', () {
      const raw = '  模型没按格式，直接输出了摘要正文。  ';
      expect(extractCompactionSummary(raw), '模型没按格式，直接输出了摘要正文。');
    });

    test('summary 内的多行结构保留', () {
      const raw = '<summary>\n1. A\n2. B\n</summary>';
      expect(extractCompactionSummary(raw), '1. A\n2. B');
    });
  });

  group('compactionSummarySystemPrompt（升级计划 ⑦）', () {
    test('无自定义指令时返回基础提示词', () {
      expect(compactionSummarySystemPrompt(), kCompactionSummarySystemPrompt);
      expect(
        compactionSummarySystemPrompt(customInstructions: '  '),
        kCompactionSummarySystemPrompt,
      );
    });

    test('有自定义指令时附在基础提示词后', () {
      final prompt =
          compactionSummarySystemPrompt(customInstructions: '重点保留报错细节');
      expect(prompt, startsWith(kCompactionSummarySystemPrompt));
      expect(prompt, contains('附加指令'));
      expect(prompt, endsWith('重点保留报错细节'));
    });
  });

  test('系统提示词包含关键小节要求', () {
    expect(kCompactionSummarySystemPrompt, contains('<analysis>'));
    expect(kCompactionSummarySystemPrompt, contains('<summary>'));
    expect(kCompactionSummarySystemPrompt, contains('用户请求与意图'));
    expect(kCompactionSummarySystemPrompt, contains('报错与修复'));
    expect(kCompactionSummarySystemPrompt, contains('待办事项'));
    expect(kCompactionSummarySystemPrompt, contains('下一步'));
  });
}
