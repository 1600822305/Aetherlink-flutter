import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';

/// The "模型设置" second-level page (hub "配置模型" → this page), a 1:1
/// reproduction of the layout of the original
/// `src/pages/Settings/DefaultModelSettings.tsx`.
///
/// This is a pure view — no business logic, no `data` import, no fabricated
/// providers. The page mirrors the original's exact metrics (font sizes, card
/// radius, paddings, spacing, colors). Controls that would need real data or a
/// not-yet-built destination carry no tap handler (they render at full visual
/// fidelity, they just don't do anything yet):
///   * 添加 / 批量删除 — need the provider store + add/multi-select flows.
///   * the provider list — has no data, so it renders empty (no fake rows).
///   * the "推荐操作" rows — link to third-level pages / toggle persisted state.
///
/// To match the original pixel-for-pixel, the per-action avatar brand hues and
/// the subtle `rgba(0,0,0,...)` tints/shadows are taken verbatim from the
/// original CSS (the only literal colors on the page; everything else is a
/// theme token).
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
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 24),
          color: theme.colorScheme.primary,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRouter.settingsPath),
        ),
        // Original HeaderBar title: the themed h6 (1.125rem = 18px) at weight
        // 600, left-aligned tight against the back button.
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(_title),
        actions: const [
          _ToolbarAction(
            icon: LucideIcons.trash2,
            label: _batchDeleteLabel,
            tint: _ToolbarTint.error,
          ),
          SizedBox(width: 8),
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

/// The original inline `Paper`: `borderRadius: 2` (= 16px against the theme's
/// `shape.borderRadius: 8`), a 1px divider-colored border and a soft
/// `0 4px 12px rgba(0,0,0,0.05)` shadow, clipped so children (header tints,
/// dividers) honor the rounded corners. Shared by both cards on this page.
class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.child});

  final Widget child;

  static const double _radius = 16;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: theme.dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 12,
            offset: Offset(0, 4),
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

/// The "模型服务商" card: a tinted header (subtitle1 title + body2 description)
/// followed by a full-width divider and the (empty) provider-list region.
class _ProvidersCard extends StatelessWidget {
  const _ProvidersCard();

  static const String _providersTitle = '模型服务商';
  static const String _providersDesc = '您可以配置多个模型服务商，点击对应的服务商进行设置和管理';

  // The original header/subheader `bgcolor: 'rgba(0,0,0,0.01)'`.
  static const Color _headerTint = Color(0x03000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ModelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: _headerTint,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _providersTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _providersDesc,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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

/// The lower "推荐操作" card: a list subheader followed by three rows
/// (辅助模型设置 / 模型选择器样式 / 添加模型服务商) split by full-width inset
/// dividers, each with its own brand-tinted avatar.
class _RecommendedActionsCard extends StatelessWidget {
  const _RecommendedActionsCard();

  static const String _subheader = '推荐操作';
  static const String _assistantTitle = '辅助模型设置';
  static const String _assistantDesc = '设置话题命名、AI 意图分析等辅助功能的模型';
  static const String _selectorTitle = '模型选择器样式';
  // The original defaults `modelSelectorStyle` to 'dialog' (`defaults.ts`), so
  // the static placeholder shows the dialog state's label + `List` icon.
  static const String _selectorDesc = '当前：弹窗式选择器（点击切换为下拉式）';
  static const String _addProviderTitle = '添加模型服务商';
  static const String _addProviderDesc = '设置新的模型服务商';

  // Verbatim per-action avatar accents from the original CSS.
  static const Color _assistantAccent = Color(0xFF4F46E5); // indigo
  static const Color _selectorAccent = Color(0xFF06B6D4); // cyan
  static const Color _addProviderAccent = Color(0xFF9333EA); // purple

  // The subheader `bgcolor: 'rgba(0,0,0,0.01)'`.
  static const Color _subheaderTint = Color(0x03000000);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _ModelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: _subheaderTint,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _subheader,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const _ActionRow(
            icon: LucideIcons.bot,
            accent: _assistantAccent,
            title: _assistantTitle,
            description: _assistantDesc,
          ),
          const Divider(height: 1, thickness: 1),
          const _ActionRow(
            icon: LucideIcons.list,
            accent: _selectorAccent,
            title: _selectorTitle,
            description: _selectorDesc,
            showChevron: false,
          ),
          const Divider(height: 1, thickness: 1),
          // The only wired entry this milestone: 添加供应商 → AddProviderPage
          // (the third-level destination now exists, M4.3.1).
          _ActionRow(
            icon: LucideIcons.plus,
            accent: _addProviderAccent,
            title: _addProviderTitle,
            description: _addProviderDesc,
            onTap: () => context.push(AppRouter.addProviderPath),
          ),
        ],
      ),
    );
  }
}

/// A single "推荐操作" row: the original `ListItemButton` (8px×16px padding) with
/// a 40px brand-tinted avatar, primary/secondary text and an optional trailing
/// 20px chevron. Rendered at full visual fidelity but with no tap handler this
/// milestone (its destinations / toggles don't exist yet).
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    this.showChevron = true,
    this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final bool showChevron;

  /// Navigation tap. When null the row renders at full visual fidelity but is
  /// non-functional (its destination / toggle doesn't exist yet this milestone).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000), // rgba(0,0,0,0.05)
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 24, color: accent),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
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
    );

    // Only the wired entry is ink-tappable; the rest render at full visual
    // fidelity but carry no handler this milestone.
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Whether a toolbar action carries the primary or the error accent.
enum _ToolbarTint { primary, error }

/// A header-bar action — the original's tonal `Button` (startIcon + label on a
/// `borderRadius: 2` (16px) low-alpha tint, weight 600, no text-transform).
/// Rendered at full visual fidelity but with no tap handler this milestone
/// (both actions need data / flows that don't exist yet).
class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final _ToolbarTint tint;

  // The original palette's `error.main`. The shared theme currently maps
  // `colorScheme.error` to Material's `#B00020`, so the literal is used here to
  // match the original's exact red (the 添加 action already matches via
  // `colorScheme.primary` = `#64748B`).
  static const Color _errorRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = tint == _ToolbarTint.error
        ? _errorRed
        : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 14,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
