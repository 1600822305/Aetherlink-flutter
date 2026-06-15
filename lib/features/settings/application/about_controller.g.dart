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
/// Values are ported verbatim from the original `AboutPage.tsx` /
/// `settings.about` zh-CN strings. The version is static for now; it can later
/// be sourced from `package_info_plus` without touching the view — only this
/// provider changes.
///
/// The "开发者工具" row points at the original's in-app `/devtools` page, which
/// does not exist in the Flutter app yet, so its [AboutLink.url] is `null` and
/// the row renders disabled (the settings hub's convention for unimplemented
/// destinations — no fake page).

@ProviderFor(aboutInfo)
final aboutInfoProvider = AboutInfoProvider._();

/// Supplies the About page with its display state from the application layer
/// (the page stays a pure view — no business logic, ADR/PROJECT_STRUCTURE).
///
/// Values are ported verbatim from the original `AboutPage.tsx` /
/// `settings.about` zh-CN strings. The version is static for now; it can later
/// be sourced from `package_info_plus` without touching the view — only this
/// provider changes.
///
/// The "开发者工具" row points at the original's in-app `/devtools` page, which
/// does not exist in the Flutter app yet, so its [AboutLink.url] is `null` and
/// the row renders disabled (the settings hub's convention for unimplemented
/// destinations — no fake page).

final class AboutInfoProvider
    extends $FunctionalProvider<AboutInfo, AboutInfo, AboutInfo>
    with $Provider<AboutInfo> {
  /// Supplies the About page with its display state from the application layer
  /// (the page stays a pure view — no business logic, ADR/PROJECT_STRUCTURE).
  ///
  /// Values are ported verbatim from the original `AboutPage.tsx` /
  /// `settings.about` zh-CN strings. The version is static for now; it can later
  /// be sourced from `package_info_plus` without touching the view — only this
  /// provider changes.
  ///
  /// The "开发者工具" row points at the original's in-app `/devtools` page, which
  /// does not exist in the Flutter app yet, so its [AboutLink.url] is `null` and
  /// the row renders disabled (the settings hub's convention for unimplemented
  /// destinations — no fake page).
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

String _$aboutInfoHash() => r'6b92cb98d87de8b88e73b126b3a2c841d85a995c';
