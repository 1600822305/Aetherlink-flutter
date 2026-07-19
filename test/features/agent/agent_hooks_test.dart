import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';

void main() {
  group('decodeAgentHooksConfig', () {
    test('完整配置解析：三个事件 + 默认值', () {
      final config = decodeAgentHooksConfig('''
{
  "preToolUse": [
    {"type": "command", "matcher": "terminal_execute",
     "pattern": "git push *", "command": "sh check.sh", "timeout": 10}
  ],
  "postToolUse": [
    {"type": "command", "matcher": "write", "command": "dart format ."}
  ],
  "stop": [{"type": "command", "command": "flutter analyze"}]
}
''')!;
      expect(config.hooks.length, 3);
      final pre = config.ofEvent(AgentHookEvent.preToolUse).single;
      expect(pre.matcher, 'terminal_execute');
      expect(pre.pattern, 'git push *');
      expect(pre.timeoutSeconds, 10);
      final post = config.ofEvent(AgentHookEvent.postToolUse).single;
      expect(post.pattern, '*');
      expect(post.timeoutSeconds, kAgentHookDefaultTimeoutSeconds);
      expect(config.ofEvent(AgentHookEvent.stop).single.matcher, '*');
    });

    test('坏 JSON / 非对象 / 空串返回 null', () {
      expect(decodeAgentHooksConfig('not json'), isNull);
      expect(decodeAgentHooksConfig('[1,2]'), isNull);
      expect(decodeAgentHooksConfig(''), isNull);
      expect(decodeAgentHooksConfig(null), isNull);
    });

    test('缺 type / 缺载体 / 类型不对的条目丢弃，未知事件键忽略', () {
      final config = decodeAgentHooksConfig('''
{
  "preToolUse": [
    {"matcher": "x"}, "junk",
    {"command": "无 type 不再默认 command"},
    {"type": "weird", "command": "x"},
    {"type": "command"},
    {"type": "prompt", "command": "载体字段不对"},
    {"type": "http"},
    {"type": "command", "command": "ok"}
  ],
  "unknownEvent": [{"type": "command", "command": "nope"}]
}
''')!;
      expect(config.hooks.single.command, 'ok');
    });

    test('新类型解析：prompt / http（含 headers）', () {
      final config = decodeAgentHooksConfig('''
{
  "preToolUse": [
    {"type": "prompt", "matcher": "write",
     "prompt": "安全吗？\$ARGUMENTS", "timeout": 20},
    {"type": "http", "url": "https://example.com/hook",
     "headers": {"Authorization": "Bearer x", "bad": 1}}
  ]
}
''')!;
      final prompt = config.hooks[0];
      expect(prompt.type, AgentHookType.prompt);
      expect(prompt.prompt, '安全吗？\$ARGUMENTS');
      expect(prompt.payload, prompt.prompt);
      expect(prompt.matcher, 'write');
      expect(prompt.timeoutSeconds, 20);
      expect(prompt.command, '');
      final http = config.hooks[1];
      expect(http.type, AgentHookType.http);
      expect(http.url, 'https://example.com/hook');
      expect(http.payload, http.url);
      expect(http.headers, {'Authorization': 'Bearer x'});
    });

    test('postToolUseFailure 事件解析与匹配', () {
      final config = decodeAgentHooksConfig('''
{"postToolUseFailure": [
  {"type": "command", "matcher": "terminal_*", "command": "diagnose.sh"}]}
''')!;
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.postToolUseFailure,
        'terminal_execute',
        ['git push origin main'],
      );
      expect(hooks.single.command, 'diagnose.sh');
      expect(
        hooksForToolCall(
          config,
          AgentHookEvent.postToolUse,
          'terminal_execute',
          ['ls'],
        ),
        isEmpty,
      );
    });

    test('subagentStart / subagentStop / taskEnd 事件解析', () {
      final config = decodeAgentHooksConfig('''
{
  "subagentStart": [{"type": "command", "command": "log_start.sh"}],
  "subagentStop": [{"type": "command", "command": "verify.sh"}],
  "taskEnd": [{"type": "command", "command": "notify.sh"}]
}
''')!;
      expect(config.ofEvent(AgentHookEvent.subagentStart).single.command,
          'log_start.sh');
      expect(config.ofEvent(AgentHookEvent.subagentStop).single.command,
          'verify.sh');
      expect(
          config.ofEvent(AgentHookEvent.taskEnd).single.command, 'notify.sh');
    });

    test('非法 timeout 回退默认', () {
      final config = decodeAgentHooksConfig(
        '{"stop":[{"type":"command","command":"c","timeout":-5}]}',
      )!;
      expect(config.hooks.single.timeoutSeconds, kAgentHookDefaultTimeoutSeconds);
    });
  });

  group('hooksForToolCall', () {
    final config = decodeAgentHooksConfig('''
{
  "preToolUse": [
    {"type": "command", "matcher": "terminal_execute",
     "pattern": "git push *", "command": "a"},
    {"type": "command", "matcher": "terminal_*", "command": "b"},
    {"type": "command", "matcher": "write", "command": "c"}
  ]
}
''')!;

    test('matcher + pattern 双重命中', () {
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.preToolUse,
        'terminal_execute',
        ['git push origin main'],
      );
      expect(hooks.map((h) => h.command), ['a', 'b']);
    });

    test('pattern 不命中时只剩通配 hook', () {
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.preToolUse,
        'terminal_execute',
        ['ls -la'],
      );
      expect(hooks.map((h) => h.command), ['b']);
    });

    test('patterns 为空按 * 处理（非终端工具）', () {
      final hooks = hooksForToolCall(
        config,
        AgentHookEvent.preToolUse,
        'write',
        const [],
      );
      expect(hooks.single.command, 'c');
    });

    test('事件不匹配返回空', () {
      expect(
        hooksForToolCall(
          config,
          AgentHookEvent.postToolUse,
          'terminal_execute',
          ['ls'],
        ),
        isEmpty,
      );
    });
  });

  group('buildAgentHookStdinJson', () {
    test('args 可解析时以 JSON 对象嵌入，含全部上下文字段', () {
      final raw = buildAgentHookStdinJson(
        eventName: 'postToolUse',
        toolName: 'terminal_execute',
        argsJson: '{"command":"ls -la"}',
        filePath: '/ws/a.dart',
        toolOutput: 'total 0',
        toolOk: true,
        sessionId: 'ws-1',
        cwd: '/ws',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['hook_event_name'], 'postToolUse');
      expect(json['tool_name'], 'terminal_execute');
      expect((json['tool_input'] as Map)['command'], 'ls -la');
      expect(json['file_path'], '/ws/a.dart');
      expect(json['tool_response'], 'total 0');
      expect(json['tool_ok'], true);
      expect(json['session_id'], 'ws-1');
      expect(json['cwd'], '/ws');
    });

    test('args 不可解析时按原文字符串；可选字段缺省不输出', () {
      final json = jsonDecode(buildAgentHookStdinJson(
        eventName: 'preToolUse',
        toolName: 'write',
        argsJson: 'not json',
      )) as Map<String, dynamic>;
      expect(json['tool_input'], 'not json');
      expect(json.containsKey('tool_response'), isFalse);
      expect(json.containsKey('tool_ok'), isFalse);
      expect(json.containsKey('file_path'), isFalse);
      expect(json.containsKey('session_id'), isFalse);
      expect(json.containsKey('cwd'), isFalse);
    });
  });

  group('userPromptSubmit / additionalContext', () {
    test('userPromptSubmit 事件解析', () {
      final config = decodeAgentHooksConfig(
        '{"userPromptSubmit":[{"type":"command","command":"check_prompt.sh"}]}',
      );
      final hooks = config!.ofEvent(AgentHookEvent.userPromptSubmit);
      expect(hooks, hasLength(1));
      expect(hooks.single.command, 'check_prompt.sh');
    });

    test('stdin JSON：prompt 事件带 prompt 字段，不带 tool_name/tool_input', () {
      final raw = buildAgentHookStdinJson(
        eventName: 'userPromptSubmit',
        toolName: '',
        argsJson: '{}',
        prompt: '帮我删库',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      expect(json['hook_event_name'], 'userPromptSubmit');
      expect(json['prompt'], '帮我删库');
      expect(json.containsKey('tool_name'), isFalse);
      expect(json.containsKey('tool_input'), isFalse);
    });

    test('exit 0 + additionalContext（无 decision）→ proceed 带注入', () {
      final r = interpretAgentHookExit(
        0,
        '{"additionalContext":"当前分支是 main"}',
        '',
      );
      expect(r.outcome, AgentHookOutcome.proceed);
      expect(r.additionalContext, '当前分支是 main');
    });

    test('decision + additionalContext 同时输出均保留', () {
      final r = interpretAgentHookExit(
        0,
        '{"decision":"allow","additionalContext":"lint 已通过"}',
        '',
      );
      expect(r.outcome, AgentHookOutcome.allow);
      expect(r.additionalContext, 'lint 已通过');
    });
  });

  group('continue:false / stopReason', () {
    test('exit 0 + {"continue":false,"stopReason":...} → 终止信号', () {
      final r = interpretAgentHookExit(
        0,
        '{"continue":false,"stopReason":"预算已超"}',
        '',
      );
      expect(r.outcome, AgentHookOutcome.proceed);
      expect(r.preventContinuation, isTrue);
      expect(r.stopReason, '预算已超');
    });

    test('continue:false 可与 decision 同时出现', () {
      final r = interpretAgentHookExit(
        0,
        '{"decision":"block","reason":"违规","continue":false,'
        '"stopReason":"终止任务"}',
        '',
      );
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, '违规');
      expect(r.preventContinuation, isTrue);
      expect(r.stopReason, '终止任务');
    });

    test('continue:true / 缺省不产生终止信号', () {
      expect(
        interpretAgentHookExit(0, '{"continue":true}', '').preventContinuation,
        isFalse,
      );
      expect(
        interpretAgentHookExit(0, '{"decision":"ask"}', '')
            .preventContinuation,
        isFalse,
      );
    });

    test('continue:false 无 stopReason 时 stopReason 为空', () {
      final r = interpretAgentHookExit(0, '{"continue":false}', '');
      expect(r.preventContinuation, isTrue);
      expect(r.stopReason, '');
    });
  });

  group('async hooks（{"async":true} 首行协议）', () {
    test('首行 {"async":true} → isAsync，按放行处理，余下输出忽略', () {
      final r = interpretAgentHookExit(
        0,
        '{"async":true}\n{"decision":"block","reason":"忽略我"}',
        '',
      );
      expect(r.isAsync, isTrue);
      expect(r.outcome, AgentHookOutcome.proceed);
      expect(r.message, '');
    });

    test('async hook 的非 0 退出码也忽略', () {
      final r = interpretAgentHookExit(2, '{"async":true,"asyncTimeout":5}', '');
      expect(r.isAsync, isTrue);
      expect(r.outcome, AgentHookOutcome.proceed);
    });

    test('非首行 / async!=true 不触发', () {
      expect(
        interpretAgentHookExit(0, 'log line\n{"async":true}', '').isAsync,
        isFalse,
      );
      expect(
        interpretAgentHookExit(0, '{"async":false}', '').isAsync,
        isFalse,
      );
      expect(
        interpretAgentHookExit(0, '{"decision":"block"}', '').isAsync,
        isFalse,
      );
    });
  });

  group('formatAgentHookStatusLine', () {
    test('放行文案含条数与耗时', () {
      final line = formatAgentHookStatusLine(
        label: 'preToolUse(write)',
        aggregate: const AgentHookResult(outcome: AgentHookOutcome.proceed),
        count: 2,
        failedCount: 0,
        asyncCount: 0,
        elapsed: const Duration(milliseconds: 840),
      );
      expect(line, '[hook] preToolUse(write) ✓ 放行 · 2 条 · 0.8s');
    });

    test('阻断带原因；async/失败/终止标注', () {
      final line = formatAgentHookStatusLine(
        label: 'stop',
        aggregate: const AgentHookResult(
          outcome: AgentHookOutcome.block,
          message: '还有 TODO',
          preventContinuation: true,
        ),
        count: 3,
        failedCount: 1,
        asyncCount: 1,
        elapsed: const Duration(seconds: 2),
      );
      expect(line, contains('✗ 阻断：还有 TODO'));
      expect(line, contains('⏹ 要求终止任务'));
      expect(line, contains('1 条转后台'));
      expect(line, contains('1 条失败（不阻断）'));
      expect(line, contains('· 3 条 · 2.0s'));
    });
  });

  group('aggregateAgentHookResults', () {
    test('任一 block 即 block，原因拼接', () {
      final r = aggregateAgentHookResults(const [
        AgentHookResult(outcome: AgentHookOutcome.allow, message: '白名单'),
        AgentHookResult(outcome: AgentHookOutcome.block, message: '违规 A'),
        AgentHookResult(outcome: AgentHookOutcome.block, message: '违规 B'),
      ]);
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, '违规 A\n违规 B');
    });

    test('优先级 block > ask > allow > proceed', () {
      expect(
        aggregateAgentHookResults(const [
          AgentHookResult(outcome: AgentHookOutcome.allow),
          AgentHookResult(outcome: AgentHookOutcome.ask),
        ]).outcome,
        AgentHookOutcome.ask,
      );
      expect(
        aggregateAgentHookResults(const [
          AgentHookResult(outcome: AgentHookOutcome.proceed),
          AgentHookResult(outcome: AgentHookOutcome.allow),
        ]).outcome,
        AgentHookOutcome.allow,
      );
      expect(
        aggregateAgentHookResults(const [
          AgentHookResult(outcome: AgentHookOutcome.failed, message: 'boom'),
        ]).outcome,
        AgentHookOutcome.proceed,
      );
    });

    test('additionalContext 非空项拼接', () {
      final r = aggregateAgentHookResults(const [
        AgentHookResult(
            outcome: AgentHookOutcome.proceed, additionalContext: '上下文1'),
        AgentHookResult(outcome: AgentHookOutcome.proceed),
        AgentHookResult(
            outcome: AgentHookOutcome.block,
            message: 'x',
            additionalContext: '上下文2'),
      ]);
      expect(r.additionalContext, '上下文1\n上下文2');
    });

    test('preventContinuation 任一为 true 即 true，stopReason 取首个非空', () {
      final r = aggregateAgentHookResults(const [
        AgentHookResult(
            outcome: AgentHookOutcome.proceed, preventContinuation: true),
        AgentHookResult(
            outcome: AgentHookOutcome.proceed,
            preventContinuation: true,
            stopReason: '第一个原因'),
        AgentHookResult(
            outcome: AgentHookOutcome.proceed,
            preventContinuation: true,
            stopReason: '第二个原因'),
      ]);
      expect(r.preventContinuation, isTrue);
      expect(r.stopReason, '第一个原因');
      expect(
        aggregateAgentHookResults(const [
          AgentHookResult(outcome: AgentHookOutcome.proceed),
        ]).preventContinuation,
        isFalse,
      );
    });

    test('空列表 → proceed', () {
      final r = aggregateAgentHookResults(const []);
      expect(r.outcome, AgentHookOutcome.proceed);
      expect(r.preventContinuation, isFalse);
    });
  });

  group('splitAgentHookOutput', () {
    test('标记行前后拆为 stdout / stderr', () {
      final r = splitAgentHookOutput(
        'hook stdout\n$kAgentHookStderrMarker\n违规：禁止 push\n',
      );
      expect(r.stdout, 'hook stdout');
      expect(r.stderr, '违规：禁止 push');
    });

    test('无标记时全部视为 stdout', () {
      final r = splitAgentHookOutput('plain output');
      expect(r.stdout, 'plain output');
      expect(r.stderr, '');
    });

    test('stderr 为空时返回空串', () {
      final r = splitAgentHookOutput('out\n$kAgentHookStderrMarker\n');
      expect(r.stdout, 'out');
      expect(r.stderr, '');
    });
  });

  group('buildAgentPromptHookText / interpretAgentPromptHookResponse', () {
    test(r'$ARGUMENTS 替换；无占位符时追加到末尾', () {
      expect(
        buildAgentPromptHookText(r'检查：$ARGUMENTS 完', '{"a":1}'),
        '检查：{"a":1} 完',
      );
      expect(
        buildAgentPromptHookText('检查输入', '{"a":1}'),
        '检查输入\n\n{"a":1}',
      );
    });

    test('{"ok":true} → proceed', () {
      final r = interpretAgentPromptHookResponse('{"ok":true}');
      expect(r.outcome, AgentHookOutcome.proceed);
    });

    test('{"ok":false,"reason":...} → block 带原因', () {
      final r = interpretAgentPromptHookResponse(
        '{"ok":false,"reason":"命令不安全"}',
      );
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, '命令不安全');
    });

    test('容忍 围栏 包裹的 JSON', () {
      final r = interpretAgentPromptHookResponse(
        '```json\n{"ok":false,"reason":"违规"}\n```',
      );
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, '违规');
    });

    test('非 JSON / 不符合协议 → failed（不阻断）', () {
      expect(
        interpretAgentPromptHookResponse('我觉得可以').outcome,
        AgentHookOutcome.failed,
      );
      expect(
        interpretAgentPromptHookResponse('{"verdict":"yes"}').outcome,
        AgentHookOutcome.failed,
      );
      expect(
        interpretAgentPromptHookResponse('{"ok":"yes"}').outcome,
        AgentHookOutcome.failed,
      );
    });
  });

  group('interpretAgentHttpHookResponse', () {
    test('2xx + decision JSON → 同 stdout 协议', () {
      final r = interpretAgentHttpHookResponse(
        200,
        '{"decision":"deny","reason":"禁止"}',
      );
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, '禁止');
      expect(
        interpretAgentHttpHookResponse(201, '{"decision":"allow"}').outcome,
        AgentHookOutcome.allow,
      );
    });

    test('2xx + continue:false / additionalContext 保留', () {
      final r = interpretAgentHttpHookResponse(
        200,
        '{"continue":false,"stopReason":"预算超",'
        '"additionalContext":"上下文"}',
      );
      expect(r.preventContinuation, isTrue);
      expect(r.stopReason, '预算超');
      expect(r.additionalContext, '上下文');
    });

    test('2xx 首行 {"async":true} → isAsync', () {
      expect(
        interpretAgentHttpHookResponse(200, '{"async":true}').isAsync,
        isTrue,
      );
    });

    test('2xx 空体 / 非 JSON → proceed', () {
      expect(
        interpretAgentHttpHookResponse(200, '').outcome,
        AgentHookOutcome.proceed,
      );
      expect(
        interpretAgentHttpHookResponse(204, 'ok').outcome,
        AgentHookOutcome.proceed,
      );
    });

    test('非 2xx → failed（不阻断）', () {
      final r = interpretAgentHttpHookResponse(500, 'boom');
      expect(r.outcome, AgentHookOutcome.failed);
      expect(r.message, contains('HTTP 500'));
      expect(
        interpretAgentHttpHookResponse(404, '').outcome,
        AgentHookOutcome.failed,
      );
    });
  });

  group('interpretAgentHookExit', () {
    test('exit 0 无输出 → proceed', () {
      final r = interpretAgentHookExit(0, '', '');
      expect(r.outcome, AgentHookOutcome.proceed);
    });

    test('exit 2 → block，stderr 优先作为原因', () {
      final r = interpretAgentHookExit(2, 'out', 'lint failed');
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, 'lint failed');
      expect(interpretAgentHookExit(2, 'only stdout', '').message,
          'only stdout');
    });

    test('exit 0 + stdout JSON decision → block', () {
      final r = interpretAgentHookExit(
        0,
        '{"decision":"deny","reason":"危险命令"}',
        '',
      );
      expect(r.outcome, AgentHookOutcome.block);
      expect(r.message, '危险命令');
      expect(
        interpretAgentHookExit(0, '{"decision":"block"}', '').outcome,
        AgentHookOutcome.block,
      );
    });

    test('exit 0 + stdout JSON decision allow/approve → allow（免审）', () {
      final r = interpretAgentHookExit(
        0,
        '{"decision":"allow","reason":"白名单命令"}',
        '',
      );
      expect(r.outcome, AgentHookOutcome.allow);
      expect(r.message, '白名单命令');
      expect(
        interpretAgentHookExit(0, '{"decision":"approve"}', '').outcome,
        AgentHookOutcome.allow,
      );
    });

    test('exit 0 + stdout JSON decision ask → ask（强制审批）', () {
      final r = interpretAgentHookExit(0, '{"decision":"ask"}', '');
      expect(r.outcome, AgentHookOutcome.ask);
    });

    test('exit 0 + 非 decision JSON / 普通输出 → proceed', () {
      expect(interpretAgentHookExit(0, '{"foo":1}', '').outcome,
          AgentHookOutcome.proceed);
      expect(interpretAgentHookExit(0, 'all good', '').outcome,
          AgentHookOutcome.proceed);
    });

    test('其他 exit code → failed（不阻断）', () {
      final r = interpretAgentHookExit(1, '', 'boom');
      expect(r.outcome, AgentHookOutcome.failed);
      expect(r.message, 'boom');
      expect(interpretAgentHookExit(127, '', '').message, 'exit 127');
    });
  });
}
