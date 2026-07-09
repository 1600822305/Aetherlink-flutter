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
  final List<String> actions = <String>[];
  final Map<String, Map<String, Object?>> paramsByAction = {};
  DexResult Function(String action, Map<String, Object?> params)? onExecute;

  /// 最近一次某 action 的入参（用于断言，某些工具会连续调用多个 native action）。
  Map<String, Object?>? paramsFor(String action) => paramsByAction[action];

  @override
  Future<DexResult> execute(
    String action, [
    Map<String, Object?> params = const {},
  ]) async {
    lastAction = action;
    lastParams = params;
    actions.add(action);
    paramsByAction[action] = params;
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

    test('target=dex decorates method results with dex_method locator',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: {
              'results': [
                {
                  'type': 'method',
                  'className': 'com.example.Foo',
                  'methodName': 'bar',
                  'prototype': '(I)V',
                  'dexFile': 'classes.dex',
                },
              ],
              'total': 1,
            });
      final result = await runDexEditorTool(
        'dex_search',
        {'sessionId': 'S-1', 'query': 'bar', 'searchType': 'method'},
        editor: dex,
      );
      final results = _json(result)['results'] as List;
      expect(
        (results.first as Map)['locator'],
        'dex_method:Lcom/example/Foo;->bar(I)V',
      );
    });

    test('target=dex code search yields dex_method locator + lineNumber',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: {
              'results': [
                {
                  'type': 'code',
                  'className': 'com.example.Foo',
                  'methodName': 'bar',
                  'prototype': '()V',
                  'line': 3,
                  'snippet': 'const-string v0',
                },
              ],
            });
      final result = await runDexEditorTool(
        'dex_search',
        {'sessionId': 'S-1', 'query': 'const-string', 'searchType': 'code'},
        editor: dex,
      );
      final r = (_json(result)['results'] as List).first as Map;
      expect(r['locator'], 'dex_method:Lcom/example/Foo;->bar()V');
      expect(r['lineNumber'], 3);
      expect(r.containsKey('line'), isFalse);
      expect(r['snippet'], 'const-string v0');
    });

    test('target=dex paginates via offset/limit with hasMore + nextCursor',
        () async {
      final five = List.generate(
        5,
        (i) => {'type': 'class', 'className': 'com.example.C$i'},
      );
      final dex = _RecordingDexEditor()
        ..onExecute =
            (_, __) => DexResult(success: true, data: {'results': five});
      final page1 = _json(await runDexEditorTool(
        'dex_search',
        {'sessionId': 'S-1', 'query': 'C', 'searchType': 'class', 'limit': 2},
        editor: dex,
      ));
      final r1 = page1['results'] as List;
      expect(r1.length, 2);
      expect((r1.first as Map)['locator'], 'dex_class:com.example.C0');
      expect(page1['hasMore'], isTrue);
      expect(page1['nextCursor'], isNotNull);
      final page2 = _json(await runDexEditorTool(
        'dex_search',
        {
          'sessionId': 'S-1',
          'query': 'C',
          'searchType': 'class',
          'cursor': page1['nextCursor'],
        },
        editor: dex,
      ));
      final r2 = page2['results'] as List;
      expect(r2.length, 2);
      expect((r2.first as Map)['className'], 'com.example.C2');
    });

    test('target=strings paginates the native string pool', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => DexResult(success: true, data: {
              'strings': List.generate(5, (i) => 'http://s$i'),
              'total': 5,
            });
      final page1 = _json(await runDexEditorTool(
        'dex_search',
        {'target': 'strings', 'sessionId': 'S-1', 'query': 'http', 'limit': 2},
        editor: dex,
      ));
      // 拉取 offset+limit+1 探测 hasMore。
      expect(dex.lastParams!['limit'], 3);
      expect((page1['strings'] as List).length, 2);
      expect(page1['hasMore'], isTrue);
      expect(page1['nextCursor'], isNotNull);
    });

    test('target=dex string search attributes className→locator', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: {
              'results': [
                {
                  'type': 'string',
                  'value': 'http://api.example.com',
                  'className': 'com.example.Api',
                },
              ],
              'total': 1,
            });
      final result = await runDexEditorTool(
        'dex_search',
        {'sessionId': 'S-1', 'query': 'http', 'searchType': 'string'},
        editor: dex,
      );
      final r = (_json(result)['results'] as List).first as Map;
      // native 反扫 const-string 回填的 className 归一为单一 locator（去 classLocator）。
      expect(r['locator'], 'dex_class:com.example.Api');
      expect(r.containsKey('classLocator'), isFalse);
    });

    test('target=arsc resources gets locator + resourceType/name + variant',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: [
              {
                'id': 0x7f0f0001,
                'name': 'app_name',
                'type': 'string',
                'value': 'Demo',
                'variant': 'zh-rCN',
              },
            ]);
      final json = _json(await runDexEditorTool(
        'dex_search',
        {
          'target': 'arsc',
          'apkPath': '/sd/app.apk',
          'query': 'app_name',
          'arscTarget': 'resources',
        },
        editor: dex,
      ));
      final r = (json['results'] as List).first as Map;
      expect(r['locator'], 'resource:0x7f0f0001');
      expect(r['resourceType'], 'string');
      expect(r['resourceName'], 'app_name');
      expect(r['variant'], 'zh-rCN');
      expect(json['hasMore'], isFalse);
    });

    test('target=arsc resources defaults variant to "default" when absent',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: [
              {'id': 0x7f0f0002, 'name': 'foo', 'type': 'string', 'value': 'x'},
            ]);
      final json = _json(await runDexEditorTool(
        'dex_search',
        {
          'target': 'arsc',
          'apkPath': '/sd/app.apk',
          'query': 'foo',
          'arscTarget': 'resources',
        },
        editor: dex,
      ));
      final r = (json['results'] as List).first as Map;
      expect(r['variant'], 'default');
    });

    test('target=arsc strings gets arsc_string locator', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (action, params) {
          if (action == 'searchArscStrings') {
            return const DexResult(success: true, data: [
              {'value': 'login', 'index': 42},
            ]);
          }
          return const DexResult(success: true, data: []);
        };
      final json = _json(await runDexEditorTool(
        'dex_search',
        {
          'target': 'arsc',
          'apkPath': '/sd/app.apk',
          'query': 'login',
          'arscTarget': 'strings',
        },
        editor: dex,
      ));
      expect(dex.lastAction, 'searchArscStrings');
      final r = (json['results'] as List).first as Map;
      expect(r['locator'], 'arsc_string:42');
      expect(r['value'], 'login');
    });

    test('target=manifest falls back to query when value absent', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: []);
      await runDexEditorTool(
        'dex_search',
        {
          'target': 'manifest',
          'apkPath': '/sd/app.apk',
          'query': 'login',
        },
        editor: dex,
      );
      expect(dex.lastAction, 'searchManifestCpp');
      // 统一入口用 query 传搜索词，_searchManifestCpp 需回退 query→value。
      expect(dex.lastParams!['value'], 'login');
    });

    test('target=manifest paginates a bare native array', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => DexResult(
              success: true,
              data: List.generate(
                5,
                (i) => {'element': 'activity', 'attribute': 'name', 'value': 'A$i'},
              ),
            );
      final json = _json(await runDexEditorTool(
        'dex_search',
        {
          'target': 'manifest',
          'apkPath': '/sd/app.apk',
          'query': 'A',
          'limit': 2,
        },
        editor: dex,
      ));
      expect((json['results'] as List).length, 2);
      expect(json['hasMore'], isTrue);
      expect(json['nextCursor'], isNotNull);
    });

    test('target=overview aggregates dex facets into hits', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (action, params) {
          final st = params['searchType'];
          final item = <String, Object?>{'type': st};
          if (st == 'string') {
            item['value'] = 'hello';
          } else {
            item['className'] = 'com.example.Foo';
            if (st == 'method') {
              item['methodName'] = 'bar';
              item['prototype'] = '()V';
            } else if (st == 'field') {
              item['fieldName'] = 'x';
              item['fieldType'] = 'I';
            }
          }
          return DexResult(success: true, data: {
            'results': [item],
          });
        };
      final json = _json(await runDexEditorTool(
        'dex_search',
        {'target': 'overview', 'sessionId': 'S-1', 'query': 'Foo'},
        editor: dex,
      ));
      final hits = json['hits'] as Map;
      expect(hits.keys, containsAll(['class', 'method', 'field', 'string']));
      expect(json['total'], 4);
      final method = (hits['method'] as List).first as Map;
      expect(method['locator'], 'dex_method:Lcom/example/Foo;->bar()V');
      // 无 apkPath 时不含整包面。
      expect(json['apkFacets'], isFalse);
      expect(hits.containsKey('file'), isFalse);
    });

    test('target=overview also aggregates file/resource/manifest with apkPath',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (action, params) {
          switch (action) {
            case 'searchInDexSession':
              return DexResult(success: true, data: {
                'results': [
                  {'type': params['searchType'], 'className': 'com.example.Foo'},
                ],
              });
            case 'searchTextInApk':
              return const DexResult(success: true, data: {
                'results': [
                  {'file': 'assets/a.json', 'lineNumber': 1, 'line': 'x'},
                ],
              });
            case 'searchArscResources':
              return const DexResult(success: true, data: {
                'results': [
                  {'id': 0x7f0e0001, 'name': 'app_name', 'type': 'string'},
                ],
              });
            case 'searchManifestCpp':
              return const DexResult(success: true, data: {
                'results': [
                  {'attrName': 'android:name', 'value': 'com.example.Foo'},
                ],
              });
            default:
              return const DexResult(success: true, data: {});
          }
        };
      final json = _json(await runDexEditorTool(
        'dex_search',
        {'target': 'overview', 'apkPath': '/sd/app.apk', 'query': 'Foo'},
        editor: dex,
      ));
      expect(json['apkFacets'], isTrue);
      final hits = json['hits'] as Map;
      expect(
        hits.keys,
        containsAll(
          ['class', 'method', 'field', 'string', 'file', 'resource', 'manifest'],
        ),
      );
      expect(((hits['file'] as List).first as Map)['locator'],
          'apk_file:assets/a.json:1');
      expect(((hits['resource'] as List).first as Map)['locator'],
          'resource:0x7f0e0001');
      // 用 sessionId 直接填 APK 路径也应触发整包面。
      final viaSession = _json(await runDexEditorTool(
        'dex_search',
        {'target': 'overview', 'sessionId': '/sd/app.apk', 'query': 'Foo'},
        editor: dex,
      ));
      expect(viaSession['apkFacets'], isTrue);
    });

    test('target=arsc resources adds resource locator + resourceType/Name',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: {
              'results': [
                {
                  'id': 0x7f0e0001,
                  'name': 'app_name',
                  'type': 'string',
                  'value': 'WenXiaoBai',
                },
              ],
            });
      final json = _json(await runDexEditorTool(
        'dex_search',
        {
          'target': 'arsc',
          'apkPath': '/sd/app.apk',
          'query': 'app_name',
          'arscTarget': 'resources',
        },
        editor: dex,
      ));
      final r = (json['results'] as List).first as Map;
      expect(r['locator'], 'resource:0x7f0e0001');
      expect(r['resourceType'], 'string');
      expect(r['resourceName'], 'app_name');
    });

    test('target=files adds apk_file locator', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(success: true, data: {
              'results': [
                {'file': 'assets/config.json', 'lineNumber': 12, 'line': 'x'},
              ],
              'totalFound': 1,
            });
      final json = _json(await runDexEditorTool(
        'dex_search',
        {'target': 'files', 'apkPath': '/sd/app.apk', 'query': 'x'},
        editor: dex,
      ));
      final r = (json['results'] as List).first as Map;
      expect(r['locator'], 'apk_file:assets/config.json:12');
    });
  });

  group('dex read structured outputs (locator + targetVersion)', () {
    test('dex_read_class returns JSON with locator + targetVersion + smali',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(
              success: true,
              data: {'smaliContent': '.class public Lcom/example/Foo;\n'},
            );
      final result = await runDexEditorTool(
        'dex_read_class',
        {'sessionId': 'S-1', 'className': 'Lcom/example/Foo;'},
        editor: dex,
      );
      expect(dex.lastAction, 'getClassSmaliFromSession');
      final json = _json(result);
      expect(json['className'], 'com.example.Foo');
      expect(json['locator'], 'dex_class:com.example.Foo');
      expect((json['targetVersion'] as String).startsWith('dex-v1:'), isTrue);
      expect(json['smali'], contains('.class public Lcom/example/Foo;'));
    });

    test('dex_read_method dispatches getMethodFromSession with structured JSON',
        () async {
      const classSmali = '.class public Lcom/example/Foo;\n'
          '.super Ljava/lang/Object;\n'
          '.method public bar(I)V\n'
          '    return-void\n'
          '.end method\n';
      final dex = _RecordingDexEditor()
        ..onExecute = (action, __) => DexResult(
              success: true,
              data: action == 'getClassSmaliFromSession'
                  ? const {'smaliContent': classSmali}
                  : const {
                      'methodCode': '.method public bar(I)V\n.end method\n',
                    },
            );
      final result = await runDexEditorTool(
        'dex_read_method',
        {
          'sessionId': 'S-1',
          'className': 'com.example.Foo',
          'methodName': 'bar',
          'methodSignature': '(I)V',
        },
        editor: dex,
      );
      expect(dex.actions, contains('getMethodFromSession'));
      final json = _json(result);
      expect(json['className'], 'com.example.Foo');
      expect(json['methodName'], 'bar');
      // 干净版：只保留单一 locator（方法级），不再有 classLocator。
      expect(json.containsKey('classLocator'), isFalse);
      expect(json['locator'], 'dex_method:Lcom/example/Foo;->bar(I)V');
      expect((json['targetVersion'] as String).startsWith('dex-v1:'), isTrue);
      expect(json['smali'], contains('.method public bar(I)V'));
      // 绝对行号：.method 在类 smali 第 3 行，.end method 第 5 行。
      expect(json['absoluteStartLine'], 3);
      expect(json['absoluteEndLine'], 5);
    });

    test('dex_read_method recovers method locator from smali when no signature',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(
              success: true,
              data: {
                'methodCode':
                    '.method public a()Ljava/lang/StackTraceElement;\n.end method\n',
              },
            );
      final result = await runDexEditorTool(
        'dex_read_method',
        {'sessionId': 'S-1', 'className': 'a.a', 'methodName': 'a'},
        editor: dex,
      );
      final json = _json(result);
      // 未传签名时应从 smali 还原出方法级 locator，而非退回类 locator。
      expect(json['methodSignature'], '()Ljava/lang/StackTraceElement;');
      expect(json['locator'], 'dex_method:La/a;->a()Ljava/lang/StackTraceElement;');
    });

    test('dex_read_method accepts a dex_method locator in place of args',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(
              success: true,
              data: {'methodCode': '.method public bar(I)V\n.end method\n'},
            );
      await runDexEditorTool(
        'dex_read_method',
        {
          'sessionId': 'S-1',
          'locator': 'dex_method:Lcom/example/Foo;->bar(I)V',
        },
        editor: dex,
      );
      expect(dex.actions, contains('getMethodFromSession'));
      final mp = dex.paramsFor('getMethodFromSession')!;
      expect(mp['className'], 'com.example.Foo');
      expect(mp['methodName'], 'bar');
      expect(mp['methodSignature'], '(I)V');
    });

    test('dex_outline_class decorates class + members with locators', () async {
      // 方法体带 const-string / invoke / 资源 ID const，验证逐方法分析字段。
      const classSmali = '.class public final Lcom/example/Foo;\n'
          '.super Ljava/lang/Object;\n'
          '.method public bar(I)V\n'
          '    const-string v0, "https://example.com/x"\n'
          '    const-string v1, "plain text here"\n'
          '    const v2, 0x7f0a0001\n'
          '    invoke-virtual {v0}, Ljava/lang/String;->length()I\n'
          '    return-void\n'
          '.end method\n';
      final dex = _RecordingDexEditor()
        ..onExecute = (action, __) => DexResult(
              success: true,
              data: action == 'getClassSmaliFromSession'
                  ? const {'smaliContent': classSmali}
                  : const {
                      'className': 'Lcom/example/Foo;',
                      'accessFlags': 0x11,
                      'superclass': 'Ljava/lang/Object;',
                      'interfaces': ['Ljava/lang/Runnable;'],
                      'fields': [
                        {'name': 'flag', 'type': 'Z', 'accessFlags': 0x42},
                      ],
                      'methods': [
                        {
                          'name': 'bar',
                          'signature': '(I)V',
                          'accessFlags': 0x101,
                        },
                      ],
                    },
            );
      final result = await runDexEditorTool(
        'dex_outline_class',
        {'sessionId': 'S-1', 'className': 'Lcom/example/Foo;'},
        editor: dex,
      );
      expect(dex.actions, contains('outlineClassFromSession'));
      final json = _json(result);
      expect(json['className'], 'com.example.Foo');
      // 干净版：类结果只用单一 locator（dex_class:...），不再有 classLocator。
      expect(json['locator'], 'dex_class:com.example.Foo');
      expect(json.containsKey('classLocator'), isFalse);
      expect(json['superclass'], 'java.lang.Object');
      expect(json['interfaces'], ['java.lang.Runnable']);
      // accessFlags 数字被解成可读修饰符（class/method/field 位含义不同）。
      expect(json['accessFlagsText'], 'public final');
      // classHeader 聚合类头元信息。
      final header = json['classHeader'] as Map;
      expect(header['accessFlagsText'], 'public final');
      expect(header['superclass'], 'java.lang.Object');
      expect(header['interfaces'], ['java.lang.Runnable']);
      final fields = json['fields'] as List;
      expect((fields.first as Map)['locator'], 'dex_field:Lcom/example/Foo;->flag:Z');
      expect((fields.first as Map)['accessFlagsText'], 'private volatile');
      final methods = json['methods'] as List;
      final bar = methods.first as Map;
      expect(bar['locator'], 'dex_method:Lcom/example/Foo;->bar(I)V');
      expect(bar['accessFlagsText'], 'public native');
      // 逐方法分析字段。
      expect(bar['stringRefCount'], 2);
      expect(bar['resourceRefCount'], 1);
      expect(bar['invokeCount'], 1);
      expect(bar['interestingStrings'], ['https://example.com/x']);
      expect(bar['interestingInvokes'],
          ['Ljava/lang/String;->length()I']);
    });

    test('dex_list_classes normalizes a dotted packageFilter to slash form',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(
              success: true,
              data: {'classes': <Object?>[], 'total': 0, 'hasMore': false},
            );
      await runDexEditorTool(
        'dex_list_classes',
        {'sessionId': 'S-1', 'packageFilter': 'com.yuanshi.wanyu'},
        editor: dex,
      );
      expect(dex.lastAction, 'listClasses');
      // native 用子串匹配描述符（`Lcom/yuanshi/...;`），点分包名需转成 `/`。
      expect(dex.lastParams!['packageFilter'], 'com/yuanshi/wanyu');
    });

    test('dex_list_classes leaves an already-slash packageFilter untouched',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(
              success: true,
              data: {'classes': <Object?>[], 'total': 0, 'hasMore': false},
            );
      await runDexEditorTool(
        'dex_list_classes',
        {'sessionId': 'S-1', 'packageFilter': 'com/yuanshi/wanyu'},
        editor: dex,
      );
      expect(dex.lastParams!['packageFilter'], 'com/yuanshi/wanyu');
    });

    test('dex_list_classes passes native brief fields through + adds locator',
        () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(
              success: true,
              data: {
                'classes': <Object?>[
                  {
                    'className': 'Lcom/example/Child;',
                    'dexFile': 'classes.dex',
                    'superclass': 'Lcom/example/Base;',
                    'interfaces': ['Ljava/lang/Runnable;'],
                    'fieldsCount': 1,
                    'methodsCount': 2,
                  },
                ],
                'total': 1,
                'hasMore': false,
              },
            );
      final result = await runDexEditorTool(
        'dex_list_classes',
        {'sessionId': 'S-1'},
        editor: dex,
      );
      final json = _json(result);
      final classes = json['classes'] as List;
      final first = classes.first as Map;
      // className/superclass/interfaces 归一为点分，计数原样透传，并补 locator。
      expect(first['className'], 'com.example.Child');
      expect(first['locator'], 'dex_class:com.example.Child');
      expect(first['superclass'], 'com.example.Base');
      expect(first['interfaces'], ['java.lang.Runnable']);
      expect(first['fieldsCount'], 1);
      expect(first['methodsCount'], 2);
    });

    test('dex_open_apk surfaces the native APK summary fields', () async {
      final dex = _RecordingDexEditor()
        ..onExecute = (_, __) => const DexResult(
              success: true,
              data: {
                'apkPath': '/x.apk',
                'packageName': 'com.yuanshi.wenxiaobai',
                'versionName': '4.8.5',
                'versionCode': 485,
                'totalClasses': 58368,
                'totalMethods': 300000,
                'dexFiles': [
                  {'name': 'classes.dex', 'size': 100, 'classCount': 58368},
                ],
              },
            );
      final result = await runDexEditorTool(
        'dex_open_apk',
        {'apkPath': '/x.apk'},
        editor: dex,
      );
      expect(dex.lastAction, 'listDexFiles');
      final json = _json(result);
      expect(json['packageName'], 'com.yuanshi.wenxiaobai');
      expect(json['versionName'], '4.8.5');
      expect(json['versionCode'], 485);
      expect(json['totalClasses'], 58368);
      expect(json['totalMethods'], 300000);
      expect((json['dexFiles'] as List).length, 1);
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
