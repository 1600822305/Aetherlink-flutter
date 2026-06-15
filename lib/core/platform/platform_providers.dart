import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/core/platform/clipboard_api.dart';
import 'package:aetherlink_flutter/core/platform/device_info_api.dart';
import 'package:aetherlink_flutter/core/platform/file_system_api.dart';
import 'package:aetherlink_flutter/core/platform/image_picker_api.dart';
import 'package:aetherlink_flutter/core/platform/impl/clipboard_impl.dart';
import 'package:aetherlink_flutter/core/platform/impl/device_info_impl.dart';
import 'package:aetherlink_flutter/core/platform/impl/file_system_impl.dart';
import 'package:aetherlink_flutter/core/platform/impl/image_picker_impl.dart';
import 'package:aetherlink_flutter/core/platform/impl/share_impl.dart';
import 'package:aetherlink_flutter/core/platform/share_api.dart';

part 'platform_providers.g.dart';

/// One provider per platform capability (ADR-0007: no aggregate facade).
/// Upper layers `ref.watch` only the capability they need; each is overridable
/// with a fake in tests. Implementations live in `impl/`; swap them here to
/// branch by platform without touching callers.

@riverpod
FileSystemApi fileSystemApi(Ref ref) => const PluginFileSystemApi();

@riverpod
ClipboardApi clipboardApi(Ref ref) => const FlutterClipboardApi();

@riverpod
ImagePickerApi imagePickerApi(Ref ref) => PluginImagePickerApi();

@riverpod
ShareApi shareApi(Ref ref) => const PluginShareApi();

@riverpod
DeviceInfoApi deviceInfoApi(Ref ref) => PluginDeviceInfoApi();
