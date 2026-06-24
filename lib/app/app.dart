import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/di/behavior_settings_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/shared/utils/haptics.dart';
import 'package:aetherlink_flutter/features/settings/application/font_size_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/theme_mode_controller.dart';
import 'package:aetherlink_flutter/features/settings/domain/app_theme_mode.dart';
import 'package:aetherlink_flutter/features/theming/application/theme_controller.dart';
import 'package:aetherlink_flutter/features/voice/application/tts_controller.dart';
import 'package:aetherlink_flutter/features/welcome/application/onboarding_controller.dart';

/// Root application widget (composition root).
///
/// It only wires features together (no business logic): it watches the active
/// [ThemeController] + [ThemeModeController] + [FontSizeController] and feeds
/// the resulting `ThemeData` and `ThemeMode` into the go_router-driven
/// `MaterialApp`. Swapping any of them at runtime rebuilds the app's appearance
/// without recreating the router.
class AetherlinkApp extends ConsumerStatefulWidget {
  const AetherlinkApp({super.key});

  @override
  ConsumerState<AetherlinkApp> createState() => _AetherlinkAppState();
}

class _AetherlinkAppState extends ConsumerState<AetherlinkApp> {
  /// Created once, the moment the persisted onboarding flag first resolves, so
  /// theme rebuilds (and the later `markStarted()` flip) never recreate it and
  /// reset navigation. First-time users land on the welcome page; the decision
  /// is read from the now-persisted `first-time-user` flag.
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    // Seed the global haptic service with the current config (defaults at
    // startup; the listener below pushes the hydrated value once Drift
    // resolves). Done here rather than in build so a toggle never rebuilds the
    // whole app.
    Haptics.instance.updateSettings(
      ref.read(appBehaviorSettingsProvider).hapticFeedback,
    );
    // Eagerly warm up the system TTS engine at app startup (matching kelivo's
    // ChangeNotifierProvider(create: (_) => TtsProvider()) in main.dart).
    // On MIUI devices binding takes several seconds; starting early ensures
    // the engine is ready by the time the user presses speak.
    ref.read(ttsControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the global haptic service in sync with the persisted config without
    // rebuilding the whole app on every toggle.
    ref.listen(appBehaviorSettingsProvider, (_, next) {
      Haptics.instance.updateSettings(next.hapticFeedback);
    });

    final spec = ref.watch(themeControllerProvider);
    final mode = ref.watch(themeModeControllerProvider);
    final fontSize = ref.watch(fontSizeControllerProvider);
    // Mirror the original `fontScale = fontSize / 16`. Apply it as a uniform
    // text scale via `MediaQuery.textScaler` rather than the theme's
    // `fontSizeFactor`: the base text theme keeps some null `fontSize`s, and
    // `TextStyle.apply` asserts a non-1.0 factor is only used on a set size, so
    // scaling through the theme would crash off the default size.
    final textScale = fontSize / FontSizeController.defaultSize;
    final lightTheme = AppTheme.light(spec);
    final darkTheme = AppTheme.dark(spec);
    final themeMode = switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    // Resolve the persisted first-time-user gate before building the router so
    // we land on the right page without flashing the welcome page (mirrors the
    // web's loading gate). On error, default to the chat home like the web did.
    final onboarding = ref.watch(onboardingControllerProvider);
    if (_router == null && (onboarding.hasValue || onboarding.hasError)) {
      _router = AppRouter.create(
        startAtWelcome: onboarding.value ?? false,
      );
    }
    final router = _router;
    if (router == null) {
      // First-frame splash while the flag resolves: a themed blank surface, no
      // spinner flash (the read settles within a frame on a real store).
      return MaterialApp(
        title: 'Aetherlink',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(),
      );
    }
    return MaterialApp.router(
      title: 'Aetherlink',
      theme: lightTheme,
      darkTheme: darkTheme,
      scrollBehavior: const ScrollBehavior().copyWith(overscroll: false),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        // Keep the system bars transparent with no contrast scrim, and flip the
        // icon brightness with the active theme so the status / navigation bar
        // glyphs stay legible. Mirrors kelivo's app-wide AnnotatedRegion.
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlay = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlay,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
