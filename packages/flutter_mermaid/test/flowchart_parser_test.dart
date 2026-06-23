import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';

void main() {
  group('FlowchartParser', () {
    late FlowchartParser parser;

    setUp(() {
      parser = FlowchartParser();
    });

    test('should parse basic TD flowchart with diamond node', () {
      // Test _parseNode directly first
      final testLine = 'A[开始] --> B{判断}';
      print('Test line: $testLine');

      // Test the regex
      final arrowRegex = RegExp(r'\s*(==>|-->|---|\.\.\.|===|-.->|-\.->|---->|====|---)\s*(\|[^|]*\|)?\s*');
      final parts = <String>[];
      var lastEnd = 0;
      for (final match in arrowRegex.allMatches(testLine)) {
        if (match.start > lastEnd) {
          parts.add(testLine.substring(lastEnd, match.start).trim());
        }
        lastEnd = match.end;
      }
      if (lastEnd < testLine.length) {
        parts.add(testLine.substring(lastEnd).trim());
      }
      print('Parts: $parts');

      // Test diamond regex directly
      final diamondRegex = RegExp(r'^(\w+)\{(.+)\}$');
      final testStr = 'B{判断}';
      final diamondMatch = diamondRegex.firstMatch(testStr);
      print('Diamond test on "$testStr": ${diamondMatch != null ? "MATCH id=${diamondMatch.group(1)}, label=${diamondMatch.group(2)}" : "NO MATCH"}');

      // Test rectangle regex
      final rectangleRegex = RegExp(r'^(\w+)\[(.+)\]$');
      final rectMatch = rectangleRegex.firstMatch(testStr);
      print('Rectangle test on "$testStr": ${rectMatch != null ? "MATCH" : "NO MATCH"}');

      final result = parser.parse([
        'graph TD',
        'A[开始] --> B{判断}',
        'B -->|是| C[处理A]',
        'B -->|否| D[处理B]',
        'C --> E[结束]',
        'D --> E',
      ]);

      expect(result, isNotNull);

      // Debug: print all nodes
      print('Nodes found: ${result!.nodes.length}');
      for (final node in result.nodes) {
        print('  ${node.id}: label="${node.label}", shape=${node.shape}');
      }

      expect(result.nodes.length, equals(5));

      // Check node shapes
      final nodeA = result.nodes.firstWhere((n) => n.id == 'A');
      final nodeB = result.nodes.firstWhere((n) => n.id == 'B');
      final nodeC = result.nodes.firstWhere((n) => n.id == 'C');

      expect(nodeA.shape, equals(NodeShape.rectangle));
      expect(nodeA.label, equals('开始'));

      expect(nodeB.shape, equals(NodeShape.diamond));
      expect(nodeB.label, equals('判断'));

      expect(nodeC.shape, equals(NodeShape.rectangle));
      expect(nodeC.label, equals('处理A'));
    });

    test('should parse node with different shapes', () {
      final result = parser.parse([
        'graph LR',
        'A[矩形] --> B(圆角)',
        'B --> C{菱形}',
        'C --> D((圆形))',
        'D --> E[[子程序]]',
      ]);

      expect(result, isNotNull);
      expect(result!.nodes.length, equals(5));

      final nodeA = result.nodes.firstWhere((n) => n.id == 'A');
      final nodeB = result.nodes.firstWhere((n) => n.id == 'B');
      final nodeC = result.nodes.firstWhere((n) => n.id == 'C');
      final nodeD = result.nodes.firstWhere((n) => n.id == 'D');
      final nodeE = result.nodes.firstWhere((n) => n.id == 'E');

      expect(nodeA.shape, equals(NodeShape.rectangle));
      expect(nodeB.shape, equals(NodeShape.roundedRect));
      expect(nodeC.shape, equals(NodeShape.diamond));
      expect(nodeD.shape, equals(NodeShape.circle));
      expect(nodeE.shape, equals(NodeShape.subroutine));
    });
  });
}
