import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

/// 网络搜索设置页面（设置 → 提示词与工具 → 网络搜索），参考 Kelivo 的
/// `SearchServicesPage` 三层结构（搜索提供商列表 + 通用选项），但使用我们
/// 自己的 `_OutlinedCard` / `_PrimaryRow` 等组件风格。
///
/// 目前仅展示 SearXNG（默认内置提供商），后续可扩展多提供商管理。
/// 状态管理和持久化暂使用页面本地 State，待后端 controller 就绪后迁移。
class WebSearchSettingsPage extends ConsumerStatefulWidget {
  const WebSearchSettingsPage({super.key});

  @override
  ConsumerState<WebSearchSettingsPage> createState() =>
      _WebSearchSettingsPageState();
}

class _WebSearchSettingsPageState
    extends ConsumerState<WebSearchSettingsPage> {
  // --- Local state (placeholder until a real controller lands) ---
  int _selectedProvider = 0;
  int _maxResults = 5;
  int _timeout = 10;

  static const _providers = <_ProviderInfo>[
    _ProviderInfo(
      name: 'SearXNG',
      description: '聚合 Google、Bing、DuckDuckGo 等 70+ 搜索引擎',
      icon: LucideIcons.search,
      accent: Color(0xFF3B82F6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          _providersCard(theme),
          const SizedBox(height: 16),
          _commonOptionsCard(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 搜索提供商 card
  // ---------------------------------------------------------------------------

  Widget _providersCard(ThemeData theme) {
    return _OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            title: '搜索提供商',
            description: '选择和管理搜索服务提供商',
          ),
          Divider(height: 1, color: theme.dividerColor),
          for (var i = 0; i < _providers.length; i++) ...[
            if (i > 0) Divider(height: 1, color: theme.dividerColor),
            _ProviderRow(
              info: _providers[i],
              selected: i == _selectedProvider,
              onTap: () => setState(() => _selectedProvider = i),
            ),
          ],
          Divider(height: 1, color: theme.dividerColor),
          _AddProviderRow(onTap: _onAddProvider),
        ],
      ),
    );
  }

  void _onAddProvider() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('即将支持添加更多搜索提供商')),
    );
  }

  // ---------------------------------------------------------------------------
  // 通用选项 card
  // ---------------------------------------------------------------------------

  Widget _commonOptionsCard(ThemeData theme) {
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
            value: _maxResults,
            min: 1,
            max: 20,
            onChanged: (v) => setState(() => _maxResults = v),
          ),
          Divider(height: 1, color: theme.dividerColor),
          _StepperRow(
            icon: LucideIcons.timer,
            accent: const Color(0xFFF59E0B),
            label: '超时时间',
            description: '搜索请求的最长等待时间',
            value: _timeout,
            min: 5,
            max: 60,
            unit: '秒',
            onChanged: (v) => setState(() => _timeout = v),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared card / row widgets — same style as BehaviorSettingsPage
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

/// A provider row with icon badge, name, description, and a check when selected.
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final _ProviderInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: info.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(info.icon, size: 16, color: info.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    info.description,
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
            if (selected)
              Icon(LucideIcons.check, size: 18, color: theme.colorScheme.primary)
            else
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
            Icon(
              LucideIcons.plus,
              size: 16,
              color: theme.colorScheme.primary,
            ),
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

/// Compact +/- stepper control.
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
    final color = enabled
        ? cs.primary
        : cs.onSurfaceVariant.withValues(alpha: 0.3);
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

// =============================================================================
// Data model
// =============================================================================

@immutable
class _ProviderInfo {
  const _ProviderInfo({
    required this.name,
    required this.description,
    required this.icon,
    required this.accent,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color accent;
}
