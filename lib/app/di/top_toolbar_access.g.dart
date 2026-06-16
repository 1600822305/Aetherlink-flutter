// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'top_toolbar_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam for cross-feature reads of the top-toolbar DIY
/// config.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The `settings` feature owns
/// [TopToolbarSettingsController], but `chat`'s top bar must follow the same
/// layout the appearance 顶部工具栏 DIY 设置 page edits, so the read provider is
/// re-exposed here in `app/` (the composition root, which may depend on any
/// feature). The chat layer watches this plus the pure-Dart [TopToolbarSettings]
/// domain type — never `settings/application` directly.

@ProviderFor(appTopToolbarSettings)
final appTopToolbarSettingsProvider = AppTopToolbarSettingsProvider._();

/// App-level composition seam for cross-feature reads of the top-toolbar DIY
/// config.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The `settings` feature owns
/// [TopToolbarSettingsController], but `chat`'s top bar must follow the same
/// layout the appearance 顶部工具栏 DIY 设置 page edits, so the read provider is
/// re-exposed here in `app/` (the composition root, which may depend on any
/// feature). The chat layer watches this plus the pure-Dart [TopToolbarSettings]
/// domain type — never `settings/application` directly.

final class AppTopToolbarSettingsProvider
    extends
        $FunctionalProvider<
          TopToolbarSettings,
          TopToolbarSettings,
          TopToolbarSettings
        >
    with $Provider<TopToolbarSettings> {
  /// App-level composition seam for cross-feature reads of the top-toolbar DIY
  /// config.
  ///
  /// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
  /// Rule 3) forbids one feature from importing another feature's `application`;
  /// only its `domain` is allowed. The `settings` feature owns
  /// [TopToolbarSettingsController], but `chat`'s top bar must follow the same
  /// layout the appearance 顶部工具栏 DIY 设置 page edits, so the read provider is
  /// re-exposed here in `app/` (the composition root, which may depend on any
  /// feature). The chat layer watches this plus the pure-Dart [TopToolbarSettings]
  /// domain type — never `settings/application` directly.
  AppTopToolbarSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appTopToolbarSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appTopToolbarSettingsHash();

  @$internal
  @override
  $ProviderElement<TopToolbarSettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TopToolbarSettings create(Ref ref) {
    return appTopToolbarSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TopToolbarSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TopToolbarSettings>(value),
    );
  }
}

String _$appTopToolbarSettingsHash() =>
    r'45a1abe72c2cb9352608fdd5f1ccfdb688f91000';
