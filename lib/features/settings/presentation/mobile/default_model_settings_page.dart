import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

/// The "模型设置" second-level page (hub "配置模型" → this page), a 1:1
/// reproduction of the layout of the original
/// `src/pages/Settings/DefaultModelSettings.tsx`.
///
/// It is a pure view — no business logic, no `data` import, no fabricated
/// providers, and every control that would need real data or a not-yet-built
/// destination is rendered disabled (the settings hub / About page convention:
/// half opacity, no tap handler):
///   * 添加 / 批量删除 — need the provider store + add/multi-select flows.
///   * the provider list — has no data, so it renders empty (no fake rows).
///   * the "推荐操作" rows — link to third-level pages / toggle persisted state
///     that don't exist yet.
///
/// The provider rows, drag-reorder, multi-select delete and edit dialog remain
/// deferred to later milestones.
///
/// All colors are theme tokens (ADR-0008); icons are lucide (ADR-0009). The
/// original's per-action avatar brand hues (indigo / cyan / purple) are
/// deliberately mapped to the theme's [ColorScheme.primary] accent — adding a
/// multi-hue palette to `ThemeSpec` is a separate effort, and hard-coding those
/// hex values would violate ADR-0008.
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
        children: const [
          _ProvidersCard(),
          SizedBox(height: 16),
          _RecommendedActionsCard(),
        ],
      ),
    );
  }
}

/// The original's inline `Paper`: 8px radius, a 1px divider-colored border and
/// a soft drop shadow, clipped so children (header tints, dividers) honor the
/// rounded corners. Shared by both cards on this page.
class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.child});

  final Widget child;

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
            children: [child],
          ),
        ),
      ),
    );
  }
}

/// The "模型服务商" card: section header (title + description) followed by the
/// (empty) provider-list region.
class _ProvidersCard extends StatelessWidget {
  const _ProvidersCard();

  static const String _providersTitle = '模型服务商';
  static const String _providersDesc = '您可以配置多个模型服务商，点击对应的服务商进行设置和管理';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ModelCard(
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
    );
  }
}

/// The lower "推荐操作" card. Its three rows link to third-level pages / toggle
/// persisted state that don't exist yet, so each row is a disabled placeholder
/// (half opacity, no tap handler). The subheader is a plain label.
class _RecommendedActionsCard extends StatelessWidget {
  const _RecommendedActionsCard();

  static const String _subheader = '推荐操作';
  static const String _assistantTitle = '辅助模型设置';
  static const String _assistantDesc = '设置话题命名、AI 意图分析等辅助功能的模型';
  static const String _selectorTitle = '模型选择器样式';
  // The original defaults `modelSelectorStyle` to 'dialog' (`defaults.ts`),
  // so the static placeholder shows the dialog state's label + icon.
  static const String _selectorDesc = '当前：弹窗式选择器（点击切换为下拉式）';
  static const String _addProviderTitle = '添加模型服务商';
  static const String _addProviderDesc = '设置新的模型服务商';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ModelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.01),
            child: Text(
              _subheader,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const _ActionRow(
            icon: LucideIcons.bot,
            title: _assistantTitle,
            description: _assistantDesc,
          ),
          const Divider(height: 1, thickness: 1),
          const _ActionRow(
            icon: LucideIcons.list,
            title: _selectorTitle,
            description: _selectorDesc,
            showChevron: false,
          ),
          const Divider(height: 1, thickness: 1),
          const _ActionRow(
            icon: LucideIcons.plus,
            title: _addProviderTitle,
            description: _addProviderDesc,
          ),
        ],
      ),
    );
  }
}

/// A single "推荐操作" row: a tinted circular avatar + title/description, with an
/// optional trailing chevron. Always rendered disabled this milestone (half
/// opacity, no tap handler).
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.description,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              child: Icon(icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ],
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
