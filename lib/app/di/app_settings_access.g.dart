// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam for the key/value settings store (the port of the
/// web `dexieStorage.getSetting` / `saveSetting`).
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's
/// `application` / `data`; only its `domain` is allowed. The single Drift-backed
/// KV store is reached through [ChatRepository] (chat's `application`), so any
/// non-chat feature that needs to persist a preference composes it here in
/// `app/` (the composition root, which may depend on any feature). Consumers
/// import this file plus chat's pure-Dart `domain` [ChatRepository] type — never
/// `chat/application` directly.
///
/// Delegates to chat's own repository provider, so there is a single repository
/// instance (and a single Drift handle) behind every read/write.

@ProviderFor(appSettingsStore)
final appSettingsStoreProvider = AppSettingsStoreProvider._();

/// App-level composition seam for the key/value settings store (the port of the
/// web `dexieStorage.getSetting` / `saveSetting`).
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's
/// `application` / `data`; only its `domain` is allowed. The single Drift-backed
/// KV store is reached through [ChatRepository] (chat's `application`), so any
/// non-chat feature that needs to persist a preference composes it here in
/// `app/` (the composition root, which may depend on any feature). Consumers
/// import this file plus chat's pure-Dart `domain` [ChatRepository] type — never
/// `chat/application` directly.
///
/// Delegates to chat's own repository provider, so there is a single repository
/// instance (and a single Drift handle) behind every read/write.

final class AppSettingsStoreProvider
    extends $FunctionalProvider<ChatRepository, ChatRepository, ChatRepository>
    with $Provider<ChatRepository> {
  /// App-level composition seam for the key/value settings store (the port of the
  /// web `dexieStorage.getSetting` / `saveSetting`).
  ///
  /// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
  /// Rule 3) forbids one feature from importing another feature's
  /// `application` / `data`; only its `domain` is allowed. The single Drift-backed
  /// KV store is reached through [ChatRepository] (chat's `application`), so any
  /// non-chat feature that needs to persist a preference composes it here in
  /// `app/` (the composition root, which may depend on any feature). Consumers
  /// import this file plus chat's pure-Dart `domain` [ChatRepository] type — never
  /// `chat/application` directly.
  ///
  /// Delegates to chat's own repository provider, so there is a single repository
  /// instance (and a single Drift handle) behind every read/write.
  AppSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<ChatRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ChatRepository create(Ref ref) {
    return appSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRepository>(value),
    );
  }
}

String _$appSettingsStoreHash() => r'45b9634b417d1ee947bf1ce80eedf1dd1f0310c6';
