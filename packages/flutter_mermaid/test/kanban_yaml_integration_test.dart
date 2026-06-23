import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kanban YAML Frontmatter Integration', () {
    const parser = MermaidParser();

    test('should parse Kanban diagram with YAML frontmatter through MermaidParser', () {
      const code = '''---
config:
  kanban:
    ticketBaseUrl: 'https://jira.example.com/browse/#TICKET#'
---
kanban
  title 产品开发看板

  backlog[产品待办] wip:10
    task1[用户认证系统] @{ assigned: "张三", ticket: "PROJ-101", priority: "High" }
    task2[数据库设计] @{ assigned: "李四", ticket: "PROJ-102", priority: "Normal" }

  todo[准备开始] wip:5
    task3[登录界面] @{ assigned: "赵六", priority: "Very High" }

  done[已完成]
    task4[CI/CD配置] @{ assigned: "张三" }''';

      final result = parser.parseWithData(code);

      expect(result, isNotNull, reason: 'Parser should successfully parse Kanban with YAML frontmatter');
      expect(result!.diagram.type.toString(), contains('kanban'), reason: 'Should detect Kanban diagram type');
      expect(result.kanbanChartData, isNotNull, reason: 'Should have Kanban chart data');
      expect(result.kanbanChartData!.title, '产品开发看板');
      expect(result.kanbanChartData!.ticketBaseUrl, 'https://jira.example.com/browse/#TICKET#');
      expect(result.kanbanChartData!.columns.length, 3);
      expect(result.kanbanChartData!.columns[0].title, '产品待办');
      expect(result.kanbanChartData!.columns[0].wipLimit, 10);
      expect(result.kanbanChartData!.columns[0].tasks.length, 2);
      expect(result.kanbanChartData!.columns[0].tasks[0].assigned, '张三');
      expect(result.kanbanChartData!.columns[0].tasks[0].ticket, 'PROJ-101');
    });

    test('should parse Kanban without YAML frontmatter', () {
      const code = '''kanban
  title 简单看板

  todo[待办]
    task1[任务1]

  done[完成]
    task2[任务2]''';

      final result = parser.parseWithData(code);

      expect(result, isNotNull);
      expect(result!.diagram.type.toString(), contains('kanban'));
      expect(result.kanbanChartData, isNotNull);
      expect(result.kanbanChartData!.title, '简单看板');
      expect(result.kanbanChartData!.ticketBaseUrl, isNull);
      expect(result.kanbanChartData!.columns.length, 2);
    });

    test('should handle Kanban with empty YAML config', () {
      const code = '''---
config:
---
kanban
  todo[待办]
    task1[任务1]''';

      final result = parser.parseWithData(code);

      expect(result, isNotNull);
      expect(result!.diagram.type.toString(), contains('kanban'));
      expect(result.kanbanChartData, isNotNull);
      expect(result.kanbanChartData!.ticketBaseUrl, isNull);
      expect(result.kanbanChartData!.columns.length, 1);
    });

    test('should handle YAML with other config options', () {
      const code = '''---
config:
  kanban:
    ticketBaseUrl: 'https://github.com/issues/#TICKET#'
    otherOption: 'value'
---
kanban
  title GitHub 问题看板

  backlog[待办]
    issue1[修复 Bug] @{ ticket: "42" }''';

      final result = parser.parseWithData(code);

      expect(result, isNotNull);
      expect(result!.kanbanChartData!.title, 'GitHub 问题看板');
      expect(result.kanbanChartData!.ticketBaseUrl, 'https://github.com/issues/#TICKET#');
      expect(result.kanbanChartData!.columns[0].tasks[0].ticket, '42');
    });
  });
}
