import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'package:aetherlink_flutter/core/platform/impl/share_impl.dart';

/// A fake `share_plus` platform that captures the [ShareParams] it receives, so
/// the real impl's request-building can be asserted without an OS share sheet.
class _FakeSharePlatform extends SharePlatform {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  // `SharePlus.instance` caches `SharePlatform.instance` on first access, so the
  // fake must be installed once before any share call and reset per test.
  final fake = _FakeSharePlatform();

  setUpAll(() {
    SharePlatform.instance = fake;
  });

  setUp(() {
    fake.lastParams = null;
  });

  test('shareText forwards text and subject', () async {
    const share = PluginShareApi();

    await share.shareText('exported chat', subject: 'My Topic');

    expect(fake.lastParams?.text, 'exported chat');
    expect(fake.lastParams?.subject, 'My Topic');
  });

  test('shareFiles forwards files as XFiles addressed by path', () async {
    const share = PluginShareApi();

    await share.shareFiles(['/tmp/a.txt', '/tmp/b.png'], text: 'see attached');

    final files = fake.lastParams?.files;
    expect(files, hasLength(2));
    expect(files!.map((f) => f.path), ['/tmp/a.txt', '/tmp/b.png']);
    expect(fake.lastParams?.text, 'see attached');
  });
}
