import 'package:flutter_test/flutter_test.dart';
import 'package:aetherlink_saf/aetherlink_saf.dart';
import 'package:aetherlink_saf/aetherlink_saf_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeAetherlinkSafPlatform extends AetherlinkSafPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<EchoResult> echo({required String value}) async {
    return EchoResult(value: 'echo:$value');
  }
}

void main() {
  final initial = AetherlinkSafPlatform.instance;

  test('default platform is the method-channel implementation', () {
    expect(initial, isA<MethodChannelAetherlinkSaf>());
  });

  test('echo forwards through the platform interface', () async {
    AetherlinkSafPlatform.instance = _FakeAetherlinkSafPlatform();
    const plugin = AetherlinkSaf();

    final result = await plugin.echo(value: 'hi');

    expect(result.value, 'echo:hi');
  });
}
