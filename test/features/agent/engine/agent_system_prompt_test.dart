import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/engine/agent_engine.dart';
import 'package:aetherlink_flutter/features/agent/application/engine/agent_system_prompt.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  AgentTask task(AgentSessionMode mode) => AgentTask(
        id: 't1',
        profileId: 'p1',
        title: '测试',
        workspaceId: 'w1',
        workspaceName: '工作区',
        status: AgentTaskStatus.running,
        mode: mode,
        createdAt: now,
        updatedAt: now,
      );

  const profile = AgentProfile(
    id: 'p1',
    name: '通用',
    emoji: '🤖',
    systemPrompt: '',
    tools: {},
  );

  ToolCallEvent exitPlanEvent(AgentToolCallState state, {String? plan}) =>
      ToolCallEvent(
        id: 'e1',
        seq: 1,
        at: now,
        toolName: kToolExitPlanMode,
        argSummary: '请求批准方案',
        state: state,
        argsDetail: plan == null ? null : jsonEncode({'plan': plan}),
      );

  test('已批准方案置尾注入系统提示（非 Plan 模式）', () {
    final prompt = buildAgentSystemPrompt(
      task: task(AgentSessionMode.code),
      profile: profile,
      events: [exitPlanEvent(AgentToolCallState.success, plan: '## 最终方案')],
    );
    expect(prompt, contains('[已批准的实施方案]'));
    expect(prompt, contains('## 最终方案'));
  });

  test('Plan 模式不注入已批准方案（方案尚在修订中）', () {
    final prompt = buildAgentSystemPrompt(
      task: task(AgentSessionMode.plan),
      profile: profile,
      events: [exitPlanEvent(AgentToolCallState.success, plan: '## 最终方案')],
    );
    expect(prompt, isNot(contains('[已批准的实施方案]')));
  });

  test('未批准（denied/waiting）方案不注入', () {
    final prompt = buildAgentSystemPrompt(
      task: task(AgentSessionMode.code),
      profile: profile,
      events: [exitPlanEvent(AgentToolCallState.denied, plan: '## 被拒方案')],
    );
    expect(prompt, isNot(contains('## 被拒方案')));
  });

  test('多次批准取最近一次的方案', () {
    final prompt = buildAgentSystemPrompt(
      task: task(AgentSessionMode.code),
      profile: profile,
      events: [
        exitPlanEvent(AgentToolCallState.success, plan: '## 方案 v1'),
        ToolCallEvent(
          id: 'e2',
          seq: 2,
          at: now,
          toolName: kToolExitPlanMode,
          argSummary: '请求批准方案',
          state: AgentToolCallState.success,
          argsDetail: jsonEncode({'plan': '## 方案 v2'}),
        ),
      ],
    );
    expect(prompt, contains('## 方案 v2'));
    expect(prompt, isNot(contains('## 方案 v1')));
  });

  test('参数缺失或非法 JSON 时安全跳过', () {
    final prompt = buildAgentSystemPrompt(
      task: task(AgentSessionMode.code),
      profile: profile,
      events: [
        ToolCallEvent(
          id: 'e1',
          seq: 1,
          at: now,
          toolName: kToolExitPlanMode,
          argSummary: '请求批准方案',
          state: AgentToolCallState.success,
          argsDetail: '不是 JSON',
        ),
      ],
    );
    expect(prompt, isNot(contains('[已批准的实施方案]')));
  });
}
