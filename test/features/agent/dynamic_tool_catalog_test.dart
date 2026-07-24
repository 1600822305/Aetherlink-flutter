import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/dynamic_tool_catalog.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/skill_read_tool.dart';

void main() {
  const readFile = McpToolDefinition(name: 'read_file', description: '');
  const browserOpen = McpToolDefinition(name: 'browser_open', description: '');
  const browserClick = McpToolDefinition(
    name: 'browser_click',
    description: '',
  );

  DynamicToolCatalog catalog() => DynamicToolCatalog(
    resident: [readFile],
    deferred: {
      'builtin-browser': [browserOpen, browserClick],
    },
    routes: {
      'read_file': const FileEditorToolRoute('read_file'),
      'browser_open': const BuiltinToolRoute('@aether/browser', 'browser_open'),
      'browser_click': const BuiltinToolRoute(
        '@aether/browser',
        'browser_click',
      ),
    },
  );

  const browserSkill = Skill(
    id: 'builtin-browser',
    name: '内置浏览器',
    description: '',
    source: SkillSource.builtin,
    enabled: true,
    content: 'x',
  );
  const otherSkill = Skill(
    id: 'other',
    name: '代码审查',
    description: '',
    source: SkillSource.builtin,
    enabled: true,
    content: 'x',
  );
  const skills = [browserSkill, otherSkill];

  ToolCallEvent readSkillEvent({
    required AgentToolCallState state,
    String? argsDetail,
    String? resultDetail,
    String toolName = kReadSkillToolName,
  }) => ToolCallEvent(
    id: 'e1',
    seq: 1,
    at: DateTime(2026),
    toolName: toolName,
    argSummary: '',
    state: state,
    argsDetail: argsDetail,
    resultDetail: resultDetail,
  );

  group('DynamicToolCatalog.definitionsFor', () {
    test('未激活时不含延迟组，routes 仍全量', () {
      final c = catalog();
      final defs = c.definitionsFor(const {});
      expect(defs.map((d) => d.name), ['read_file']);
      expect(
        c.routes.keys,
        containsAll(['read_file', 'browser_open', 'browser_click']),
      );
    });

    test('激活后追加延迟组，常驻不变', () {
      final defs = catalog().definitionsFor(const {'builtin-browser'});
      expect(defs.map((d) => d.name), [
        'read_file',
        'browser_open',
        'browser_click',
      ]);
    });

    test('未知 skillId 安全忽略', () {
      final defs = catalog().definitionsFor(const {'nope'});
      expect(defs.map((d) => d.name), ['read_file']);
    });
  });

  group('activatedSkillIdsFromEvents', () {
    test('成功 read_skill（精确名）激活绑定组', () {
      final events = [
        readSkillEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"skill_name":"内置浏览器"}',
        ),
      ];
      expect(activatedSkillIdsFromEvents(events, skills), {'builtin-browser'});
    });

    test('子串匹配与 executeReadSkill 一致', () {
      final events = [
        readSkillEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"skill_name":"浏览器"}',
        ),
      ];
      expect(activatedSkillIdsFromEvents(events, skills), {'builtin-browser'});
    });

    test('失败调用不激活', () {
      final events = [
        readSkillEvent(
          state: AgentToolCallState.failure,
          argsDetail: '{"skill_name":"内置浏览器"}',
        ),
      ];
      expect(activatedSkillIdsFromEvents(events, skills), isEmpty);
    });

    test('读无绑定技能不激活', () {
      final events = [
        readSkillEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"skill_name":"代码审查"}',
        ),
      ];
      expect(activatedSkillIdsFromEvents(events, skills), isEmpty);
    });

    test('argsDetail 缺失时回退解析结果首行「# 技能名」', () {
      final events = [
        readSkillEvent(
          state: AgentToolCallState.success,
          resultDetail: '# 内置浏览器\n\n正文',
        ),
      ];
      expect(activatedSkillIdsFromEvents(events, skills), {'builtin-browser'});
    });

    test('非 read_skill 工具不参与', () {
      final events = [
        readSkillEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"skill_name":"内置浏览器"}',
          toolName: 'read_file',
        ),
      ];
      expect(activatedSkillIdsFromEvents(events, skills), isEmpty);
    });

    test('重复读取幂等（集合语义）', () {
      final events = [
        readSkillEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"skill_name":"内置浏览器"}',
        ),
        readSkillEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"skill_name":"内置浏览器"}',
        ),
      ];
      expect(activatedSkillIdsFromEvents(events, skills), {'builtin-browser'});
    });
  });

  test('matchSkillByName 三段式：精确 → 忽略大小写 → 子串', () {
    const en = Skill(
      id: 'en',
      name: 'Browser',
      description: '',
      source: SkillSource.builtin,
    );
    expect(matchSkillByName(const [en], 'Browser')?.id, 'en');
    expect(matchSkillByName(const [en], 'browser')?.id, 'en');
    expect(matchSkillByName(const [en], 'rows')?.id, 'en');
    expect(matchSkillByName(const [en], 'nope'), isNull);
  });
}
