import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aetherlink_flutter/app/theme/app_theme_extension.dart';
import 'package:aetherlink_flutter/features/settings/application/about_controller.dart';
import 'package:aetherlink_flutter/features/settings/domain/about_info.dart';

/// The About page — the first concrete page in M4.0. Its job is to prove the
/// theme → go_router → `Scaffold` pipeline end to end.
///
/// It is a pure view: all display state comes from [aboutInfoProvider] in the
/// application layer; it holds no business logic and never touches `data`.
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(aboutInfoProvider);
    final radius =
        Theme.of(context).extension<AppThemeExtension>()?.borderRadius ?? 8.0;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('关于'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(info: info, radius: radius),
          const SizedBox(height: 24),
          for (final link in info.links)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(link.label),
              trailing: const Icon(Icons.open_in_new, size: 16),
              subtitle: Text(link.url),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.info, required this.radius});

  final AboutInfo info;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(radius),
          ),
          alignment: Alignment.center,
          child: Text(
            info.appName.isEmpty ? '?' : info.appName[0],
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(info.appName, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(info.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Chip(label: Text('v${info.version}')),
            ],
          ),
        ),
      ],
    );
  }
}
