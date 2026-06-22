import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/chat/application/web_search_settings_controller.dart';
import 'package:aetherlink_flutter/features/chat/domain/entities/web_search_settings.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/web_search/search_provider_catalog.dart';

/// 网络搜索设置二级页面（设置 → 网络搜索）。
///
/// Shows only user-added providers (from [WebSearchSettings.providers]).
/// Each row navigates to the third-level detail page. The "添加搜索提供商"
/// button opens [AddSearchProviderPage] where the user picks from presets.
/// Below the provider list is a "通用选项" card for maxResults / timeout.
class WebSearchSettingsPage extends ConsumerWidget {
  const WebSearchSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ws = ref.watch(webSearchSettingsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.settingsPath),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('网络搜索'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _providersCard(context, ref, theme, ws),
          const SizedBox(height: 16),
          _commonOptionsCard(theme, ref, ws),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 搜索提供商列表 card
  // ---------------------------------------------------------------------------

  Widget _providersCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    WebSearchSettings ws,
  ) {
    final providers = ws.providers;

    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: '搜索提供商',
            description: '已添加的搜索服务，点击进入配置',
          ),
          Divider(height: 1, color: theme.dividerColor),

          // 已添加的提供商列表
          if (providers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.search,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无搜索提供商',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '点击下方按钮添加',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (var i = 0; i < providers.length; i++) ...[
              if (i > 0) Divider(height: 1, color: theme.dividerColor),
              _ProviderRow(
                config: providers[i],
                isActive: providers[i].id == ws.activeProviderId,
                onTap: () => context.push(
                  AppRouter.searchProviderDetailPath(providers[i].id),
                ),
                onDelete: () => ref
                    .read(webSearchSettingsControllerProvider.notifier)
                    .removeProvider(providers[i].id),
              ),
            ],

          Divider(height: 1, color: theme.dividerColor),
          _AddProviderRow(
            onTap: () => context.push(AppRouter.addSearchProviderPath),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 通用选项 card
  // ---------------------------------------------------------------------------

  Widget _commonOptionsCard(
    ThemeData theme,
    WidgetRef ref,
    WebSearchSettings ws,
  ) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: '通用选项',
            description: '搜索结果数量和超时时间等通用设置',
          ),
          Divider(height: 1, color: theme.dividerColor),
          _StepperRow(
            icon: LucideIcons.listOrdered,
            accent: const Color(0xFF8B5CF6),
            label: '最大结果数',
            description: '每次搜索返回的最大结果条数',
            value: ws.maxResults,
            min: 1,
            max: 20,
            onChanged: (v) => ref
                .read(webSearchSettingsControllerProvider.notifier)
                .setMaxResults(v),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _StepperRow(
            icon: LucideIcons.timer,
            accent: const Color(0xFFF59E0B),
            label: '超时时间',
            description: '搜索请求的最长等待时间',
            value: ws.timeout,
            min: 5,
            max: 60,
            unit: '秒',
            onChanged: (v) => ref
                .read(webSearchSettingsControllerProvider.notifier)
                .setTimeout(v),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared card / row widgets
// =============================================================================

class _OutlinedCard extends StatelessWidget {
  const _OutlinedCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: theme.colorScheme.onSurface.withValues(alpha: 0.015),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A provider row showing icon, name, description, active badge, delete icon,
/// and chevron. The delete icon uses a two-tap pattern: first tap turns it red
/// (confirm state), second tap performs the deletion. Tapping elsewhere or
/// waiting 2 seconds resets the confirm state.
class _ProviderRow extends StatefulWidget {
  const _ProviderRow({
    required this.config,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final SearchProviderConfig config;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends State<_ProviderRow> {
  bool _confirmDelete = false;

  void _resetConfirm() {
    if (_confirmDelete && mounted) setState(() => _confirmDelete = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preset = presetForId(widget.config.id);

    return InkWell(
      onTap: () {
        if (_confirmDelete) {
          setState(() => _confirmDelete = false);
          return;
        }
        widget.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SearchProviderIcon(preset: preset, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.config.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (widget.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '当前',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      if (!widget.config.isEnabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '已禁用',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preset?.description ?? widget.config.apiHost,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Delete icon: first tap → red confirm, second tap → delete.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_confirmDelete) {
                  widget.onDelete();
                } else {
                  setState(() => _confirmDelete = true);
                  Future.delayed(
                      const Duration(seconds: 2), _resetConfirm);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: _confirmDelete
                      ? const Color(0xFFEF4444)
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// "添加提供商" row at the bottom of the providers card.
class _AddProviderRow extends StatelessWidget {
  const _AddProviderRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.plus, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              '添加搜索提供商',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stepper row: icon + label on the left, minus/value/plus on the right.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.icon,
    required this.accent,
    required this.label,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String description;
  final int value;
  final int min;
  final int max;
  final String? unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Stepper(
            value: value,
            min: min,
            max: max,
            unit: unit,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit,
  });

  final int value;
  final int min;
  final int max;
  final String? unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: LucideIcons.minus,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            unit != null ? '$value$unit' : '$value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
        _StepperButton(
          icon: LucideIcons.plus,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color =
        enabled ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.3);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
