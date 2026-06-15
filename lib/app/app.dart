import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';
import 'package:aetherlink_flutter/features/theming/application/theme_controller.dart';

/// Root application widget (composition root).
///
/// It only wires features together (no business logic): it watches the active
/// [ThemeController] and feeds the resulting `ThemeData` into the go_router-driven
/// `MaterialApp`. Swapping the theme at runtime rebuilds the app's appearance
/// without recreating the router.
class AetherlinkApp extends ConsumerStatefulWidget {
  const AetherlinkApp({super.key});

  @override
  ConsumerState<AetherlinkApp> createState() => _AetherlinkAppState();
}

class _AetherlinkAppState extends ConsumerState<AetherlinkApp> {
  /// Created once for the app's lifetime so theme rebuilds never recreate it
  /// (which would reset navigation state).
  final GoRouter _router = AppRouter.create();

  @override
  Widget build(BuildContext context) {
    final spec = ref.watch(themeControllerProvider);
    return MaterialApp.router(
      title: 'Aetherlink',
      theme: AppTheme.light(spec),
      darkTheme: AppTheme.dark(spec),
      routerConfig: _router,
    );
  }
}
