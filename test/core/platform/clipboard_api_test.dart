import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/platform/impl/clipboard_impl.dart';

/// Headless smoke test: exercises the real impl against a mocked platform
/// channel that stands in for the system clipboard. No real device involved.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const clipboard = FlutterClipboardApi();
  String? stored;

  setUp(() {
    stored = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              stored = (call.arguments as Map)['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return stored == null ? null : <String, dynamic>{'text': stored};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('copies text then reads the same text back', () async {
    await clipboard.copyText('hello world');

    expect(stored, 'hello world');
    expect(await clipboard.readText(), 'hello world');
  });

  test('readText returns null when the clipboard is empty', () async {
    expect(await clipboard.readText(), isNull);
  });
}
