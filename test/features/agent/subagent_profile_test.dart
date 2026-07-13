import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/domain/subagent_profile.dart';

void main() {
  test('frontmatter 完整档案：name/description/readonly + 正文', () {
    const content = '''
---
name: code-reviewer
description: 审查代码改动并给出意见
readonly: true
---
你是代码审查子代理，只读检查改动。''';
    final p = parseSubagentProfileMarkdown('reviewer.md', content);
    expect(p, isNotNull);
    expect(p!.name, 'code-reviewer');
    expect(p.description, '审查代码改动并给出意见');
    expect(p.readonly, isTrue);
    expect(p.systemPrompt, '你是代码审查子代理，只读检查改动。');
  });

  test('readonly: false 生效', () {
    const content = '''
---
description: 修 bug
readonly: false
---
修复指定 bug。''';
    final p = parseSubagentProfileMarkdown('fixer.md', content);
    expect(p!.readonly, isFalse);
    expect(p.name, 'fixer'); // name 缺省取文件名去 .md
  });

  test('无 frontmatter：整个文件作为系统提示，默认只读', () {
    final p = parseSubagentProfileMarkdown('doc-writer.md', '写文档的子代理。');
    expect(p!.name, 'doc-writer');
    expect(p.readonly, isTrue);
    expect(p.systemPrompt, '写文档的子代理。');
    expect(p.description, '');
  });

  test('frontmatter 未闭合：按无 frontmatter 处理', () {
    const content = '---\nname: broken\n正文';
    final p = parseSubagentProfileMarkdown('broken.md', content);
    expect(p!.name, 'broken');
    expect(p.systemPrompt, content.trim());
  });

  test('空档案无效', () {
    expect(parseSubagentProfileMarkdown('empty.md', ''), isNull);
    expect(parseSubagentProfileMarkdown('empty.md', '---\n---\n'), isNull);
  });

  test('description 冒号后带冒号的值完整保留', () {
    const content = '''
---
description: 用法：跑测试并总结
---
跑测试。''';
    final p = parseSubagentProfileMarkdown('t.md', content);
    expect(p!.description, '用法：跑测试并总结');
  });
}
