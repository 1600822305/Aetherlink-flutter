import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:aetherlink_flutter/app/di/app_settings_access.dart';

part 'font_size_controller.g.dart';

const String kFontSizeSettingKey = 'fontSize';

/// Holds the global base font size in px (the original `settings.fontSize`),
/// so the appearance page stays a pure view.
///
/// The app shell maps this to a text-scale factor of [defaultSize] (`size / 16`)
/// applied to the active theme, so every text style scales proportionally —
/// matching the original theme's `fontScale = fontSize / 16` (`themes.ts`).
///
/// Seeds [defaultSize] (16px = "标准"), the original default. Hydrated from the
/// Drift key/value store on first build and written through on every change,
/// so the size survives a full restart.
///
/// `keepAlive: true`: an app-level preference that must survive the appearance
/// page being disposed when navigating away, so it is not auto-disposed.
@Riverpod(keepAlive: true)
class FontSizeController extends _$FontSizeController {
  /// The original slider bounds (`min={12} max={24}`) and default
  /// (`defaults.ts` seeds `fontSize: 16`).
  static const int minSize = 12;
  static const int maxSize = 24;
  static const int defaultSize = 16;

  @override
  int build() {
    _hydrate();
    return defaultSize;
  }

  Future<void> _hydrate() async {
    final stored = await ref
        .read(appSettingsStoreProvider)
        .getSetting(kFontSizeSettingKey);
    if (stored == null || stored.isEmpty) return;
    final parsed = int.tryParse(stored);
    if (parsed == null) return;
    state = parsed < minSize
        ? minSize
        : parsed > maxSize
            ? maxSize
            : parsed;
  }

  /// Sets the global font size; the appearance page's 全局字体大小 slider calls
  /// this. The value is clamped to [minSize]..[maxSize].
  void use(int size) {
    final clamped = size < minSize
        ? minSize
        : size > maxSize
            ? maxSize
            : size;
    state = clamped;
    ref.read(appSettingsStoreProvider).saveSetting(
          kFontSizeSettingKey,
          clamped.toString(),
        );
  }
}
