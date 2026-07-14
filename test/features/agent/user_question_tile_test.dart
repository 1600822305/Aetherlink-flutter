import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/user_question_tile.dart';

class _TestAgentTasks extends AgentTasks {
  _TestAgentTasks(this.task);

  final AgentTask task;

  @override
  List<AgentTask> build() => [task];
}

void main() {
  testWidgets('waitingInput 时显示结构化提问卡和全部选项', (tester) async {
    final at = DateTime(2026, 7, 14);
    final task = AgentTask(
      id: 'task-1',
      profileId: 'agent-1',
      title: '测试任务',
      workspaceId: 'workspace-1',
      workspaceName: '测试工作区',
      status: AgentTaskStatus.waitingInput,
      mode: AgentSessionMode.code,
      createdAt: at,
      updatedAt: at,
    );
    final question = UserQuestionEvent(
      id: 'question-1',
      seq: 1,
      at: at,
      toolCallId: 'call-1',
      questions: const [
        AgentUserQuestion(question: '选择发布环境', options: ['测试', '生产']),
        AgentUserQuestion(
          question: '选择检查项',
          options: ['日志', '指标'],
          allowMultiple: true,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentTasksProvider.overrideWith(() => _TestAgentTasks(task)),
          agentTaskEventsProvider(
            task.id,
          ).overrideWith((ref) => Stream.value([question])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: UserQuestionTile(event: question, taskId: task.id),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('需要你的回答'), findsOneWidget);
    expect(find.text('1. 选择发布环境'), findsOneWidget);
    expect(find.text('2. 选择检查项'), findsOneWidget);
    expect(find.text('测试'), findsOneWidget);
    expect(find.text('生产'), findsOneWidget);
    expect(find.text('日志'), findsOneWidget);
    expect(find.text('指标'), findsOneWidget);
    expect(find.text('可多选'), findsOneWidget);
    expect(find.text('提交回答'), findsOneWidget);
  });

  testWidgets('单问题时展示建议答案按钮和自定义输入框，无提交按钮', (tester) async {
    final at = DateTime(2026, 7, 14);
    final task = AgentTask(
      id: 'task-1',
      profileId: 'agent-1',
      title: '测试任务',
      workspaceId: 'workspace-1',
      workspaceName: '测试工作区',
      status: AgentTaskStatus.waitingInput,
      mode: AgentSessionMode.code,
      createdAt: at,
      updatedAt: at,
    );
    final question = UserQuestionEvent(
      id: 'question-1',
      seq: 1,
      at: at,
      toolCallId: 'call-1',
      questions: const [
        AgentUserQuestion(
          question: '配置文件路径是？',
          options: ['./config.json', './src/config.json'],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentTasksProvider.overrideWith(() => _TestAgentTasks(task)),
          agentTaskEventsProvider(
            task.id,
          ).overrideWith((ref) => Stream.value([question])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: UserQuestionTile(event: question, taskId: task.id),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('配置文件路径是？'), findsOneWidget);
    expect(find.text('./config.json'), findsOneWidget);
    expect(find.text('./src/config.json'), findsOneWidget);
    expect(find.text('自定义回答…'), findsOneWidget);
    expect(find.text('提交回答'), findsNothing);
  });
}
