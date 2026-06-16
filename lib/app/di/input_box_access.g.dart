// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'input_box_access.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-level composition seam for cross-feature reads of the input-box config.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The `settings` feature owns
/// [InputBoxSettingsController], but `chat`'s composer must follow the same
/// config, so the read provider is re-exposed here in `app/` (the composition
/// root, which may depend on any feature). The chat layer watches this plus the
/// pure-Dart [InputBoxSettings] domain type — never `settings/application`
/// directly.

@ProviderFor(appInputBoxSettings)
final appInputBoxSettingsProvider = AppInputBoxSettingsProvider._();

/// App-level composition seam for cross-feature reads of the input-box config.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
/// Rule 3) forbids one feature from importing another feature's `application`;
/// only its `domain` is allowed. The `settings` feature owns
/// [InputBoxSettingsController], but `chat`'s composer must follow the same
/// config, so the read provider is re-exposed here in `app/` (the composition
/// root, which may depend on any feature). The chat layer watches this plus the
/// pure-Dart [InputBoxSettings] domain type — never `settings/application`
/// directly.

final class AppInputBoxSettingsProvider
    extends
        $FunctionalProvider<
          InputBoxSettings,
          InputBoxSettings,
          InputBoxSettings
        >
    with $Provider<InputBoxSettings> {
  /// App-level composition seam for cross-feature reads of the input-box config.
  ///
  /// The import-boundary rule (`test/architecture/import_boundaries_test.dart`
  /// Rule 3) forbids one feature from importing another feature's `application`;
  /// only its `domain` is allowed. The `settings` feature owns
  /// [InputBoxSettingsController], but `chat`'s composer must follow the same
  /// config, so the read provider is re-exposed here in `app/` (the composition
  /// root, which may depend on any feature). The chat layer watches this plus the
  /// pure-Dart [InputBoxSettings] domain type — never `settings/application`
  /// directly.
  AppInputBoxSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appInputBoxSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appInputBoxSettingsHash();

  @$internal
  @override
  $ProviderElement<InputBoxSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InputBoxSettings create(Ref ref) {
    return appInputBoxSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InputBoxSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InputBoxSettings>(value),
    );
  }
}

String _$appInputBoxSettingsHash() =>
    r'a30c7c0764d446a55a04071ff3344ee4f36ca93e';
