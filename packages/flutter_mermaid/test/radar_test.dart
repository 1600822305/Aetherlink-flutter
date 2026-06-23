import 'package:flutter_mermaid/flutter_mermaid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RadarParser', () {
    const parser = RadarParser();

    test('parses basic radar chart', () {
      const code = '''radar-beta
    axis A, B, C, D, E
    curve c1{1, 2, 3, 4, 5}
    curve c2{5, 4, 3, 2, 1}''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final radarData = result!.$2;

      expect(radarData.axes.length, 5);
      expect(radarData.curves.length, 2);
      expect(radarData.axes[0].id, 'A');
      expect(radarData.axes[0].label, 'A');
      expect(radarData.curves[0].id, 'c1');
      expect(radarData.curves[0].values, [1, 2, 3, 4, 5]);
    });

    test('parses radar chart with labeled axes', () {
      const code = '''radar-beta
    axis A["Label A"], B["Label B"], C["Label C"]
    curve data{1, 2, 3}''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final radarData = result!.$2;

      expect(radarData.axes.length, 3);
      expect(radarData.axes[0].id, 'A');
      expect(radarData.axes[0].label, 'Label A');
      expect(radarData.axes[1].id, 'B');
      expect(radarData.axes[1].label, 'Label B');
    });

    test('parses radar chart with labeled curves', () {
      const code = '''radar-beta
    axis A, B, C
    curve c1["Curve One"]{1, 2, 3}
    curve c2["Curve Two"]{3, 2, 1}''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final radarData = result!.$2;

      expect(radarData.curves.length, 2);
      expect(radarData.curves[0].label, 'Curve One');
      expect(radarData.curves[1].label, 'Curve Two');
    });

    test('parses radar chart with title', () {
      const code = '''radar-beta
    title My Radar Chart
    axis A, B, C
    curve c1{1, 2, 3}''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final radarData = result!.$2;

      expect(radarData.title, 'My Radar Chart');
    });

    test('parses radar chart with options', () {
      const code = '''radar-beta
    axis A, B, C
    curve c1{1, 2, 3}
    showLegend false
    max 10
    min 0
    graticule circle
    ticks 10''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final radarData = result!.$2;

      expect(radarData.showLegend, false);
      expect(radarData.max, 10);
      expect(radarData.min, 0);
      expect(radarData.graticule, RadarGraticule.circle);
      expect(radarData.ticks, 10);
    });

    test('parses radar chart with key-value format', () {
      const code = '''radar-beta
    axis A, B, C
    curve c1{A: 1, B: 2, C: 3}''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final radarData = result!.$2;

      expect(radarData.curves[0].values, [1, 2, 3]);
    });

    test('returns null for invalid radar chart (no axes)', () {
      const code = '''radar-beta
    curve c1{1, 2, 3}''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNull);
    });

    test('returns null for invalid radar chart (no curves)', () {
      const code = '''radar-beta
    axis A, B, C''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNull);
    });

    test('handles empty lines gracefully', () {
      const code = '''radar-beta

    axis A, B, C

    curve c1{1, 2, 3}
    ''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final radarData = result!.$2;

      expect(radarData.axes.length, 3);
      expect(radarData.curves.length, 1);
    });

    test('parses Chinese labels correctly', () {
      const code = '''radar-beta
    title 技能评估
    axis 编程, 设计, 沟通, 管理, 创新
    curve 张三{5, 3, 4, 2, 4}
    curve 李四{3, 5, 3, 4, 3}''';

      final lines = code.split('\n').map((l) => l.trim()).toList();
      final result = parser.parse(lines);

      expect(result, isNotNull);
      final radarData = result!.$2;

      expect(radarData.title, '技能评估');
      expect(radarData.axes.length, 5);
      expect(radarData.axes[0].label, '编程');
      expect(radarData.axes[1].label, '设计');
      expect(radarData.curves[0].label, '张三');
      expect(radarData.curves[1].label, '李四');
    });
  });

  group('RadarChartData', () {
    test('effectiveMax calculates from data when max is null', () {
      const data = RadarChartData(
        axes: [
          RadarAxis(id: 'A', label: 'A'),
          RadarAxis(id: 'B', label: 'B'),
        ],
        curves: [
          RadarCurve(id: 'c1', label: 'c1', values: [5, 8]),
          RadarCurve(id: 'c2', label: 'c2', values: [3, 7]),
        ],
      );

      expect(data.effectiveMax, greaterThanOrEqualTo(8));
    });

    test('effectiveMax uses provided max value', () {
      const data = RadarChartData(
        axes: [
          RadarAxis(id: 'A', label: 'A'),
          RadarAxis(id: 'B', label: 'B'),
        ],
        curves: [
          RadarCurve(id: 'c1', label: 'c1', values: [5, 8]),
        ],
        max: 100,
      );

      expect(data.effectiveMax, 100);
    });

    test('effectiveMin defaults to 0', () {
      const data = RadarChartData(
        axes: [
          RadarAxis(id: 'A', label: 'A'),
        ],
        curves: [
          RadarCurve(id: 'c1', label: 'c1', values: [5]),
        ],
      );

      expect(data.effectiveMin, 0);
    });

    test('effectiveMin uses provided min value', () {
      const data = RadarChartData(
        axes: [
          RadarAxis(id: 'A', label: 'A'),
        ],
        curves: [
          RadarCurve(id: 'c1', label: 'c1', values: [5]),
        ],
        min: -10,
      );

      expect(data.effectiveMin, -10);
    });
  });
}
