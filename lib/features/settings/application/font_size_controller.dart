import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'font_size_controller.g.dart';

/// Holds the global base font size in px (the original `settings.fontSize`),
/// so the appearance page stays a pure view.
///
/// The app shell maps this to a text-scale factor of [defaultSize] (`size / 16`)
/// applied to the active theme, so every text style scales proportionally —
/// matching the original theme's `fontScale = fontSize / 16` (`themes.ts`).
///
/// Seeds [defaultSize] (16px = "标准"), the original default. Like
/// [ThemeModeController], it lives in memory only for now: the original
/// persisted `settings.fontSize`, but where app preferences live
/// (shared_preferences vs a Drift settings table) is a separate decision, so
/// the size resets to the default on each cold start until persistence is
/// wired.
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
  int build() => defaultSize;

  /// Sets the global font size; the appearance page's 全局字体大小 slider calls
  /// this. The value is clamped to [minSize]..[maxSize].
  void use(int size) {
    state = size < minSize
        ? minSize
        : size > maxSize
        ? maxSize
        : size;
  }
}
