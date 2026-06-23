import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mermaid/flutter_mermaid.dart';

void main() {
  group('PieChartParser', () {
    const parser = PieChartParser();

    test('parses basic pie chart', () {
      final lines = [
        'pie',
        '    "Dogs" : 386',
        '    "Cats" : 85',
        '    "Rats" : 15',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$1.type, DiagramType.pieChart);
      expect(result.$2.slices.length, 3);
      expect(result.$2.slices[0].label, 'Dogs');
      expect(result.$2.slices[0].value, 386);
      expect(result.$2.slices[1].label, 'Cats');
      expect(result.$2.slices[1].value, 85);
      expect(result.$2.slices[2].label, 'Rats');
      expect(result.$2.slices[2].value, 15);
    });

    test('parses pie chart with title', () {
      final lines = [
        'pie',
        '    title Favorite Pets',
        '    "Dogs" : 386',
        '    "Cats" : 85',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.title, 'Favorite Pets');
      expect(result.$2.slices.length, 2);
    });

    test('parses pie chart with showData option', () {
      final lines = [
        'pie showData',
        '    "Dogs" : 386',
        '    "Cats" : 85',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.showValuesInLegend, true);
    });

    test('parses pie chart with single-quoted labels', () {
      final lines = [
        'pie',
        "    'Dogs' : 386",
        "    'Cats' : 85",
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.slices.length, 2);
      expect(result.$2.slices[0].label, 'Dogs');
      expect(result.$2.slices[1].label, 'Cats');
    });

    test('parses pie chart with unquoted labels', () {
      final lines = [
        'pie',
        '    Dogs : 386',
        '    Cats : 85',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.slices.length, 2);
      expect(result.$2.slices[0].label, 'Dogs');
      expect(result.$2.slices[1].label, 'Cats');
    });

    test('parses pie chart with decimal values', () {
      final lines = [
        'pie',
        '    "Item A" : 33.5',
        '    "Item B" : 66.5',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.slices.length, 2);
      expect(result.$2.slices[0].value, 33.5);
      expect(result.$2.slices[1].value, 66.5);
    });

    test('calculates total value correctly', () {
      final lines = [
        'pie',
        '    "A" : 25',
        '    "B" : 25',
        '    "C" : 50',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.totalValue, 100);
    });

    test('calculates percentage correctly', () {
      final lines = [
        'pie',
        '    "A" : 25',
        '    "B" : 75',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      final pieData = result!.$2;
      expect(pieData.getPercentage(pieData.slices[0]), 25.0);
      expect(pieData.getPercentage(pieData.slices[1]), 75.0);
    });

    test('returns null for empty slices', () {
      final lines = [
        'pie',
        '    title Empty Pie',
      ];

      final result = parser.parse(lines);

      expect(result, isNull);
    });

    test('ignores invalid slice lines', () {
      final lines = [
        'pie',
        '    "Valid" : 50',
        '    Invalid line without colon',
        '    "Also Valid" : 50',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.slices.length, 2);
    });

    test('skips lines with zero or negative values', () {
      final lines = [
        'pie',
        '    "Valid" : 50',
        '    "Zero" : 0',
        '    "Negative" : -10',
        '    "Also Valid" : 50',
      ];

      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.slices.length, 2);
    });
  });

  group('MermaidParser pie chart integration', () {
    const parser = MermaidParser();

    test('detects pie chart type', () {
      const code = '''
pie
    "Dogs" : 386
    "Cats" : 85
''';

      final result = parser.parseWithData(code);

      expect(result, isNotNull);
      expect(result!.diagram.type, DiagramType.pieChart);
      expect(result.pieChartData, isNotNull);
      expect(result.pieChartData!.slices.length, 2);
    });

    test('parse method also works', () {
      const code = '''
pie
    title My Chart
    "A" : 30
    "B" : 70
''';

      final diagram = parser.parse(code);

      expect(diagram, isNotNull);
      expect(diagram!.type, DiagramType.pieChart);
      expect(diagram.title, 'My Chart');
    });

    test('handles pie chart with comments', () {
      const code = '''
pie
    title My Chart
    %% This is a comment
    "A" : 50
    "B" : 50
''';

      final result = parser.parseWithData(code);

      expect(result, isNotNull);
      expect(result!.pieChartData!.slices.length, 2);
    });
  });
}
