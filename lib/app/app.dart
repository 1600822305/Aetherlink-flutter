import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/settings/application/font_size_controller.dart';
import 'package:aetherlink_flutter/features/settings/application/theme_mode_controller.dart';
import 'package:aetherlink_flutter/features/settings/domain/app_theme_mode.dart';
import 'package:aetherlink_flutter/features/theming/application/theme_controller.dart';
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
  /// Created once for the app's lifetime so theme rebuilds never recreate it
  /// (which would reset navigation state). First-time users land on the welcome
  /// page; the decision is read once here from the in-memory onboarding seam.
  late final GoRouter _router = AppRouter.create(
    startAtWelcome: ref.read(onboardingControllerProvider),
  );

  @override
  Widget build(BuildContext context) {
    final spec = ref.watch(themeControllerProvider);
    final mode = ref.watch(themeModeControllerProvider);
    final fontSize = ref.watch(fontSizeControllerProvider);
    // Mirror the original `fontScale = fontSize / 16`. Apply it as a uniform
    // text scale via `MediaQuery.textScaler` rather than the theme's
    // `fontSizeFactor`: the base text theme keeps some null `fontSize`s, and
    // `TextStyle.apply` asserts a non-1.0 factor is only used on a set size, so
    // scaling through the theme would crash off the default size.
    final textScale = fontSize / FontSizeController.defaultSize;
    return MaterialApp.router(
      title: 'Aetherlink',
      theme: AppTheme.light(spec),
      darkTheme: AppTheme.dark(spec),
      themeMode: switch (mode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: _router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
