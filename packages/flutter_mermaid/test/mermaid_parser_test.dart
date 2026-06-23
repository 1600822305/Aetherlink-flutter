import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';

void main() {
  group('MermaidParser', () {
    const parser = MermaidParser();

    test('detects flowchart diagram type', () {
      final result = parser.parse('''
graph TD
  A --> B
''');
      expect(result, isNotNull);
      expect(result!.type, DiagramType.flowchart);
    });

    test('detects sequence diagram type', () {
      final result = parser.parse('''
sequenceDiagram
  A->>B: Hello
''');
      expect(result, isNotNull);
      expect(result!.type, DiagramType.sequence);
    });

    test('returns null for empty input', () {
      expect(parser.parse(''), isNull);
      expect(parser.parse('   '), isNull);
    });

    test('returns null for unknown diagram type', () {
      expect(parser.parse('unknown diagram type'), isNull);
    });

    test('removes comments', () {
      final result = parser.parse('''
graph TD
  %% This is a comment
  A --> B
''');
      expect(result, isNotNull);
      expect(result!.nodes.length, 2);
    });
  });

  group('FlowchartParser', () {
    test('parses simple flowchart', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A --> B',
      ]);

      expect(result, isNotNull);
      expect(result!.nodes.length, 2);
      expect(result.edges.length, 1);
    });

    test('parses direction correctly', () {
      final parser = FlowchartParser();

      var result = parser.parse(['graph TD', 'A --> B']);
      expect(result!.direction, DiagramDirection.topToBottom);

      result = parser.parse(['graph LR', 'A --> B']);
      expect(result!.direction, DiagramDirection.leftToRight);

      result = parser.parse(['graph BT', 'A --> B']);
      expect(result!.direction, DiagramDirection.bottomToTop);

      result = parser.parse(['graph RL', 'A --> B']);
      expect(result!.direction, DiagramDirection.rightToLeft);
    });

    test('parses node with rectangle shape', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A[Hello World]',
      ]);

      expect(result, isNotNull);
      expect(result!.nodes.length, 1);
      expect(result.nodes.first.id, 'A');
      expect(result.nodes.first.label, 'Hello World');
      expect(result.nodes.first.shape, NodeShape.rectangle);
    });

    test('parses node with rounded rect shape', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A(Rounded)',
      ]);

      expect(result!.nodes.first.shape, NodeShape.roundedRect);
    });

    test('parses node with diamond shape', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A{Decision}',
      ]);

      expect(result!.nodes.first.shape, NodeShape.diamond);
    });

    test('parses node with circle shape', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A((Circle))',
      ]);

      expect(result!.nodes.first.shape, NodeShape.circle);
    });

    test('parses node with stadium shape', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A([Stadium])',
      ]);

      expect(result!.nodes.first.shape, NodeShape.stadium);
    });

    test('parses node with cylinder shape', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A[(Database)]',
      ]);

      expect(result!.nodes.first.shape, NodeShape.cylinder);
    });

    test('parses edge with label', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A -->|Yes| B',
      ]);

      expect(result!.edges.length, 1);
      expect(result.edges.first.from, 'A');
      expect(result.edges.first.to, 'B');
      expect(result.edges.first.label, 'Yes');
    });

    test('parses dotted edge', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A -.-> B',
      ]);

      expect(result!.edges.first.lineType, LineType.dotted);
    });

    test('parses thick edge', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A ==> B',
      ]);

      expect(result!.edges.first.lineType, LineType.thick);
    });

    test('parses chained edges', () {
      final parser = FlowchartParser();
      final result = parser.parse([
        'graph TD',
        '  A --> B --> C',
      ]);

      expect(result!.nodes.length, 3);
      expect(result.edges.length, 2);
    });
  });

  group('SequenceParser', () {
    test('parses simple sequence diagram', () {
      final parser = SequenceParser();
      final result = parser.parse([
        'sequenceDiagram',
        '  A->>B: Hello',
      ]);

      expect(result, isNotNull);
      expect(result!.nodes.length, 2);
      expect(result.edges.length, 1);
    });

    test('parses participant declarations', () {
      final parser = SequenceParser();
      final result = parser.parse([
        'sequenceDiagram',
        '  participant A as Alice',
        '  participant B as Bob',
        '  A->>B: Hello',
      ]);

      expect(result!.nodes.length, 2);
      final alice = result.nodes.firstWhere((n) => n.id == 'A');
      expect(alice.label, 'Alice');
    });

    test('parses actor declarations', () {
      final parser = SequenceParser();
      final result = parser.parse([
        'sequenceDiagram',
        '  actor User',
        '  User->>Server: Request',
      ]);

      final user = result!.nodes.firstWhere((n) => n.id == 'User');
      expect(user, isA<SequenceParticipant>());
      expect((user as SequenceParticipant).participantType,
          ParticipantType.actor);
    });

    test('parses message types correctly', () {
      final parser = SequenceParser();
      final result = parser.parse([
        'sequenceDiagram',
        '  A->>B: Sync',
        '  A-->>B: Reply',
      ]);

      expect(result!.edges.length, 2);
      expect(result.edges[0].lineType, LineType.solid);
      expect(result.edges[1].lineType, LineType.dotted);
    });

    test('auto-creates participants from messages', () {
      final parser = SequenceParser();
      final result = parser.parse([
        'sequenceDiagram',
        '  Client->>Server: Request',
      ]);

      expect(result!.nodes.length, 2);
      expect(result.nodes.any((n) => n.id == 'Client'), isTrue);
      expect(result.nodes.any((n) => n.id == 'Server'), isTrue);
    });
  });
}
