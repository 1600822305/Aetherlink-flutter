// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'welcome_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Supplies the welcome page with its display text from the application layer
/// (the page stays a pure view — no business logic, see PROJECT_STRUCTURE).
///
/// Strings are static for M4.1, lifted verbatim from the original `welcome.*`
/// i18n namespace. A real i18n system is a separate later effort and is
/// intentionally not built here; when it lands only this provider changes, not
/// the view.

@ProviderFor(welcomeContent)
final welcomeContentProvider = WelcomeContentProvider._();

/// Supplies the welcome page with its display text from the application layer
/// (the page stays a pure view — no business logic, see PROJECT_STRUCTURE).
///
/// Strings are static for M4.1, lifted verbatim from the original `welcome.*`
/// i18n namespace. A real i18n system is a separate later effort and is
/// intentionally not built here; when it lands only this provider changes, not
/// the view.

final class WelcomeContentProvider
    extends $FunctionalProvider<WelcomeContent, WelcomeContent, WelcomeContent>
    with $Provider<WelcomeContent> {
  /// Supplies the welcome page with its display text from the application layer
  /// (the page stays a pure view — no business logic, see PROJECT_STRUCTURE).
  ///
  /// Strings are static for M4.1, lifted verbatim from the original `welcome.*`
  /// i18n namespace. A real i18n system is a separate later effort and is
  /// intentionally not built here; when it lands only this provider changes, not
  /// the view.
  WelcomeContentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'welcomeContentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$welcomeContentHash();

  @$internal
  @override
  $ProviderElement<WelcomeContent> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WelcomeContent create(Ref ref) {
    return welcomeContent(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WelcomeContent value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WelcomeContent>(value),
    );
  }
}

String _$welcomeContentHash() => r'267453961d391f3c6df8c1acf5f630a9f32d2ad9';
