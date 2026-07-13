import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/config/builtin_skills.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';

void main() {
  test('内置技能「子代理派发」存在且正文完整，read_skill 可读', () {
    final skill = kBuiltinSkills
        .where((s) => s.id == 'builtin-subagent-dispatch')
        .single;
    expect(skill.name, '子代理派发');
    expect(skill.content, contains('spawn_subagent'));
    expect(skill.content, contains('background'));
    expect(skill.content, contains('explore'));

    final result = executeReadSkill(kBuiltinSkills, {'skill_name': '子代理派发'});
    expect(result.isError, isFalse);
    expect(result.text, contains('prompt'));
  });
}
