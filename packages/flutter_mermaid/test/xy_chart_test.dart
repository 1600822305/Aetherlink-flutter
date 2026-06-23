import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XYChartParser', () {
    const parser = XYChartParser();

    test('parses basic bar chart', () {
      const code = '''xychart-beta
    title "Sales Revenue"
    x-axis [Jan, Feb, Mar, Apr]
    y-axis "Revenue" 0 --> 100
    bar [23, 45, 67, 89]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final xyData = result!.$2;

      expect(xyData.title, 'Sales Revenue');
      expect(xyData.xAxisCategories, ['Jan', 'Feb', 'Mar', 'Apr']);
      expect(xyData.yAxisTitle, 'Revenue');
      expect(xyData.yAxisMin, 0);
      expect(xyData.yAxisMax, 100);
      expect(xyData.series.length, 1);
      expect(xyData.series[0].type, XYSeriesType.bar);
      expect(xyData.series[0].values, [23, 45, 67, 89]);
    });

    test('parses line chart', () {
      const code = '''xychart-beta
    x-axis [Q1, Q2, Q3, Q4]
    line [20, 50, 60, 85]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final xyData = result!.$2;

      expect(xyData.series.length, 1);
      expect(xyData.series[0].type, XYSeriesType.line);
      expect(xyData.series[0].values, [20, 50, 60, 85]);
    });

    test('parses mixed bar and line chart', () {
      const code = '''xychart-beta
    title "Sales Data"
    x-axis [Q1, Q2, Q3, Q4]
    y-axis "Revenue" 0 --> 100
    bar [23, 45, 67, 89]
    line [20, 50, 60, 85]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final xyData = result!.$2;

      expect(xyData.series.length, 2);
      expect(xyData.series[0].type, XYSeriesType.bar);
      expect(xyData.series[1].type, XYSeriesType.line);
    });

    test('parses horizontal orientation', () {
      const code = '''xychart-beta horizontal
    x-axis [A, B, C]
    bar [10, 20, 30]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.orientation, XYChartOrientation.horizontal);
    });

    test('parses unquoted title', () {
      const code = '''xychart-beta
    title Revenue
    x-axis [A, B]
    bar [10, 20]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.title, 'Revenue');
    });

    test('parses negative and decimal values', () {
      const code = '''xychart-beta
    x-axis [A, B, C]
    line [2.3, -3.4, .98]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.series[0].values, [2.3, -3.4, 0.98]);
    });

    test('returns null for empty series', () {
      const code = '''xychart-beta
    x-axis [A, B, C]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNull);
    });

    test('parses x-axis with quoted categories', () {
      const code = '''xychart-beta
    x-axis ["Q1 2024", "Q2 2024", "Q3 2024"]
    bar [10, 20, 30]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      expect(result!.$2.xAxisCategories, ['Q1 2024', 'Q2 2024', 'Q3 2024']);
    });

    test('parses xychart without -beta suffix', () {
      const code = '''xychart
    x-axis [A, B]
    bar [10, 20]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
    });

    test('multiple bar series', () {
      const code = '''xychart-beta
    x-axis [A, B, C]
    bar [10, 20, 30]
    bar [15, 25, 35]''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final xyData = result!.$2;

      expect(xyData.series.length, 2);
      expect(xyData.series[0].type, XYSeriesType.bar);
      expect(xyData.series[1].type, XYSeriesType.bar);
    });
  });

  group('XYChartData', () {
    test('effectiveYMax calculates from data when yMax is null', () {
      const data = XYChartData(
        series: [
          XYChartSeries(type: XYSeriesType.bar, values: [10, 50, 80]),
        ],
        xAxisCategories: ['A', 'B', 'C'],
      );

      expect(data.effectiveYMax, greaterThan(0));
    });

    test('effectiveYMax uses provided yMax', () {
      const data = XYChartData(
        series: [
          XYChartSeries(type: XYSeriesType.bar, values: [10, 50]),
        ],
        yAxisMax: 200,
      );

      expect(data.effectiveYMax, 200);
    });

    test('effectiveYMin defaults to 0', () {
      const data = XYChartData(
        series: [
          XYChartSeries(type: XYSeriesType.bar, values: [10, 50]),
        ],
      );

      expect(data.effectiveYMin, 0);
    });

    test('isCategorical returns true when categories exist', () {
      const data = XYChartData(
        series: [
          XYChartSeries(type: XYSeriesType.bar, values: [10]),
        ],
        xAxisCategories: ['A'],
      );

      expect(data.isCategorical, true);
    });

    test('dataPointCount returns category count for categorical', () {
      const data = XYChartData(
        series: [
          XYChartSeries(type: XYSeriesType.bar, values: [10, 20, 30]),
        ],
        xAxisCategories: ['A', 'B', 'C'],
      );

      expect(data.dataPointCount, 3);
    });
  });
}
