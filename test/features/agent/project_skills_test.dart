import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/agent_project_skills_access.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

void main() {
  test('解析带 frontmatter 的 SKILL.md：name/description/正文', () {
    final skill = parseProjectSkillMarkdown(
      'code-review',
      '---\n'
          'name: 代码审查\n'
          'description: "按团队规范审查 PR"\n'
          '---\n'
          '## 步骤\n先看 diff。',
      sourceDir: '.claude/skills',
    );
    expect(skill.name, '代码审查');
    expect(skill.description, '按团队规范审查 PR');
    expect(skill.content, '## 步骤\n先看 diff。');
    expect(skill.id, '$kProjectSkillIdPrefix.claude/skills/code-review');
    expect(skill.enabled, isTrue);
    expect(skill.source, SkillSource.user);
  });

  test('无 frontmatter 时用目录/文件名兜底，全文作正文', () {
    final skill = parseProjectSkillMarkdown(
      'deploy',
      '## 部署流程\n跑 make deploy。',
      sourceDir: '.agents/skills',
    );
    expect(skill.name, 'deploy');
    expect(skill.description, isEmpty);
    expect(skill.content, contains('部署流程'));
  });

  test('frontmatter 未闭合时不吞正文', () {
    final skill = parseProjectSkillMarkdown(
      'broken',
      '---\nname: x\n正文没闭合',
      sourceDir: '.cursor/skills',
    );
    expect(skill.name, 'broken');
    expect(skill.content, contains('正文没闭合'));
  });

  test('扫描目录顺序：.aetherlink 优先', () {
    expect(kProjectSkillDirs.first, '.aetherlink/skills');
    expect(kProjectSkillDirs, contains('.claude/skills'));
    expect(kProjectSkillDirs, contains('.cursor/skills'));
    expect(kProjectSkillDirs, contains('.agents/skills'));
  });
}
