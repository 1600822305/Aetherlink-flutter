// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'about_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Supplies the About page with its display state from the application layer
/// (the page stays a pure view — no business logic, ADR/PROJECT_STRUCTURE).
///
/// Values are static for M4.0 (ported from the original `AboutPage.tsx`). The
/// version can later be sourced from `package_info_plus` without touching the
/// view — only this provider changes.

@ProviderFor(aboutInfo)
final aboutInfoProvider = AboutInfoProvider._();

/// Supplies the About page with its display state from the application layer
/// (the page stays a pure view — no business logic, ADR/PROJECT_STRUCTURE).
///
/// Values are static for M4.0 (ported from the original `AboutPage.tsx`). The
/// version can later be sourced from `package_info_plus` without touching the
/// view — only this provider changes.

final class AboutInfoProvider
    extends $FunctionalProvider<AboutInfo, AboutInfo, AboutInfo>
    with $Provider<AboutInfo> {
  /// Supplies the About page with its display state from the application layer
  /// (the page stays a pure view — no business logic, ADR/PROJECT_STRUCTURE).
  ///
  /// Values are static for M4.0 (ported from the original `AboutPage.tsx`). The
  /// version can later be sourced from `package_info_plus` without touching the
  /// view — only this provider changes.
  AboutInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aboutInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aboutInfoHash();

  @$internal
  @override
  $ProviderElement<AboutInfo> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AboutInfo create(Ref ref) {
    return aboutInfo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AboutInfo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AboutInfo>(value),
    );
  }
}

String _$aboutInfoHash() => r'98ee8d682d5165b338c5d120f41222b6d99760c1';
