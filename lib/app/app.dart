import 'package:flutter/material.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme.dart';

/// Root application widget.
///
/// Assembles the theme and the initial route. Business logic never lives here;
/// the shell only wires together features (see `docs/PROJECT_STRUCTURE.md`).
class AetherlinkApp extends StatelessWidget {
  const AetherlinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aetherlink',
      theme: AppTheme.light,
      home: AppRouter.home,
    );
  }
}
