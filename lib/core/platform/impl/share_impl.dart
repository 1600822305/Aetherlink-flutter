import 'package:share_plus/share_plus.dart';

import 'package:aetherlink_flutter/core/platform/share_api.dart';

/// [ShareApi] backed by `share_plus`. The only place the plugin is imported.
class PluginShareApi implements ShareApi {
  const PluginShareApi();

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  @override
  Future<void> shareFiles(
    List<String> paths, {
    String? text,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        files: paths.map(XFile.new).toList(),
      ),
    );
  }
}
