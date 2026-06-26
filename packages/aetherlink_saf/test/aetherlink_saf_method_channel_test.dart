import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aetherlink_saf/aetherlink_saf.dart';
import 'package:aetherlink_saf/aetherlink_saf_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelAetherlinkSaf();
  const channel = MethodChannel('aetherlink_saf');

  setUp(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'echo') {
        final args = (call.arguments as Map?)?.cast<Object?, Object?>() ?? {};
        return {'value': 'echo:${args['value']}'};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('echo round-trips the value', () async {
    final result = await platform.echo(value: 'hi');
    expect(result, isA<EchoResult>());
    expect(result.value, 'echo:hi');
  });
}
