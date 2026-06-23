import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';

void main() {
  group('KanbanParser', () {
    const parser = KanbanParser();

    test('parses basic kanban with two columns', () {
      const input = '''
kanban
  todo[To Do]
    task1[Setup project]
  doing[In Progress]
    task2[Write code]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      expect(result!.$1.type, DiagramType.kanban);
      expect(result.$2.columns.length, 2);
      expect(result.$2.columns[0].title, 'To Do');
      expect(result.$2.columns[0].tasks.length, 1);
      expect(result.$2.columns[0].tasks[0].description, 'Setup project');
    });

    test('parses task with metadata', () {
      const input = '''
kanban
  todo[To Do]
    task1[Fix bug] @{ assigned: "Alice", ticket: "123", priority: "High" }
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      final task = result!.$2.columns[0].tasks[0];
      expect(task.assigned, 'Alice');
      expect(task.ticket, '123');
      expect(task.priority, KanbanPriority.high);
    });

    test('parses config with ticketBaseUrl', () {
      const input = '''
---
config:
  kanban:
    ticketBaseUrl: 'https://example.com/#TICKET#'
---
kanban
  todo[To Do]
    task1[Task]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      expect(result!.$2.ticketBaseUrl, 'https://example.com/#TICKET#');
    });

    test('parses WIP limit', () {
      const input = '''
kanban
  doing[In Progress] wip:3
    task1[Task 1]
    task2[Task 2]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      expect(result!.$2.columns[0].wipLimit, 3);
      expect(result.$2.columns[0].isOverLimit, false);
    });

    test('detects over WIP limit', () {
      const input = '''
kanban
  doing[In Progress] wip:2
    task1[Task 1]
    task2[Task 2]
    task3[Task 3]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      expect(result!.$2.columns[0].wipLimit, 2);
      expect(result.$2.columns[0].tasks.length, 3);
      expect(result.$2.columns[0].isOverLimit, true);
    });

    test('handles multiple tasks in column', () {
      const input = '''
kanban
  todo[To Do]
    task1[Task 1]
    task2[Task 2]
    task3[Task 3]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      expect(result!.$2.columns[0].tasks.length, 3);
    });

    test('parses title', () {
      const input = '''
kanban
  title My Kanban Board
  todo[To Do]
    task1[Task]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      expect(result!.$2.title, 'My Kanban Board');
      expect(result.$1.title, 'My Kanban Board');
    });

    test('returns null for empty input', () {
      final result = parser.parse([]);

      expect(result, isNull);
    });

    test('returns null for kanban without columns', () {
      const input = '''
kanban
  title My Board
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNull);
    });

    test('handles all priority levels', () {
      const priorities = {
        'Very High': KanbanPriority.veryHigh,
        'High': KanbanPriority.high,
        'Low': KanbanPriority.low,
        'Very Low': KanbanPriority.veryLow,
      };

      for (final entry in priorities.entries) {
        final input = '''
kanban
  todo[To Do]
    task1[Task] @{ priority: "${entry.key}" }
''';
        final result = parser.parse(input.split('\n'));

        expect(result, isNotNull);
        expect(
          result!.$2.columns[0].tasks[0].priority,
          entry.value,
          reason: 'Failed for priority: ${entry.key}',
        );
      }
    });

    test('handles multiple columns', () {
      const input = '''
kanban
  backlog[Backlog]
    task1[Task 1]
  todo[To Do]
    task2[Task 2]
  doing[In Progress]
    task3[Task 3]
  review[Review]
    task4[Task 4]
  done[Done]
    task5[Task 5]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      expect(result!.$2.columns.length, 5);
      expect(result.$2.columns[0].title, 'Backlog');
      expect(result.$2.columns[4].title, 'Done');
    });

    test('parses complete example with all features', () {
      const input = '''
---
config:
  kanban:
    ticketBaseUrl: 'https://jira.example.com/browse/#TICKET#'
---
kanban
  title Product Development

  backlog[Backlog] wip:10
    task1[User auth] @{ assigned: "Alice", ticket: "PROJ-101", priority: "High" }
    task2[Database design] @{ assigned: "Bob", ticket: "PROJ-102" }

  todo[To Do] wip:5
    task3[Login UI] @{ assigned: "Charlie", priority: "Very High" }

  doing[In Progress] wip:3
    task4[Dashboard] @{ assigned: "Bob", ticket: "PROJ-104", priority: "High" }

  done[Done]
    task5[CI/CD] @{ assigned: "Alice" }
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      expect(result!.$2.title, 'Product Development');
      expect(result.$2.ticketBaseUrl, 'https://jira.example.com/browse/#TICKET#');
      expect(result.$2.columns.length, 4);

      // Check backlog
      expect(result.$2.columns[0].title, 'Backlog');
      expect(result.$2.columns[0].wipLimit, 10);
      expect(result.$2.columns[0].tasks.length, 2);

      // Check first task
      final task1 = result.$2.columns[0].tasks[0];
      expect(task1.description, 'User auth');
      expect(task1.assigned, 'Alice');
      expect(task1.ticket, 'PROJ-101');
      expect(task1.priority, KanbanPriority.high);
    });

    test('getTask finds task by ID', () {
      const input = '''
kanban
  todo[To Do]
    task1[First task]
    task2[Second task]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      final task = result!.$2.getTask('task2');
      expect(task, isNotNull);
      expect(task!.description, 'Second task');

      final notFound = result.$2.getTask('task999');
      expect(notFound, isNull);
    });

    test('allTasks returns all tasks across columns', () {
      const input = '''
kanban
  todo[To Do]
    task1[Task 1]
    task2[Task 2]
  doing[Doing]
    task3[Task 3]
''';
      final result = parser.parse(input.split('\n'));

      expect(result, isNotNull);
      final allTasks = result!.$2.allTasks;
      expect(allTasks.length, 3);
      expect(allTasks.map((t) => t.id).toList(), ['task1', 'task2', 'task3']);
    });
  });

  group('KanbanChartColors', () {
    test('getColorForPriority returns correct colors', () {
      expect(
        KanbanChartColors.getColorForPriority(KanbanPriority.veryHigh),
        0xFFD32F2F,
      );
      expect(
        KanbanChartColors.getColorForPriority(KanbanPriority.high),
        0xFFFF9800,
      );
      expect(
        KanbanChartColors.getColorForPriority(KanbanPriority.normal),
        0xFF9E9E9E,
      );
      expect(
        KanbanChartColors.getColorForPriority(KanbanPriority.low),
        0xFF2196F3,
      );
      expect(
        KanbanChartColors.getColorForPriority(KanbanPriority.veryLow),
        0xFF4CAF50,
      );
    });

    test('getAvatarColor returns consistent colors', () {
      final color1 = KanbanChartColors.getAvatarColor('Alice');
      final color2 = KanbanChartColors.getAvatarColor('Alice');
      final color3 = KanbanChartColors.getAvatarColor('Bob');

      expect(color1, color2); // Same name should give same color
      expect(color1, isNot(equals(color3))); // Different names likely different colors
    });
  });
}
