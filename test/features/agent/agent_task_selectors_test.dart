import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/widgets/agent_status.dart';

class _TestAgentTasks extends AgentTasks {
  _TestAgentTasks(this.initial);

  final List<AgentTask> initial;

  @override
  List<AgentTask> build() => initial;

  void replace(AgentTask task) => state = [
    for (final t in state)
      if (t.id == task.id) task else t,
  ];
}

class _TestUiSettings extends AgentUiSettingsController {
  @override
  AgentUiSettings build() => const AgentUiSettings();
}

AgentTask _task(String id) => AgentTask(
  id: id,
  profileId: 'agent-1',
  title: '任务 $id',
  workspaceId: 'workspace-1',
  workspaceName: '测试工作区',
  status: AgentTaskStatus.running,
  mode: AgentSessionMode.code,
  createdAt: DateTime(2026, 7, 14),
  updatedAt: DateTime(2026, 7, 14),
);

void main() {
  test('agentTaskProvider：其它话题写回不通知，本话题替换才通知', () {
    final a = _task('a');
    final b = _task('b');
    final container = ProviderContainer(
      overrides: [
        agentTasksProvider.overrideWith(() => _TestAgentTasks([a, b])),
      ],
    );
    addTearDown(container.dispose);

    final seen = <AgentTask?>[];
    container.listen(agentTaskProvider('a'), (_, next) => seen.add(next));
    final notifier =
        container.read(agentTasksProvider.notifier) as _TestAgentTasks;

    notifier.replace(b.copyWith(rounds: 3, contextTokens: 1000));
    expect(seen, isEmpty);

    final updated = a.copyWith(rounds: 1);
    notifier.replace(updated);
    expect(seen, [updated]);
    expect(container.read(agentTaskProvider('missing')), isNull);
  });

  testWidgets('AgentStatusLine 按 taskId 订阅，轮数刷新只重建状态条', (tester) async {
    final a = _task('a');
    final container = ProviderContainer(
      overrides: [
        agentTasksProvider.overrideWith(() => _TestAgentTasks([a])),
        agentUiSettingsControllerProvider.overrideWith(_TestUiSettings.new),
      ],
    );
    addTearDown(container.dispose);

    var parentBuilds = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                parentBuilds++;
                return const AgentStatusLine(taskId: 'a');
              },
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('第0轮'), findsOneWidget);

    (container.read(agentTasksProvider.notifier) as _TestAgentTasks).replace(
      a.copyWith(rounds: 12, contextTokens: 8400),
    );
    await tester.pump();

    expect(find.textContaining('第12轮'), findsOneWidget);
    expect(find.textContaining('上下文8.4k'), findsOneWidget);
    expect(parentBuilds, 1);
  });
}
