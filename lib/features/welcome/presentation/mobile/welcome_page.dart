import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/welcome/application/onboarding_controller.dart';
import 'package:aetherlink_flutter/features/welcome/application/welcome_controller.dart';

/// The welcome page — the second concrete page after M4.0's About page, again
/// proving the theme → go_router → `Scaffold` pipeline end to end (this time
/// exercising gradient text and the onboarding seam).
///
/// It is a pure view: all text comes from [welcomeContentProvider]; the only
/// action delegates to [OnboardingController.markStarted] in the application
/// layer, then navigates. It holds no business logic and never touches `data`.
///
/// Every color is a theme token (ADR-0008): the title gradient uses
/// `primary → secondary`, surfaces/text use their role colors — no hard-coded
/// colors, because this page's job is to prove theme assembly on a real screen.
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(welcomeContentProvider);
    final theme = Theme.of(context);
    final radius = theme.extension<AppThemeExtension>()?.borderRadius ?? 8.0;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LogoBadge(radius: radius),
                const SizedBox(height: 32),
                _GradientTitle(text: content.title),
                const SizedBox(height: 16),
                Text(
                  content.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    ref
                        .read(onboardingControllerProvider.notifier)
                        .markStarted();
                    context.go(AppRouter.chatPath);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(content.startButtonLabel),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded logo tile: a `primary`-filled square with the app glyph, echoing the
/// original welcome page's branded badge. Colors are theme tokens only.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 80,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome,
        size: 40,
        color: theme.colorScheme.onPrimary,
      ),
    );
  }
}

/// Title rendered with a `primary → secondary` linear gradient via [ShaderMask]
/// (the Flutter equivalent of the original CSS `background-clip: text`). The
/// child color is a token too; `srcIn` replaces it with the gradient.
class _GradientTitle extends StatelessWidget {
  const _GradientTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
      ).createShader(bounds),
      child: Text(text, textAlign: TextAlign.center, style: style),
    );
  }
}
