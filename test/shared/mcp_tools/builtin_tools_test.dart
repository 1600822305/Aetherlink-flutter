import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
// runCalculatorTool / runTimeTool live in this barrel; the dispatch tests below
// call them directly.
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tools.dart';

Map<String, Object?> _json(McpToolResult result) =>
    jsonDecode(result.text) as Map<String, Object?>;

void main() {
  group('runBuiltinTool dispatch', () {
    test('routes only the locally-runnable servers', () async {
      expect(
        await runBuiltinTool('@aether/calculator', 'calculate', {
          'expression': '1+1',
        }),
        isNotNull,
      );
      expect(
        await runBuiltinTool('@aether/time', 'get_current_time', const {}),
        isNotNull,
      );
      // Native-plugin and external servers are not locally runnable.
      expect(
        await runBuiltinTool('@aether/calendar', 'get_calendars', const {}),
        isNull,
      );
      expect(
        await runBuiltinTool('@aether/alarm', 'show_alarms', const {}),
        isNull,
      );
      expect(
        await runBuiltinTool('external-xyz', 'whatever', const {}),
        isNull,
      );
    });

    test('unknown calculator tool is an error result', () {
      final result = runCalculatorTool('nope', const {});
      expect(result.isError, isTrue);
      expect(_json(result)['success'], isFalse);
    });
  });

  group('calculate', () {
    test('basic and scientific expressions', () {
      final r = _json(
        runCalculatorTool('calculate', {'expression': '2 + 3 * 4'}),
      );
      expect(r['success'], isTrue);
      expect(r['result'], 14);
      expect(r['formatted'], '14');

      final s = _json(
        runCalculatorTool('calculate', {'expression': 'sqrt(16)'}),
      );
      expect(s['result'], 4);

      final p = _json(
        runCalculatorTool('calculate', {'expression': 'pow(2, 10)'}),
      );
      expect(p['result'], 1024);
    });

    test('non-integer result is formatted to <=10 decimals', () {
      final r = _json(runCalculatorTool('calculate', {'expression': '1 / 3'}));
      expect(r['success'], isTrue);
      expect(r['formatted'], '0.3333333333');
    });

    test('malformed expression yields an error result', () {
      final result = runCalculatorTool('calculate', {'expression': '2 +'});
      expect(result.isError, isTrue);
      final r = _json(result);
      expect(r['success'], isFalse);
      expect(r['error'], isNotNull);
    });
  });

  group('convert_base', () {
    test('decimal to binary/hex', () {
      final bin = _json(
        runCalculatorTool('convert_base', {
          'value': '255',
          'fromBase': 10,
          'toBase': 2,
        }),
      );
      expect((bin['output'] as Map)['value'], '11111111');
      expect(bin['decimal'], 255);

      final hex = _json(
        runCalculatorTool('convert_base', {
          'value': '255',
          'fromBase': 10,
          'toBase': 16,
        }),
      );
      expect((hex['output'] as Map)['value'], 'FF');
    });

    test('hex to decimal (accepts lowercase)', () {
      final dec = _json(
        runCalculatorTool('convert_base', {
          'value': 'ff',
          'fromBase': 16,
          'toBase': 10,
        }),
      );
      expect((dec['output'] as Map)['value'], '255');
    });

    test('rejects unsupported base and invalid value', () {
      expect(
        runCalculatorTool('convert_base', {
          'value': '10',
          'fromBase': 3,
          'toBase': 10,
        }).isError,
        isTrue,
      );
      expect(
        runCalculatorTool('convert_base', {
          'value': 'xyz',
          'fromBase': 10,
          'toBase': 2,
        }).isError,
        isTrue,
      );
    });
  });

  group('convert_unit', () {
    test('length and weight via base factors', () {
      final len = _json(
        runCalculatorTool('convert_unit', {
          'value': 1000,
          'category': 'length',
          'fromUnit': 'm',
          'toUnit': 'km',
        }),
      );
      expect(len['result'], 1);
      expect(len['input'], '1000 m');
      expect(len['output'], '1 km');

      final w = _json(
        runCalculatorTool('convert_unit', {
          'value': 2,
          'category': 'weight',
          'fromUnit': 'kg',
          'toUnit': 'g',
        }),
      );
      expect(w['result'], 2000);
    });

    test('temperature conversions', () {
      final f = _json(
        runCalculatorTool('convert_unit', {
          'value': 100,
          'category': 'temperature',
          'fromUnit': 'celsius',
          'toUnit': 'fahrenheit',
        }),
      );
      expect(f['result'], 212);

      final k = _json(
        runCalculatorTool('convert_unit', {
          'value': 0,
          'category': 'temperature',
          'fromUnit': 'celsius',
          'toUnit': 'kelvin',
        }),
      );
      expect(k['result'], closeTo(273.15, 1e-9));
    });

    test('rejects unknown unit / category', () {
      expect(
        runCalculatorTool('convert_unit', {
          'value': 1,
          'category': 'length',
          'fromUnit': 'm',
          'toUnit': 'parsec',
        }).isError,
        isTrue,
      );
      expect(
        runCalculatorTool('convert_unit', {
          'value': 1,
          'category': 'mass',
          'fromUnit': 'm',
          'toUnit': 'km',
        }).isError,
        isTrue,
      );
    });
  });

  group('statistics', () {
    test('computes the full summary', () {
      final r = _json(
        runCalculatorTool('statistics', {
          'numbers': [1, 2, 3, 4, 5],
        }),
      );
      expect(r['success'], isTrue);
      expect(r['count'], 5);
      expect(r['sum'], 15);
      expect(r['mean'], 3);
      expect(r['median'], 3);
      expect(r['min'], 1);
      expect(r['max'], 5);
      expect(r['range'], 4);
      expect(
        (r['standardDeviation'] as num).toDouble(),
        closeTo(1.4142135624, 1e-6),
      );
      expect(r['sorted'], [1, 2, 3, 4, 5]);
    });

    test(
      'even count median is the midpoint average; mode null when all unique',
      () {
        final r = _json(
          runCalculatorTool('statistics', {
            'numbers': [4, 1, 3, 2],
          }),
        );
        expect(r['median'], 2.5);
        expect(r['mode'], isNull);
      },
    );

    test('mode returned when a value repeats', () {
      final r = _json(
        runCalculatorTool('statistics', {
          'numbers': [1, 2, 2, 3],
        }),
      );
      expect(r['mode'], 2);
    });

    test('rejects empty / non-array input', () {
      expect(
        runCalculatorTool('statistics', {'numbers': const []}).isError,
        isTrue,
      );
      expect(runCalculatorTool('statistics', const {}).isError, isTrue);
    });
  });

  group('get_current_time', () {
    final fixed = DateTime.utc(2025, 6, 18, 8, 30, 15); // Wed

    test('iso format echoes the instant', () {
      final r = _json(
        runTimeTool('get_current_time', {'format': 'iso'}, now: fixed),
      );
      expect(r['format'], 'iso');
      expect(r['currentTime'], fixed.toUtc().toIso8601String());
    });

    test('timestamp format exposes ms and seconds', () {
      final r = _json(
        runTimeTool('get_current_time', {'format': 'timestamp'}, now: fixed),
      );
      expect(r['currentTime'], fixed.millisecondsSinceEpoch.toString());
      expect(r['milliseconds'], fixed.millisecondsSinceEpoch);
      expect(r['seconds'], fixed.millisecondsSinceEpoch ~/ 1000);
    });

    test('locale format breaks down the local date parts', () {
      final local = fixed.toLocal();
      final r = _json(
        runTimeTool('get_current_time', {'format': 'locale'}, now: fixed),
      );
      expect(r['format'], 'locale');
      expect(r['year'], local.year);
      expect(r['month'], local.month);
      expect(r['day'], local.day);
      expect(r['hour'], local.hour);
      expect(r['weekday'], isA<String>());
    });

    test('a requested timezone is acknowledged but not converted', () {
      final r = _json(
        runTimeTool('get_current_time', {
          'format': 'locale',
          'timezone': 'America/New_York',
        }, now: fixed),
      );
      expect(r['timezone'], 'America/New_York');
      expect(r['note'], isNotNull);
    });

    test('unknown time tool returns a plain-text error', () {
      final result = runTimeTool('nope', const {}, now: fixed);
      expect(result.text, contains('获取时间失败'));
    });
  });

  group('builtin tool catalog', () {
    test('exposes the four calc-class servers with their tools', () {
      expect(
        kBuiltinMcpTools['@aether/calculator']!.map((t) => t.name),
        containsAll([
          'calculate',
          'convert_base',
          'convert_unit',
          'statistics',
        ]),
      );
      expect(kBuiltinMcpTools['@aether/time']!.single.name, 'get_current_time');
      expect(builtinToolsFor('@aether/calendar'), isNotEmpty);
      expect(builtinToolsFor('@aether/alarm'), isNotEmpty);
      expect(builtinToolsFor('unknown-server'), isEmpty);
    });

    test('the locally-runnable builtins are the pure-compute / HTTP servers', () {
      expect(kLocallyRunnableBuiltins, {
        '@aether/calculator',
        '@aether/time',
        '@aether/searxng',
        '@aether/fetch',
        '@aether/metaso-search',
        '@aether/grok-search',
      });
    });

    test('file-editor exposes run_command requiring a command (SSH-3)', () {
      final tool = kBuiltinMcpTools['@aether/file-editor']!
          .firstWhere((t) => t.name == 'run_command');
      final schema = tool.inputSchema;
      expect(schema['required'], contains('command'));
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.keys, containsAll(['command', 'workspace', 'cwd', 'timeout_ms']));
    });
  });

  group('file-editor risk classification', () {
    test('run_command is high-risk and needs HITL confirmation', () {
      expect(fileEditorRiskLevel('run_command'), FileEditorRisk.high);
      expect(fileEditorNeedsConfirmation('run_command'), isTrue);
    });

    test('read-only tools need no confirmation', () {
      expect(fileEditorRiskLevel('read_file'), isNull);
      expect(fileEditorNeedsConfirmation('read_file'), isFalse);
    });
  });
}
