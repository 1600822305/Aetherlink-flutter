import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

/// The "模型设置" second-level page (hub "配置模型" → this page), a 1:1
/// reproduction of the layout of the original
/// `src/pages/Settings/DefaultModelSettings.tsx`.
///
/// This milestone (M4.3.0) ports only the page's top section: the header bar
/// (back / title / 批量删除 / 添加) and the "模型服务商" card (title + description
/// + provider list). It is a pure view — no business logic, no `data` import,
/// no fabricated providers, and every control that would need real data or a
/// not-yet-built destination is rendered disabled (the settings hub / About
/// page convention: half opacity, no tap handler):
///   * 添加 / 批量删除 — need the provider store + add/multi-select flows.
///   * the provider list — has no data, so it renders empty (no fake rows).
///
/// The original's lower "推荐操作" card (which links to third-level pages) and
/// the provider rows, drag-reorder, multi-select delete and edit dialog are
/// deferred to later milestones.
///
/// All colors are theme tokens (ADR-0008); icons are lucide (ADR-0009).
class DefaultModelSettingsPage extends ConsumerWidget {
  const DefaultModelSettingsPage({super.key});

  // Strings lifted verbatim from the original `modelSettings.modelList.*`
  // zh-CN i18n (the M4.1/M4.2 static-constant approach).
  static const String _title = '模型设置';
  static const String _batchDeleteLabel = '批量删除';
  static const String _addLabel = '添加';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
        title: const Text(_title),
        actions: const [
          // Both actions need the provider store / a flow that doesn't exist
          // yet, so they render disabled (no tap handler).
          _ToolbarAction(
            icon: LucideIcons.trash2,
            label: _batchDeleteLabel,
            tint: _ToolbarTint.error,
          ),
          _ToolbarAction(
            icon: LucideIcons.plus,
            label: _addLabel,
            tint: _ToolbarTint.primary,
          ),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [_ProvidersCard()],
      ),
    );
  }
}

/// The "模型服务商" card: the original inline `Paper` (8px radius, 1px divider
/// border, a soft drop shadow) holding the section header and the provider
/// list region.
class _ProvidersCard extends StatelessWidget {
  const _ProvidersCard();

  static const String _providersTitle = '模型服务商';
  static const String _providersDesc = '您可以配置多个模型服务商，点击对应的服务商进行设置和管理';
  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _providersTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _providersDesc,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              // No data this milestone: the provider list renders empty — no
              // fabricated rows.
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether a toolbar action carries the primary or the error accent.
enum _ToolbarTint { primary, error }

/// A header-bar action — the original's tonal `Button` (icon + label on a
/// low-alpha tint). Rendered disabled this milestone: the app's placeholder
/// convention (half opacity, no tap handler), since both actions need data /
/// flows that don't exist yet.
class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final _ToolbarTint tint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = tint == _ToolbarTint.error ? scheme.error : scheme.primary;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Opacity(
        opacity: 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
