// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'platform_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One provider per platform capability (ADR-0007: no aggregate facade).
/// Upper layers `ref.watch` only the capability they need; each is overridable
/// with a fake in tests. Implementations live in `impl/`; swap them here to
/// branch by platform without touching callers.

@ProviderFor(fileSystemApi)
final fileSystemApiProvider = FileSystemApiProvider._();

/// One provider per platform capability (ADR-0007: no aggregate facade).
/// Upper layers `ref.watch` only the capability they need; each is overridable
/// with a fake in tests. Implementations live in `impl/`; swap them here to
/// branch by platform without touching callers.

final class FileSystemApiProvider
    extends $FunctionalProvider<FileSystemApi, FileSystemApi, FileSystemApi>
    with $Provider<FileSystemApi> {
  /// One provider per platform capability (ADR-0007: no aggregate facade).
  /// Upper layers `ref.watch` only the capability they need; each is overridable
  /// with a fake in tests. Implementations live in `impl/`; swap them here to
  /// branch by platform without touching callers.
  FileSystemApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fileSystemApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fileSystemApiHash();

  @$internal
  @override
  $ProviderElement<FileSystemApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FileSystemApi create(Ref ref) {
    return fileSystemApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FileSystemApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FileSystemApi>(value),
    );
  }
}

String _$fileSystemApiHash() => r'5d21822036667acc018c62f8a025184e1cf9f8ee';

@ProviderFor(clipboardApi)
final clipboardApiProvider = ClipboardApiProvider._();

final class ClipboardApiProvider
    extends $FunctionalProvider<ClipboardApi, ClipboardApi, ClipboardApi>
    with $Provider<ClipboardApi> {
  ClipboardApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipboardApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipboardApiHash();

  @$internal
  @override
  $ProviderElement<ClipboardApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClipboardApi create(Ref ref) {
    return clipboardApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClipboardApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClipboardApi>(value),
    );
  }
}

String _$clipboardApiHash() => r'e427c47af022713305b4bc60580854ca681059b4';

@ProviderFor(imagePickerApi)
final imagePickerApiProvider = ImagePickerApiProvider._();

final class ImagePickerApiProvider
    extends $FunctionalProvider<ImagePickerApi, ImagePickerApi, ImagePickerApi>
    with $Provider<ImagePickerApi> {
  ImagePickerApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imagePickerApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imagePickerApiHash();

  @$internal
  @override
  $ProviderElement<ImagePickerApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ImagePickerApi create(Ref ref) {
    return imagePickerApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImagePickerApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImagePickerApi>(value),
    );
  }
}

String _$imagePickerApiHash() => r'07c710fb6422e52f8c04c9ec0e906a345080403b';

@ProviderFor(shareApi)
final shareApiProvider = ShareApiProvider._();

final class ShareApiProvider
    extends $FunctionalProvider<ShareApi, ShareApi, ShareApi>
    with $Provider<ShareApi> {
  ShareApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareApiHash();

  @$internal
  @override
  $ProviderElement<ShareApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShareApi create(Ref ref) {
    return shareApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShareApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShareApi>(value),
    );
  }
}

String _$shareApiHash() => r'7a5e95ae793d5ec0225983eabde9c36c7bb3e685';

@ProviderFor(deviceInfoApi)
final deviceInfoApiProvider = DeviceInfoApiProvider._();

final class DeviceInfoApiProvider
    extends $FunctionalProvider<DeviceInfoApi, DeviceInfoApi, DeviceInfoApi>
    with $Provider<DeviceInfoApi> {
  DeviceInfoApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deviceInfoApiProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deviceInfoApiHash();

  @$internal
  @override
  $ProviderElement<DeviceInfoApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DeviceInfoApi create(Ref ref) {
    return deviceInfoApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeviceInfoApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeviceInfoApi>(value),
    );
  }
}

String _$deviceInfoApiHash() => r'278b3414e150ad630dfd9ab4b8fb952f140ee97c';
