import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/about_controller.dart';
import 'package:aetherlink_flutter/features/settings/domain/about_info.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_group.dart';

/// The About page ("关于我们"), a 1:1 reproduction of the original
/// `src/pages/Settings/AboutPage.tsx`: an info card (circular app icon + name +
/// description + version badge) followed by a links card (GitHub / 官方群组 /
/// 反馈 / 开发者工具).
///
/// It is a pure view: all display state comes from [aboutInfoProvider] in the
/// application layer; it holds no business logic and never touches `data`. The
/// external links open in the system browser; "开发者工具" targets an in-app
/// page that does not exist yet, so that row renders disabled. All colors are
/// theme tokens (ADR-0008); icons are lucide (ADR-0009).
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  static const String _appIconAsset = 'assets/images/app-icon.png';
  static const String _githubIconAsset = 'assets/icons/lucide_github.svg';
  static const double _appIconSize = 70;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final info = ref.watch(aboutInfoProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          color: theme.colorScheme.primary,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRouter.settingsPath),
        ),
        // Match the original HeaderBar title: 1.125rem (18px) at weight 600,
        // left-aligned tight against the back button (SettingComponents.tsx).
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('关于我们'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingCard(child: _AboutHeader(info: info)),
          const SizedBox(height: 24),
          _SettingCard(child: _LinksList(links: info.links)),
        ],
      ),
    );
  }
}

/// The bordered surface card shared by the About page's two sections — same
/// shape as the settings hub's group card.
class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kSettingGroupRadius),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kSettingGroupRadius),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.info});

  final AboutInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.asset(
              AboutPage._appIconAsset,
              width: AboutPage._appIconSize,
              height: AboutPage._appIconSize,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.appName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _VersionBadge(version: info.version),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The green "v0.6.5" pill. Uses the theme's emerald [ColorScheme.secondary] as
/// the success accent (the original used MUI's `success` palette) — no
/// hard-coded color.
class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        'v$version',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: accent),
      ),
    );
  }
}

class _LinksList extends StatelessWidget {
  const _LinksList({required this.links});

  final List<AboutLink> links;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < links.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, thickness: 1));
      }
      rows.add(_AboutLinkRow(link: links[i]));
    }
    return Column(children: rows);
  }
}

class _AboutLinkRow extends StatelessWidget {
  const _AboutLinkRow({required this.link});

  final AboutLink link;

  static const double _iconSize = 20;
  static const double _arrowSize = 16;

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = link.url;
    final enabled = url != null;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _LinkLeadingIcon(
            kind: link.kind,
            size: _iconSize,
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(link.title, style: theme.textTheme.bodyLarge)),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.arrowUpRight,
            size: _arrowSize,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );

    if (!enabled) {
      return Opacity(opacity: 0.5, child: row);
    }
    return InkWell(onTap: () => _open(url), child: row);
  }
}

/// Maps an [AboutLinkKind] to its lucide leading icon. GitHub is rendered from
/// the official lucide `github.svg` (this lucide port dropped the brand icons),
/// the rest are native `LucideIcons.*`.
class _LinkLeadingIcon extends StatelessWidget {
  const _LinkLeadingIcon({
    required this.kind,
    required this.size,
    required this.color,
  });

  final AboutLinkKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (kind == AboutLinkKind.github) {
      return SvgPicture.asset(
        AboutPage._githubIconAsset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    final icon = switch (kind) {
      AboutLinkKind.qqGroup => LucideIcons.messageCircle,
      AboutLinkKind.feedback => LucideIcons.messageSquare,
      AboutLinkKind.devTools => LucideIcons.terminal,
      AboutLinkKind.github => LucideIcons.arrowUpRight, // unreachable
    };
    return Icon(icon, size: size, color: color);
  }
}
