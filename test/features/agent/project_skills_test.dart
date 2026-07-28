import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/agent_project_skills_access.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';

import '../workspace/in_memory_workspace_backend.dart';

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

  test('packageDir 透传进 Skill；单文件技能恒为 null', () {
    final packaged = parseProjectSkillMarkdown(
      'pptx',
      '---\nname: pptx\n---\n正文',
      sourceDir: '.claude/skills',
      packageDir: '.claude/skills/pptx',
    );
    expect(packaged.packageDir, '.claude/skills/pptx');
    final single = parseProjectSkillMarkdown(
      'deploy',
      '正文',
      sourceDir: '.agents/skills',
    );
    expect(single.packageDir, isNull);
  });

  test('walkSkillPackageFiles：递归列资源、跳过顶层 SKILL.md、限深度', () async {
    final backend = InMemoryWorkspaceBackend();
    const pkg = '.claude/skills/pptx';
    backend.seedFile('/ws/$pkg/SKILL.md', '---\nname: pptx\n---\n正文');
    backend.seedFile('/ws/$pkg/scripts/render.py', 'print(1)');
    backend.seedFile('/ws/$pkg/references/ooxml.md', '# ooxml');
    backend.seedFile('/ws/$pkg/references/deep/a/b/c/too_deep.md', 'x');
    backend.seedFile('/ws/$pkg/scripts/SKILL.md', '非顶层同名不跳过');

    final files = await walkSkillPackageFiles(backend, '/ws', pkg);
    expect(files, contains('$pkg/scripts/render.py'));
    expect(files, contains('$pkg/references/ooxml.md'));
    expect(files, contains('$pkg/scripts/SKILL.md'));
    expect(files, isNot(contains('$pkg/SKILL.md')));
    expect(files.any((f) => f.endsWith('too_deep.md')), isFalse);
  });

  test('walkSkillPackageFiles：目录不存在返回空、条目数封顶', () async {
    final backend = InMemoryWorkspaceBackend();
    expect(
      await walkSkillPackageFiles(backend, '/ws', '.claude/skills/none'),
      isEmpty,
    );

    const pkg = '.agents/skills/big';
    backend.seedFile('/ws/$pkg/SKILL.md', '正文');
    for (var i = 0; i < kSkillPackageMaxEntries + 20; i++) {
      backend.seedFile('/ws/$pkg/assets/f$i.txt', '');
    }
    final files = await walkSkillPackageFiles(backend, '/ws', pkg);
    expect(files.length, kSkillPackageMaxEntries);
  });

  test('扫描目录顺序：.aetherlink 优先', () {
    expect(kProjectSkillDirs.first, '.aetherlink/skills');
    expect(kProjectSkillDirs, contains('.claude/skills'));
    expect(kProjectSkillDirs, contains('.cursor/skills'));
    expect(kProjectSkillDirs, contains('.agents/skills'));
  });
}
