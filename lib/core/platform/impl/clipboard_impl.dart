import 'package:flutter/services.dart';

import 'package:aetherlink_flutter/core/platform/clipboard_api.dart';

/// [ClipboardApi] backed by Flutter's built-in `Clipboard` (no plugin). The
/// only place `flutter/services` clipboard access is imported.
class FlutterClipboardApi implements ClipboardApi {
  const FlutterClipboardApi();

  @override
  Future<void> copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  @override
  Future<String?> readText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
