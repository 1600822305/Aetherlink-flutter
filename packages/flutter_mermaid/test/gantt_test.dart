import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';

void main() {
  group('GanttChartData', () {
    test('calculates date range correctly', () {
      final tasks = [
        GanttTask(
          id: 'task1',
          name: 'Task 1',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 10),
        ),
        GanttTask(
          id: 'task2',
          name: 'Task 2',
          startDate: DateTime(2024, 1, 5),
          endDate: DateTime(2024, 1, 20),
        ),
      ];

      final data = GanttChartData(tasks: tasks);

      expect(data.minDate, DateTime(2024, 1, 1));
      expect(data.maxDate, DateTime(2024, 1, 20));
      expect(data.totalDays, 20);
    });

    test('calculates task duration correctly', () {
      final task = GanttTask(
        id: 'task1',
        name: 'Task 1',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 10),
      );

      expect(task.durationDays, 10);
    });

    test('getTask returns correct task', () {
      final tasks = [
        GanttTask(
          id: 'task1',
          name: 'Task 1',
          startDate: DateTime(2024, 1, 1),
          endDate: DateTime(2024, 1, 10),
        ),
        GanttTask(
          id: 'task2',
          name: 'Task 2',
          startDate: DateTime(2024, 1, 5),
          endDate: DateTime(2024, 1, 20),
        ),
      ];

      final data = GanttChartData(tasks: tasks);

      expect(data.getTask('task1')?.name, 'Task 1');
      expect(data.getTask('task2')?.name, 'Task 2');
      expect(data.getTask('task3'), isNull);
    });
  });

  group('GanttParser', () {
    const parser = GanttParser();

    test('parses basic gantt chart', () {
      final lines = [
        'gantt',
        '    title Project Timeline',
        '    dateFormat YYYY-MM-DD',
        '    Task A :a1, 2024-01-01, 30d',
        '    Task B :a2, 2024-01-15, 15d',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$1.type, DiagramType.ganttChart);
      expect(result.$2.title, 'Project Timeline');
      expect(result.$2.tasks.length, 2);
      expect(result.$2.tasks[0].name, 'Task A');
      expect(result.$2.tasks[0].id, 'a1');
      expect(result.$2.tasks[1].name, 'Task B');
    });

    test('parses gantt chart with sections', () {
      final lines = [
        'gantt',
        '    title Development Plan',
        '    section Design',
        '        UI Design :d1, 2024-01-01, 10d',
        '        API Design :d2, 2024-01-05, 7d',
        '    section Development',
        '        Frontend :dev1, 2024-01-15, 20d',
        '        Backend :dev2, 2024-01-10, 25d',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.sections.length, 2);
      expect(result.$2.sections[0].name, 'Design');
      expect(result.$2.sections[0].tasks.length, 2);
      expect(result.$2.sections[1].name, 'Development');
      expect(result.$2.sections[1].tasks.length, 2);
    });

    test('parses task status', () {
      final lines = [
        'gantt',
        '    Done Task :done, t1, 2024-01-01, 5d',
        '    Active Task :active, t2, 2024-01-06, 5d',
        '    Critical Task :crit, t3, 2024-01-11, 5d',
        '    Milestone :milestone, m1, 2024-01-16, 0d',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.tasks[0].status, GanttTaskStatus.done);
      expect(result.$2.tasks[1].status, GanttTaskStatus.active);
      expect(result.$2.tasks[2].status, GanttTaskStatus.critical);
      expect(result.$2.tasks[3].status, GanttTaskStatus.milestone);
    });

    test('parses task dependencies', () {
      final lines = [
        'gantt',
        '    Task A :a1, 2024-01-01, 10d',
        '    Task B :a2, after a1, 5d',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.tasks[1].dependencies, contains('a1'));
    });

    test('parses end date instead of duration', () {
      final lines = [
        'gantt',
        '    Task A :a1, 2024-01-01, 2024-01-15',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.tasks[0].startDate, DateTime(2024, 1, 1));
      expect(result.$2.tasks[0].endDate, DateTime(2024, 1, 15));
    });

    test('returns null for empty input', () {
      final result = parser.parse([]);
      expect(result, isNull);
    });

    test('returns null for input with no tasks', () {
      final lines = [
        'gantt',
        '    title Empty Chart',
      ];

      final result = parser.parse(lines);
      expect(result, isNull);
    });
  });

  group('MermaidParser integration', () {
    const parser = MermaidParser();

    test('detects gantt chart type', () {
      const source = '''
gantt
    title A Gantt Diagram
    Task 1 :a1, 2024-01-01, 30d
''';

      final result = parser.parseWithData(source);

      expect(result, isNotNull);
      expect(result!.diagram.type, DiagramType.ganttChart);
      expect(result.ganttChartData, isNotNull);
      expect(result.ganttChartData!.tasks.length, 1);
    });

    test('parses full gantt chart example', () {
      const source = '''
gantt
    title Software Development Timeline
    dateFormat YYYY-MM-DD

    section Planning
        Requirements Analysis :done, req, 2024-01-01, 14d
        Design Document :done, design, after req, 10d

    section Development
        Frontend Development :active, front, 2024-01-25, 30d
        Backend Development :active, back, 2024-01-20, 35d
        API Integration :crit, api, after back, 10d

    section Testing
        Unit Testing :test1, 2024-02-25, 10d
        Integration Testing :test2, after test1, 7d
        Release :milestone, rel, after test2, 0d
''';

      final result = parser.parseWithData(source);

      expect(result, isNotNull);
      expect(result!.diagram.title, 'Software Development Timeline');
      expect(result.ganttChartData, isNotNull);

      final gantt = result.ganttChartData!;
      expect(gantt.sections.length, 3);
      expect(gantt.tasks.length, 8);

      // Check sections
      expect(gantt.sections[0].name, 'Planning');
      expect(gantt.sections[1].name, 'Development');
      expect(gantt.sections[2].name, 'Testing');

      // Check task statuses
      final reqTask = gantt.getTask('req');
      expect(reqTask?.status, GanttTaskStatus.done);

      final frontTask = gantt.getTask('front');
      expect(frontTask?.status, GanttTaskStatus.active);

      final apiTask = gantt.getTask('api');
      expect(apiTask?.status, GanttTaskStatus.critical);

      final relTask = gantt.getTask('rel');
      expect(relTask?.status, GanttTaskStatus.milestone);
    });
  });

  group('GanttChartColors', () {
    test('returns correct color for status', () {
      expect(
        GanttChartColors.getColorForStatus(GanttTaskStatus.done),
        GanttChartColors.doneColor,
      );
      expect(
        GanttChartColors.getColorForStatus(GanttTaskStatus.active),
        GanttChartColors.activeColor,
      );
      expect(
        GanttChartColors.getColorForStatus(GanttTaskStatus.critical),
        GanttChartColors.criticalColor,
      );
      expect(
        GanttChartColors.getColorForStatus(GanttTaskStatus.milestone),
        GanttChartColors.milestoneColor,
      );
      expect(
        GanttChartColors.getColorForStatus(GanttTaskStatus.normal),
        GanttChartColors.normalColor,
      );
    });
  });
}
