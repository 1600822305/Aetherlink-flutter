import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aetherlink_flutter/core/platform/impl/clipboard_impl.dart';
import 'package:aetherlink_flutter/core/platform/impl/device_info_impl.dart';
import 'package:aetherlink_flutter/core/platform/impl/file_system_impl.dart';
import 'package:aetherlink_flutter/core/platform/impl/image_picker_impl.dart';
import 'package:aetherlink_flutter/core/platform/impl/share_impl.dart';
import 'package:aetherlink_flutter/core/platform/platform_providers.dart';

/// Each capability has its own provider wired to its plugin-backed impl — there
/// is no aggregate facade. Reading the providers is channel-free (the impl
/// constructors do not touch platform channels).
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('fileSystemApiProvider yields the plugin-backed impl', () {
    expect(container.read(fileSystemApiProvider), isA<PluginFileSystemApi>());
  });

  test('clipboardApiProvider yields the Flutter clipboard impl', () {
    expect(container.read(clipboardApiProvider), isA<FlutterClipboardApi>());
  });

  test('imagePickerApiProvider yields the plugin-backed impl', () {
    expect(container.read(imagePickerApiProvider), isA<PluginImagePickerApi>());
  });

  test('shareApiProvider yields the plugin-backed impl', () {
    expect(container.read(shareApiProvider), isA<PluginShareApi>());
  });

  test('deviceInfoApiProvider yields the plugin-backed impl', () {
    expect(container.read(deviceInfoApiProvider), isA<PluginDeviceInfoApi>());
  });
}
