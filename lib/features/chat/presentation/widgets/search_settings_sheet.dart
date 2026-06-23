import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/input_modes_controller.dart';
import 'package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/web_search/search_provider_catalog.dart';

/// 网络搜索设置底部弹窗 — 参考 Kelivo 的三层结构：
///   1. 搜索总开关
///   2. 搜索提供商选择
///   3. 通用设置（结果数量等）
///
/// 从输入框搜索按钮打开，替代原来的简单 toggle。
Future<void> showSearchSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _SearchSettingsSheet(),
  );
}

class _SearchSettingsSheet extends ConsumerWidget {
  const _SearchSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mode = ref.watch(inputModeControllerProvider);
    final enabled = mode == InputMode.webSearch;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Text(
                    '网络搜索',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    icon: Icon(
                      LucideIcons.settings,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(AppRouter.webSearchPath);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- 搜索总开关 ---
            _ToggleCard(
              icon: LucideIcons.globe,
              iconColor: cs.primary,
              label: '启用网络搜索',
              subtitle: 'AI 将根据对话内容自主决定是否搜索',
              value: enabled,
              onChanged: (v) {
                ref
                    .read(inputModeControllerProvider.notifier)
                    .toggle(InputMode.webSearch);
              },
            ),

            // --- 搜索提供商 ---
            if (enabled) ...[
              const SizedBox(height: 8),
              const _SectionHeader(label: '搜索提供商'),
              const SizedBox(height: 4),
              const _ProviderList(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header label, styled like a form group title.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// Toggle card with icon, label, optional subtitle, and a switch.
class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: value ? cs.primary.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? cs.primary.withValues(alpha: 0.3)
              : cs.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lists every provider the user has added and lets them pick the active one
/// with a single tap — no need to dive into the settings pages. The active
/// provider is highlighted; tapping another switches to it (and enables it if
/// it was turned off, so the choice always takes effect). When the list is
/// empty, a prompt navigates to the full settings page to add one.
class _ProviderList extends ConsumerWidget {
  const _ProviderList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(webSearchSettingsControllerProvider);
    final providers = ws.providers;

    if (providers.isEmpty) return const _AddProviderPrompt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final config in providers) ...[
          _ProviderTile(
            config: config,
            selected: config.id == ws.activeProviderId,
            onTap: () {
              final notifier =
                  ref.read(webSearchSettingsControllerProvider.notifier);
              if (!config.isEnabled) {
                notifier.updateProvider(config.copyWith(isEnabled: true));
              }
              notifier.setActiveProvider(config.id);
            },
          ),
          const SizedBox(height: 8),
        ],
        const _ManageProvidersRow(),
      ],
    );
  }
}

/// A single selectable provider row: brand icon, name, description, and a
/// radio-style indicator that fills in when it is the active provider.
class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.config,
    required this.selected,
    required this.onTap,
  });

  final SearchProviderConfig config;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preset = presetForId(config.id);
    final name = config.name.isNotEmpty
        ? config.name
        : (preset?.name ?? config.id);
    final description = preset?.description ?? '';

    return Container(
      decoration: BoxDecoration(
        color: selected ? cs.primary.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? cs.primary.withValues(alpha: 0.4)
              : cs.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SearchProviderIcon(preset: preset, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? cs.primary : cs.onSurface,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 20,
                color: selected
                    ? cs.primary
                    : cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A subtle row that opens the full search settings page to add / configure
/// providers (host, API key, etc.).
class _ManageProvidersRow extends StatelessWidget {
  const _ManageProvidersRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pop();
        context.push(AppRouter.webSearchPath);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Icon(LucideIcons.settings2, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              '管理搜索提供商',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const Spacer(),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when no provider has been added yet — taps through to the settings
/// page where the user can pick one from the preset catalogue.
class _AddProviderPrompt extends StatelessWidget {
  const _AddProviderPrompt();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).pop();
        context.push(AppRouter.webSearchPath);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(LucideIcons.plus, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '添加搜索提供商',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '尚未添加任何搜索提供商，点击前往添加',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
