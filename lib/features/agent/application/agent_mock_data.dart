/// UI 先行阶段的假数据（已拍板：先用 mock 事件流把全部界面跑通，
/// 再接真引擎/drift 持久化替换本文件的数据源）。
library;

import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';

/// 内置预设档案（UI 稿 §三：编程/网络研究/PPT 文档，不可删可复制）。
const List<AgentProfile> kBuiltinAgentProfiles = [
  AgentProfile(
    id: 'agent-coding',
    name: '编程',
    emoji: '💻',
    systemPrompt: '你是一名资深软件工程师……',
    tools: {
      AgentToolGroup.fileEditor,
      AgentToolGroup.terminal,
      AgentToolGroup.skills,
    },
    workspaceId: 'ws-1',
    workspaceName: 'aetherlink-app',
    builtin: true,
  ),
  AgentProfile(
    id: 'agent-research',
    name: '网络研究',
    emoji: '🔍',
    systemPrompt: '你是一名调研分析师……',
    tools: {
      AgentToolGroup.webSearch,
      AgentToolGroup.knowledgeBase,
      AgentToolGroup.fileEditor,
    },
    workspaceId: 'ws-2',
    workspaceName: 'research-notes',
    builtin: true,
  ),
  AgentProfile(
    id: 'agent-docs',
    name: 'PPT 文档',
    emoji: '📊',
    systemPrompt: '你是一名文档/演示专家……',
    tools: {AgentToolGroup.fileEditor, AgentToolGroup.skills},
    builtin: true,
  ),
];

final List<AgentTask> kMockAgentTasks = [
  AgentTask(
    id: 'task-1',
    profileId: 'agent-coding',
    title: '修复登录页崩溃',
    workspaceId: 'ws-1',
    workspaceName: 'aetherlink-app',
    status: AgentTaskStatus.waitingApproval,
    mode: AgentSessionMode.code,
    createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
    updatedAt: DateTime.now(),
    modelLabel: 'GLM-4.6',
    rounds: 12,
    tokenCount: 8400,
    elapsed: const Duration(minutes: 6),
    lastEventSummary: '等待授权 write login.dart',
  ),
  AgentTask(
    id: 'task-2',
    profileId: 'agent-coding',
    title: '升级依赖并过 CI',
    workspaceId: 'ws-1',
    workspaceName: 'aetherlink-app',
    status: AgentTaskStatus.done,
    mode: AgentSessionMode.code,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 20)),
    modelLabel: 'GLM-4.6',
    rounds: 23,
    tokenCount: 31000,
    elapsed: const Duration(minutes: 18),
    lastEventSummary: '任务完成：依赖升级并通过全部测试',
  ),
  AgentTask(
    id: 'task-3',
    profileId: 'agent-research',
    title: '调研 Flutter 状态管理趋势',
    workspaceId: 'ws-2',
    workspaceName: 'research-notes',
    status: AgentTaskStatus.paused,
    mode: AgentSessionMode.ask,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    modelLabel: 'GLM-4.6',
    rounds: 7,
    tokenCount: 5200,
    elapsed: const Duration(minutes: 4),
    lastEventSummary: '已暂停：用户手动暂停',
  ),
];

List<AgentEvent> mockEventsForTask(String taskId) {
  final base = DateTime.now().subtract(const Duration(minutes: 8));
  DateTime t(int m) => base.add(Duration(minutes: m));
  var seq = 0;
  int next() => seq++;
  if (taskId != 'task-1') {
    return [
      UserMessageEvent(
        id: '$taskId-e0',
        seq: next(),
        at: t(0),
        text: '（示例话题）任务指令内容…',
      ),
      AssistantTextEvent(
        id: '$taskId-e1',
        seq: next(),
        at: t(1),
        text: '好的，我来处理这个任务。',
      ),
    ];
  }
  return [
    UserMessageEvent(
      id: 'e-user-1',
      seq: next(),
      at: t(0),
      text: '登录页在输入空密码时崩溃，帮我修复并补上测试。',
    ),
    PlanUpdateEvent(
      id: 'e-plan-1',
      seq: next(),
      at: t(0),
      items: const [
        AgentPlanItem(
          content: '复现崩溃并定位根因',
          status: AgentPlanItemStatus.completed,
        ),
        AgentPlanItem(
          content: '阅读 login.dart 与相关校验逻辑',
          status: AgentPlanItemStatus.completed,
        ),
        AgentPlanItem(
          content: '修复空密码分支',
          status: AgentPlanItemStatus.inProgress,
        ),
        AgentPlanItem(content: '补充单元测试', status: AgentPlanItemStatus.pending),
        AgentPlanItem(content: '运行全部测试验证', status: AgentPlanItemStatus.pending),
      ],
    ),
    AssistantTextEvent(
      id: 'e-a-1',
      seq: next(),
      at: t(1),
      text: '我先看一下崩溃日志和登录页的实现，定位空密码分支的问题。',
    ),
    ToolCallEvent(
      id: 'e-t-1',
      seq: next(),
      at: t(1),
      toolName: 'read_file',
      argSummary: 'lib/login.dart',
      state: AgentToolCallState.success,
      resultSummary: '234 行 · 0.4s',
      elapsed: const Duration(milliseconds: 400),
      argsDetail: '{"path": "lib/login.dart"}',
      resultDetail:
          'class LoginPage extends StatefulWidget {\n'
          '  const LoginPage({super.key});\n  ...\n（共 234 行，截断展示）',
    ),
    ToolCallEvent(
      id: 'e-t-2',
      seq: next(),
      at: t(2),
      toolName: 'search_files',
      argSummary: 'validatePassword',
      state: AgentToolCallState.success,
      resultSummary: '3 处匹配 · 0.2s',
    ),
    ToolCallEvent(
      id: 'e-t-3',
      seq: next(),
      at: t(3),
      toolName: 'terminal_execute',
      argSummary: r'$ flutter test test/login_test.dart',
      state: AgentToolCallState.failure,
      resultSummary: '失败 ✗ · 2 用例崩溃',
      argsDetail: r'$ flutter test test/login_test.dart',
      resultDetail:
          '00:21 +3 -2: login validates empty password [E]\n'
          '  Null check operator used on a null value\n'
          '  package:aetherlink/login.dart 87:21  _validate\n'
          '（完整输出接真引擎后落盘，这里为截断内容）',
      elapsed: const Duration(seconds: 21),
    ),
    AssistantTextEvent(
      id: 'e-a-2',
      seq: next(),
      at: t(4),
      text:
          '定位到了：`validatePassword` 对 null/空串直接解引用导致崩溃。'
          '我准备修改 login.dart 增加空值守卫，然后补测试。',
    ),
    CompactionEvent(
      id: 'e-c-1',
      seq: next(),
      at: t(5),
      coveredCount: 41,
      summary: '早期探索阶段：浏览了项目结构、定位到登录模块……',
    ),
    ToolCallEvent(
      id: 'e-t-4',
      seq: next(),
      at: t(6),
      toolName: 'write',
      argSummary: 'lib/login.dart',
      state: AgentToolCallState.waitingApproval,
    ),
  ];
}
