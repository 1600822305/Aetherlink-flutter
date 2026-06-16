/// The user-selectable app theme mode (the original `settings.theme`:
/// `'light' | 'dark' | 'system'`).
///
/// Pure Dart so it satisfies the `domain` import-boundary rule; the app shell
/// maps it to Flutter's `ThemeMode` when driving `MaterialApp`.
enum AppThemeMode { system, light, dark }
