import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/features/settings/application/font_settings_controller.dart'
    as font;

part 'font_settings_access.g.dart';

/// App-level composition seam exposing the 代码字体 family to the `chat` feature.
///
/// The import-boundary rule (`test/architecture/import_boundaries_test.dart`)
/// forbids one feature from importing another feature's `application`, so chat's
/// markdown / code-block / diff renderers cannot read the 全局字体 providers
/// (which live in `settings/application`) directly. They watch this provider in
/// `app/` (the composition root, which may depend on any feature) instead.
///
/// The underlying controller provider is imported under the `font` prefix so its
/// `codeFontFamilyProvider` doesn't collide with the identically-named provider
/// generated for this seam — call sites keep using `codeFontFamilyProvider`
/// unchanged, only their import line moves to this file.
@Riverpod(keepAlive: true)
String? codeFontFamily(Ref ref) => ref.watch(font.codeFontFamilyProvider);
