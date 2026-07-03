import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/shared/domain/mcp_tool.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tool_catalog.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/builtin_tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/file_editor/file_editor_tools.dart';
// runCalculatorTool / runTimeTool live in this barrel; the dispatch tests below
// call them directly.
import 'package:aetherlink_flutter/shared/mcp_tools/tools/tools.dart';
import 'package:aetherlink_flutter/shared/mcp_tools/tools/dex_editor_tool.dart';
import 'package:dex_editor/dex_editor.dart';

Map<String, Object?> _json(McpToolResult result) =>
    jsonDecode(result.text) as Map<String, Object?>;

/// 记录最近一次 native 调用的 action/params，并可自定义返回结果，
/// 用于验证 Dart 层把 sessionId / apkPath / locator 归一到同一 sessionId 入参。
class _RecordingDexEditor implements DexEditor {
  String? lastAction;
  Map<String, Object?>? lastParams;
  DexResult Function(String action, Map<String, Object?> params)? onExecute;

  @override
  Future<DexResult> execute(
    String action, [
    Map<String, Object?> params = const {},
  ]) async {
    lastAction = action;
    lastParams = params;
    return onExecute?.call(action, params) ?? const DexResult(success: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

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
        // 原生 dex_editor 插件也在进程内运行（无需 Riverpod Ref）。
        '@aether/dex-editor',
      });
    });

    test('dex_find_method_xrefs exposes CHA resolution modes + methodSignature', () {
      final tool = kBuiltinMcpTools['@aether/dex-editor']!
          .firstWhere((t) => t.name == 'dex_find_method_xrefs');
      final schema = tool.inputSchema;
      final props = schema['properties'] as Map<String, Object?>;
      // 新增可选参数：区分重载 + 三种解析模式。
      expect(props.keys, containsAll(['methodSignature', 'resolution']));
      final resolution = props['resolution'] as Map<String, Object?>;
      expect(resolution['enum'], containsAll(['exact', 'slot', 'dispatch']));
      // 向后兼容：className 仍可选、methodName 必填（sessionId 也必填）。
      expect(schema['required'], containsAll(['sessionId', 'methodName']));
      expect(schema['required'], isNot(contains('resolution')));
      expect(schema['required'], isNot(contains('methodSignature')));
      // 置信度分级：返回说明里应同时提及 certainty 两级与 summary 汇总。
      expect(tool.description, contains('certainty'));
      expect(tool.description, contains('exact'));
      expect(tool.description, contains('possible'));
      expect(tool.description, contains('summary'));
    });

    test('dex_find_field_xrefs exposes fieldType + access filtering', () {
      final tool = kBuiltinMcpTools['@aether/dex-editor']!
          .firstWhere((t) => t.name == 'dex_find_field_xrefs');
      final schema = tool.inputSchema;
      final props = schema['properties'] as Map<String, Object?>;
      // 新增可选参数：区分同名字段 + 读/写过滤。
      expect(props.keys, containsAll(['fieldType', 'access']));
      final access = props['access'] as Map<String, Object?>;
      expect(access['enum'], containsAll(['read', 'write', 'all']));
      // 向后兼容：className 仍可选、fieldName 必填（sessionId 也必填）。
      expect(schema['required'], containsAll(['sessionId', 'fieldName']));
      expect(schema['required'], isNot(contains('access')));
      expect(schema['required'], isNot(contains('fieldType')));
    });

    test('dex_find_class_xrefs exposes a class-level xref query', () {
      final tool = kBuiltinMcpTools['@aether/dex-editor']!
          .firstWhere((t) => t.name == 'dex_find_class_xrefs');
      final schema = tool.inputSchema;
      final props = schema['properties'] as Map<String, Object?>;
      expect(props.keys, containsAll(['className', 'locator', 'limit']));
      // 向后兼容：className 可选（可用 locator 替代），仅 sessionId 必填。
      expect(schema['required'], contains('sessionId'));
      expect(schema['required'], isNot(contains('className')));
    });

    test('dex_open advertises idempotent (apkPath 复用) session semantics', () {
      final tool = kBuiltinMcpTools['@aether/dex-editor']!
          .firstWhere((t) => t.name == 'dex_open');
      expect(tool.description, contains('幂等'));
      expect(tool.description, contains('复用'));
    });

    test('dex_list_sessions surfaces restorable (rebuildable) sessions', () {
      final tool = kBuiltinMcpTools['@aether/dex-editor']!
          .firstWhere((t) => t.name == 'dex_list_sessions');
      expect(tool.description, contains('restorable'));
      expect(tool.description, contains('alive'));
    });

    test('dex_search is the unified search entry with a target enum', () {
      final tool = kBuiltinMcpTools['@aether/dex-editor']!
          .firstWhere((t) => t.name == 'dex_search');
      final props = tool.inputSchema['properties'] as Map<String, Object?>;
      final target = props['target'] as Map<String, Object?>;
      expect(
        target['enum'],
        containsAll(['dex', 'strings', 'files', 'arsc', 'manifest']),
      );
      // 统一入口只强制 query；searchType 按 target=dex 在 handler 内校验。
      expect(tool.inputSchema['required'], contains('query'));
      expect(tool.inputSchema['required'], isNot(contains('searchType')));
    });

    test('session tools document that sessionId also accepts an apkPath', () {
      final tool = kBuiltinMcpTools['@aether/dex-editor']!
          .firstWhere((t) => t.name == 'dex_list_classes');
      final props = tool.inputSchema['properties'] as Map<String, Object?>;
      final sessionId = props['sessionId'] as Map<String, Object?>;
      expect(sessionId['description'], contains('APK 路径'));
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

  group('dex session arg normalization (sessionId / apkPath / locator)', () {
    test('explicit sessionId is forwarded as-is', () async {
      final dex = _RecordingDexEditor();
      await runDexEditorTool(
        'dex_close',
        {'sessionId': 'S-123'},
        editor: dex,
      );
      expect(dex.lastAction, 'closeMultiDexSession');
      expect(dex.lastParams!['sessionId'], 'S-123');
    });

    test('apkPath is accepted in place of sessionId (no manual id needed)',
        () async {
      final dex = _RecordingDexEditor();
      await runDexEditorTool(
        'dex_list_classes',
        {'apkPath': '/sd/app.apk'},
        editor: dex,
      );
      expect(dex.lastAction, 'listClasses');
      // 无 sessionId 时回退到 apkPath；原生 requireOrRebuild 同时接受二者。
      expect(dex.lastParams!['sessionId'], '/sd/app.apk');
    });

    test('locator dex_session:<apkPath> resolves to that apkPath', () async {
      final dex = _RecordingDexEditor();
      await runDexEditorTool(
        'dex_close',
        {'locator': 'dex_session:/sd/app.apk'},
        editor: dex,
      );
      expect(dex.lastParams!['sessionId'], '/sd/app.apk');
    });

    test('sessionId wins over apkPath when both are supplied', () async {
      final dex = _RecordingDexEditor();
      await runDexEditorTool(
        'dex_close',
        {'sessionId': 'S-9', 'apkPath': '/sd/app.apk'},
        editor: dex,
      );
      expect(dex.lastParams!['sessionId'], 'S-9');
    });

    test('unsaved-edits-lost error from native is surfaced to the model',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(
              success: false,
              error: '会话已失效，且上次有未保存的改动（未 dex_save），'
                  '这些改动已随会话丢失，请重新打开并重做修改。',
            );
      final result = await runDexEditorTool(
        'dex_list_classes',
        {'sessionId': 'S-dead'},
        editor: dex,
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('未保存'));
    });
  });

  group('dex_search unified target dispatch', () {
    test('default target=dex hits searchInDexSession', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: {});
      await runDexEditorTool(
        'dex_search',
        {'sessionId': 'S-1', 'query': 'Foo', 'searchType': 'class'},
        editor: dex,
      );
      expect(dex.lastAction, 'searchInDexSession');
      expect(dex.lastParams!['searchType'], 'class');
    });

    test('target=strings routes to listStrings (session)', () async {
      final dex = _RecordingDexEditor();
      await runDexEditorTool(
        'dex_search',
        {'target': 'strings', 'sessionId': 'S-1', 'query': 'http', 'filter': 'http'},
        editor: dex,
      );
      expect(dex.lastAction, 'listStrings');
      expect(dex.lastParams!['filter'], 'http');
    });

    test('target=files routes to searchTextInApk with query as pattern',
        () async {
      final dex = _RecordingDexEditor();
      await runDexEditorTool(
        'dex_search',
        {'target': 'files', 'apkPath': '/sd/app.apk', 'query': 'AdView'},
        editor: dex,
      );
      expect(dex.lastAction, 'searchTextInApk');
      expect(dex.lastParams!['pattern'], 'AdView');
    });

    test('target=arsc maps arscTarget to native target', () async {
      final dex = _RecordingDexEditor();
      await runDexEditorTool(
        'dex_search',
        {
          'target': 'arsc',
          'apkPath': '/sd/app.apk',
          'query': 'app_name',
          'arscTarget': 'resources',
          'type': 'string',
        },
        editor: dex,
      );
      expect(dex.lastAction, 'searchArscResources');
      expect(dex.lastParams!['type'], 'string');
    });

    test('target=manifest routes to searchManifestCpp', () async {
      final dex = _RecordingDexEditor();
      await runDexEditorTool(
        'dex_search',
        {
          'target': 'manifest',
          'apkPath': '/sd/app.apk',
          'query': 'ignored',
          'attrName': 'android:exported',
        },
        editor: dex,
      );
      expect(dex.lastAction, 'searchManifestCpp');
      expect(dex.lastParams!['attrName'], 'android:exported');
    });

    test('target=dex without searchType is a clear error', () async {
      final dex = _RecordingDexEditor();
      final result = await runDexEditorTool(
        'dex_search',
        {'sessionId': 'S-1', 'query': 'Foo'},
        editor: dex,
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('searchType'));
      expect(dex.lastAction, isNull);
    });

    test('unknown target is a clear error', () async {
      final dex = _RecordingDexEditor();
      final result = await runDexEditorTool(
        'dex_search',
        {'target': 'bogus', 'query': 'x'},
        editor: dex,
      );
      expect(result.isError, isTrue);
      expect(result.text, contains('target'));
      expect(dex.lastAction, isNull);
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
