import 'package:dex_editor/dex_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.aetherlink.dexeditor/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('execute forwards action/params and decodes the result envelope',
      () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return <Object?, Object?>{
        'success': true,
        'data': {'classes': 3},
      };
    });

    final result = await DexEditor.instance.execute('listClasses', {
      'sessionId': 's1',
      'offset': 0,
    });

    expect(captured?.method, 'execute');
    expect((captured?.arguments as Map)['action'], 'listClasses');
    expect(((captured?.arguments as Map)['params'] as Map)['sessionId'], 's1');
    expect(result.success, isTrue);
    expect((result.data as Map)['classes'], 3);
  });

  test('execute surfaces native business errors without throwing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <Object?, Object?>{'success': false, 'error': 'boom'};
    });

    final result = await DexEditor.instance.execute('loadDex');
    expect(result.success, isFalse);
    expect(result.error, 'boom');
  });

  test('DexProgressEvent parses native progress payloads', () {
    final event = DexProgressEvent.fromMap(const {
      'type': 'progress',
      'current': 5,
      'total': 10,
      'percent': 50,
    });
    expect(event.type, DexProgressType.progress);
    expect(event.percent, 50);
  });
}
