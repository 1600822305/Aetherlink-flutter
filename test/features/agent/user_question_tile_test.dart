import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_event.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/event_stream/tiles/user_question_tile.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_followup_panel.dart';

class _TestAgentTasks extends AgentTasks {
  _TestAgentTasks(this.task);

  final AgentTask task;

  @override
  List<AgentTask> build() => [task];
}

AgentTask _task(DateTime at) => AgentTask(
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

UserQuestionEvent _question(DateTime at) => UserQuestionEvent(
      id: 'question-1',
      seq: 1,
      at: at,
      toolCallId: 'call-1',
      question: '选择发布环境',
      suggestions: const ['测试', '生产'],
    );

Widget _scope(AgentTask task, List<AgentEvent> events, Widget child) =>
    ProviderScope(
      key: ValueKey('scope-${events.length}'),
      overrides: [
        agentTasksProvider.overrideWith(() => _TestAgentTasks(task)),
        agentTaskEventsProvider(
          task.id,
        ).overrideWith((ref) => Stream.value(events)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('提问记录 tile：未回答时显示等待状态，已回答时显示回答', (tester) async {
    final at = DateTime(2026, 7, 14);
    final task = _task(at);
    final question = _question(at);

    await tester.pumpWidget(_scope(
      task,
      [question],
      UserQuestionTile(event: question, taskId: task.id),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('选择发布环境'), findsOneWidget);
    expect(find.text('等待回答（在下方面板中选择或输入）'), findsOneWidget);

    final answer = UserMessageEvent(
      id: 'answer-1',
      seq: 2,
      at: at,
      text: '测试',
      replyToQuestionId: question.id,
    );
    await tester.pumpWidget(_scope(
      task,
      [question, answer],
      UserQuestionTile(event: question, taskId: task.id),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('回答：测试'), findsOneWidget);
    expect(find.text('等待回答（在下方面板中选择或输入）'), findsNothing);
  });

  testWidgets('建议答案面板：待答时展示问题和整行建议按钮，已答后不占位', (tester) async {
    final at = DateTime(2026, 7, 14);
    final task = _task(at);
    final question = _question(at);

    await tester.pumpWidget(_scope(
      task,
      [question],
      AgentFollowupPanel(task: task),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('选择发布环境'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '测试'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '生产'), findsOneWidget);

    final answer = UserMessageEvent(
      id: 'answer-1',
      seq: 2,
      at: at,
      text: '测试',
      replyToQuestionId: question.id,
    );
    await tester.pumpWidget(_scope(
      task,
      [question, answer],
      AgentFollowupPanel(task: task),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('选择发布环境'), findsNothing);
  });
}
