import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/app/di/dynamic_tool_catalog.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/chat/application/tools/tool_routes.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_server.dart';
import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/domain/skill.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/load_mcp_tools_tool.dart';
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

  group('子代理派发延迟组', () {
    const subagentSkill = Skill(
      id: 'builtin-subagent-dispatch',
      name: '子代理派发',
      description: '',
      source: SkillSource.builtin,
      enabled: true,
      content: 'x',
    );
    const spawn = McpToolDefinition(name: 'spawn_subagent', description: '');

    test('读取「子代理派发」后 spawn_subagent 注入', () {
      final c = DynamicToolCatalog(
        resident: [readFile],
        deferred: {
          'builtin-subagent-dispatch': [spawn],
        },
        routes: {},
      );
      expect(
        c.definitionsFor(const {}).map((d) => d.name),
        isNot(contains('spawn_subagent')),
      );
      final activated = activatedSkillIdsFromEvents(
        [
          readSkillEvent(
            state: AgentToolCallState.success,
            argsDetail: '{"skill_name":"子代理派发"}',
          ),
        ],
        const [subagentSkill],
      );
      expect(activated, {'builtin-subagent-dispatch'});
      expect(
        c.definitionsFor(activated).map((d) => d.name),
        contains('spawn_subagent'),
      );
    });

    test('hasTool 覆盖常驻与延迟组，与激活状态无关', () {
      final c = DynamicToolCatalog(
        resident: [readFile],
        deferred: {
          'builtin-subagent-dispatch': [spawn],
        },
        routes: {},
      );
      expect(c.hasTool('read_file'), isTrue);
      expect(c.hasTool('spawn_subagent'), isTrue);
      expect(c.hasTool('nope'), isFalse);
    });
  });

  group('外部 MCP 延迟组（load_mcp_tools 激活）', () {
    const server = McpServer(
      id: 'srv-1',
      name: 'my-tools',
      type: McpServerType.stdio,
      isActive: true,
    );
    const servers = [server];

    ToolCallEvent loadEvent({
      required AgentToolCallState state,
      String? argsDetail,
      String? resultDetail,
    }) => readSkillEvent(
      state: state,
      argsDetail: argsDetail,
      resultDetail: resultDetail,
      toolName: kLoadMcpToolsToolName,
    );

    test('成功装载（名称）激活 mcp:<serverId> 组', () {
      final events = [
        loadEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"server":"my-tools"}',
        ),
      ];
      expect(activatedMcpServerKeysFromEvents(events, servers), {
        mcpDeferredKey('srv-1'),
      });
    });

    test('按 id 装载同样激活', () {
      final events = [
        loadEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"server":"srv-1"}',
        ),
      ];
      expect(activatedMcpServerKeysFromEvents(events, servers), {
        mcpDeferredKey('srv-1'),
      });
    });

    test('失败调用不激活', () {
      final events = [
        loadEvent(
          state: AgentToolCallState.failure,
          argsDetail: '{"server":"my-tools"}',
        ),
      ];
      expect(activatedMcpServerKeysFromEvents(events, servers), isEmpty);
    });

    test('argsDetail 缺失时回退解析结果「已装载服务器「名称」」', () {
      final events = [
        loadEvent(
          state: AgentToolCallState.success,
          resultDetail: '已装载服务器「my-tools」的 2 个工具，…',
        ),
      ];
      expect(activatedMcpServerKeysFromEvents(events, servers), {
        mcpDeferredKey('srv-1'),
      });
    });

    test('未知服务器名安全忽略', () {
      final events = [
        loadEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"server":"nope"}',
        ),
      ];
      expect(activatedMcpServerKeysFromEvents(events, servers), isEmpty);
    });

    test('read_skill 事件不参与 MCP 激活', () {
      final events = [
        readSkillEvent(
          state: AgentToolCallState.success,
          argsDetail: '{"server":"my-tools"}',
        ),
      ];
      expect(activatedMcpServerKeysFromEvents(events, servers), isEmpty);
    });

    test('definitionsFor 接受 mcp: key 激活组', () {
      const extTool = McpToolDefinition(name: 'ext_tool', description: '');
      final c = DynamicToolCatalog(
        resident: [readFile],
        deferred: {
          mcpDeferredKey('srv-1'): [extTool],
        },
        routes: {},
        deferredMcpLabels: {mcpDeferredKey('srv-1'): 'my-tools'},
      );
      expect(
        c.definitionsFor(const {}).map((d) => d.name),
        isNot(contains('ext_tool')),
      );
      expect(
        c.definitionsFor({mcpDeferredKey('srv-1')}).map((d) => d.name),
        contains('ext_tool'),
      );
    });

    test('matchMcpServerByName：id → 名称精确 → 忽略大小写 → 子串', () {
      expect(matchMcpServerByName(servers, 'srv-1')?.id, 'srv-1');
      expect(matchMcpServerByName(servers, 'my-tools')?.id, 'srv-1');
      expect(matchMcpServerByName(servers, 'MY-TOOLS')?.id, 'srv-1');
      expect(matchMcpServerByName(servers, 'tools')?.id, 'srv-1');
      expect(matchMcpServerByName(servers, 'nope'), isNull);
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
