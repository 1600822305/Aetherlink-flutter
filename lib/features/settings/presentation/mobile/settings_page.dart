import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/settings/application/settings_view_mode_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/settings_catalog.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_group.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_item.dart';

/// The settings hub — the top-level grouped list of settings entries, a 1:1
/// reproduction of the original `src/pages/Settings/index.tsx`.
///
/// It is a pure view: the compact/detailed mode comes from
/// [settingsViewModeControllerProvider] in the application layer; the grouped
/// rows come from the static [kSettingsGroups] navigation catalog. It holds no
/// business logic and never touches `data`.
///
/// This milestone builds only the hub. Every row except "关于我们" is a
/// not-yet-implemented placeholder (rendered disabled); their sub-pages are
/// later milestones. "关于我们" pushes the existing [AboutPage] to prove the hub
/// navigates. Header shows the original's back button + 设置 title +
/// compact/detailed toggle. All colors are theme tokens (ADR-0008); icons are
/// lucide (ADR-0009).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const double _groupSpacing = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCompact = ref.watch(settingsViewModeControllerProvider);

    return Scaffold(
      // The original HeaderBar is light and flat: `background.paper` fill,
      // elevation 0, a 1px bottom divider and a left-aligned title — matching
      // the restored chat top bar rather than a default Material 2 AppBar.
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
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRouter.chatPath),
        ),
        // Match the original HeaderBar title: 1.125rem (18px) at weight 600,
        // left-aligned tight against the back button (SettingComponents.tsx).
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(kSettingsTitle),
        actions: [
          IconButton(
            icon: Icon(isCompact ? LucideIcons.list : LucideIcons.layoutGrid),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: isCompact
                ? kSettingsDetailedModeLabel
                : kSettingsCompactModeLabel,
            onPressed: () =>
                ref.read(settingsViewModeControllerProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final group in kSettingsGroups) ...[
            SettingGroup(
              title: group.title,
              children: [
                for (final item in group.items)
                  SettingItem(
                    icon: item.icon,
                    title: item.title,
                    description: isCompact ? null : item.description,
                    enabled: item.enabled,
                    onTap: item.route == null
                        ? null
                        : () => context.push(item.route!),
                  ),
              ],
            ),
            const SizedBox(height: _groupSpacing),
          ],
        ],
      ),
    );
  }
}
