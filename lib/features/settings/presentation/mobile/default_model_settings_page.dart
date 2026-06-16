import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';
import 'package:aetherlink_flutter/shared/utils/provider_icons.dart';

/// The "模型设置" second-level page (hub "配置模型" → this page), a 1:1
/// reproduction of the layout of the original
/// `src/pages/Settings/DefaultModelSettings.tsx`.
///
/// The page mirrors the original's exact metrics (font sizes, card radius,
/// paddings, spacing, colors) and is fully wired: 添加 opens the add-provider
/// page, 批量删除 enters the original's multi-select batch-delete flow, and the
/// provider list renders the persisted providers (brand avatar + enabled status
/// + reorder), opening each provider's detail page on tap. Some "推荐操作" rows
/// still link to not-yet-built destinations and carry no handler.
///
/// To match the original pixel-for-pixel, the per-action avatar brand hues and
/// the subtle `rgba(0,0,0,...)` tints/shadows are taken verbatim from the
/// original CSS (the only literal colors on the page; everything else is a
/// theme token).
class DefaultModelSettingsPage extends ConsumerStatefulWidget {
  const DefaultModelSettingsPage({super.key});

  @override
  ConsumerState<DefaultModelSettingsPage> createState() =>
      _DefaultModelSettingsPageState();
}

class _DefaultModelSettingsPageState
    extends ConsumerState<DefaultModelSettingsPage> {
  // Strings lifted verbatim from the original `modelSettings.modelList.*`
  // zh-CN i18n (the M4.1/M4.2 static-constant approach).
  static const String _title = '模型设置';
  static const String _batchDeleteLabel = '批量删除';
  static const String _addLabel = '添加';
  static const String _cancelLabel = '取消';

  // The original's `isMultiSelectMode` / `selectedProviders` component state.
  bool _multiSelect = false;
  final Set<String> _selected = <String>{};

  void _enterMultiSelect() => setState(() {
    _multiSelect = true;
    _selected.clear();
  });

  void _exitMultiSelect() => setState(() {
    _multiSelect = false;
    _selected.clear();
  });

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _selectAll(List<ModelProvider> providers) => setState(() {
    if (_selected.length == providers.length) {
      _selected.clear();
    } else {
      _selected
        ..clear()
        ..addAll(providers.map((p) => p.id));
    }
  });

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
        // Original back IconButton: a 40x40 hit target sitting 4px from the
        // edge (16px gutter − the 12px `edge="start"` overhang), so its 24px
        // glyph lands 16px in and the title butts up at x=44.
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
        // Original HeaderBar title: the themed h6 (1.125rem = 18px) at weight
        // 600, left-aligned tight against the back button.
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text(_title),
        actions: [
          if (_multiSelect) ...[
            _ToolbarAction(
              icon: LucideIcons.x,
              label: _cancelLabel,
              tint: _ToolbarTint.neutral,
              onTap: _exitMultiSelect,
            ),
            const SizedBox(width: 8),
            _ToolbarAction(
              icon: LucideIcons.trash2,
              label: '删除 (${_selected.length})',
              tint: _ToolbarTint.error,
              enabled: _selected.isNotEmpty,
              onTap: _selected.isEmpty ? null : _confirmDeleteSelected,
            ),
          ] else ...[
            _ToolbarAction(
              icon: LucideIcons.trash2,
              label: _batchDeleteLabel,
              tint: _ToolbarTint.error,
              onTap: _enterMultiSelect,
            ),
            const SizedBox(width: 8),
            _ToolbarAction(
              icon: LucideIcons.plus,
              label: _addLabel,
              tint: _ToolbarTint.primary,
              onTap: () => context.push(AppRouter.addProviderPath),
            ),
          ],
          // Toolbar right gutter (16px on the mobile breakpoint).
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProvidersCard(
            multiSelect: _multiSelect,
            selectedIds: _selected,
            onToggle: _toggle,
            onSelectAll: _selectAll,
          ),
          const SizedBox(height: 16),
          const _RecommendedActionsCard(),
        ],
      ),
    );
  }

  /// Confirms then deletes every selected provider (the original's
  /// `handleConfirmDelete`), then clears the selection and leaves multi-select.
  Future<void> _confirmDeleteSelected() async {
    if (_selected.isEmpty) return;
    final ids = _selected.toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(
            '确认删除',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '您确定要删除选中的 '),
                    TextSpan(
                      text: '${ids.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' 个供应商吗？'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '此操作将删除这些供应商及其所有配置信息，且无法恢复。',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                backgroundColor: const Color(0x1AEF4444),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final store = ref.read(modelStoreProvider.notifier);
    for (final id in ids) {
      await store.deleteProvider(id);
    }
    if (!mounted) return;
    _exitMultiSelect();
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
/// followed by a full-width divider and the persisted provider list. With no
/// providers (fresh install) the list region stays empty — no fabricated rows.
class _ProvidersCard extends ConsumerWidget {
  const _ProvidersCard({
    required this.multiSelect,
    required this.selectedIds,
    required this.onToggle,
    required this.onSelectAll,
  });

  final bool multiSelect;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;
  final void Function(List<ModelProvider> providers) onSelectAll;

  static const String _providersTitle = '模型服务商';
  static const String _providersDesc = '您可以配置多个模型服务商，点击对应的服务商进行设置和管理';
  static const String _selectToDelete = '选择要删除的服务商';
  static const String _selectAll = '全选';
  static const String _unselectAll = '取消全选';

  // The original header/subheader `bgcolor: 'rgba(0,0,0,0.01)'`.
  static const Color _headerTint = Color(0x03000000);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providersAsync = ref.watch(appModelProvidersProvider);
    final providers = providersAsync.asData?.value ?? const <ModelProvider>[];
    final allSelected =
        providers.isNotEmpty && selectedIds.length == providers.length;

    return _ModelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ColoredBox(
            color: _headerTint,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _providersTitle,
                          // subtitle1: not overridden in the theme, so it keeps
                          // MUI's default scaled by the `typography.fontSize:16`
                          // coef (16/14) → 18.29px, line-height 1.75 (= 32px).
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 128 / 7,
                            height: 1.75,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          multiSelect ? _selectToDelete : _providersDesc,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (multiSelect)
                    TextButton(
                      onPressed: () => onSelectAll(providers),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      child: Text(allSelected ? _unselectAll : _selectAll),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          if (providers.isNotEmpty)
            _ProviderList(
              providers: providers,
              multiSelect: multiSelect,
              selectedIds: selectedIds,
              onToggle: onToggle,
            ),
        ],
      ),
    );
  }
}

/// The reorderable list of persisted providers — a 1:1 port of the original
/// `List` of `ListItemButton`s. Each row drags to reorder (`reorderProviders`),
/// shows the provider's brand avatar + enabled/disabled status, and opens its
/// detail page on tap. In multi-select mode the drag handle becomes a checkbox
/// and tapping toggles the row's selection instead of navigating.
class _ProviderList extends ConsumerWidget {
  const _ProviderList({
    required this.providers,
    required this.multiSelect,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<ModelProvider> providers;
  final bool multiSelect;
  final Set<String> selectedIds;
  final void Function(String id) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: providers.length,
      onReorderItem: (oldIndex, newIndex) {
        final ids = [for (final p in providers) p.id];
        final moved = ids.removeAt(oldIndex);
        ids.insert(newIndex, moved);
        ref.read(modelStoreProvider.notifier).reorderProviders(ids);
      },
      itemBuilder: (context, index) {
        final provider = providers[index];
        return _ProviderRow(
          key: ValueKey(provider.id),
          provider: provider,
          index: index,
          multiSelect: multiSelect,
          selected: selectedIds.contains(provider.id),
          onToggle: () => onToggle(provider.id),
          onOpen: () => context.push(AppRouter.modelProviderPath(provider.id)),
          onEdit: () => _editProvider(context, ref, provider),
        );
      },
    );
  }

  /// Opens the original's 编辑供应商 dialog (the gear's `handleEditProvider`)
  /// and, on save, persists the edited name + type through `saveProvider`
  /// (the original's `updateProvider({ name, providerType })`).
  Future<void> _editProvider(
    BuildContext context,
    WidgetRef ref,
    ModelProvider provider,
  ) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditProviderDialog(provider: provider),
    );
    if (result == null) return;
    await ref
        .read(modelStoreProvider.notifier)
        .saveProvider(
          provider.copyWith(name: result.$1, providerType: result.$2),
        );
  }
}

/// One provider row. Layout mirrors the original `ListItemButton`: a leading
/// drag handle (or checkbox in multi-select), the 40px brand avatar, the name
/// over an "已启用/已禁用·N 个模型" status line, and a trailing settings gear +
/// chevron (hidden in multi-select).
class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    super.key,
    required this.provider,
    required this.index,
    required this.multiSelect,
    required this.selected,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
  });

  final ModelProvider provider;
  final int index;
  final bool multiSelect;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;

  // The original chevron's `rgba(79, 70, 229, 0.5)`.
  static const Color _chevron = Color(0x804F46E5);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // MUI `success.main` (light #2e7d32 / dark #66bb6a) and `text.disabled`.
    final statusColor = provider.isEnabled
        ? (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32))
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Material(
      color: selected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        onTap: multiSelect ? onToggle : onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (multiSelect)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onToggle(),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                )
              else
                Opacity(
                  opacity: 0.6,
                  child: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(LucideIcons.gripVertical, size: 20),
                    ),
                  ),
                ),
              _ProviderAvatar(provider: provider),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          provider.isEnabled ? '已启用' : '已禁用',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                        if (provider.models.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${provider.models.length} 个模型',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!multiSelect) ...[
                IconButton(
                  icon: const Icon(LucideIcons.settings, size: 16),
                  color: theme.colorScheme.onSurfaceVariant,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  tooltip: '编辑',
                  onPressed: onEdit,
                ),
                const SizedBox(width: 8),
                const Icon(LucideIcons.chevronRight, size: 20, color: _chevron),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The provider's 40px circular brand avatar — the original MUI `Avatar` with a
/// transparent fill, a soft `0 2px 6px rgba(0,0,0,0.05)` shadow and a
/// first-letter fallback when the bundled logo can't be resolved.
class _ProviderAvatar extends StatelessWidget {
  const _ProviderAvatar({required this.provider});

  final ModelProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final type = provider.providerType;
    final assetPath = getProviderIcon(
      (type != null && type.isNotEmpty) ? type : provider.id,
      isDark: isDark,
    );
    final fallback = provider.name.isNotEmpty
        ? provider.name.substring(0, 1).toUpperCase()
        : '?';

    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Center(
          child: Text(
            fallback,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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
                    // ListSubheader default size scaled by the 16/14 coef = 16px.
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
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

/// Whether a toolbar action carries the primary, error or neutral accent.
enum _ToolbarTint { primary, error, neutral }

/// A header-bar action — the original's tonal `Button` (startIcon + label on a
/// `borderRadius: 2` (16px) low-alpha tint, weight 600, no text-transform).
/// Carries error / primary / neutral accents plus an optional disabled state
/// (the 删除 (N) action greys out when nothing is selected).
class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.icon,
    required this.label,
    required this.tint,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final _ToolbarTint tint;
  final bool enabled;

  /// Tap handler. When null the action renders at full visual fidelity but is
  /// non-functional this milestone.
  final VoidCallback? onTap;

  // The original palette's `error.main`. The shared theme currently maps
  // `colorScheme.error` to Material's `#B00020`, so the literal is used here to
  // match the original's exact red (the 添加 action already matches via
  // `colorScheme.primary` = `#64748B`).
  static const Color _errorRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg;
    final Color fg;
    if (!enabled) {
      // The original `&:disabled`: grey[500] @ 0.05 fill, `text.disabled` ink.
      bg = const Color(0x0D9E9E9E);
      fg = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    } else {
      switch (tint) {
        case _ToolbarTint.error:
          bg = _errorRed.withValues(alpha: 0.1);
          fg = _errorRed;
        case _ToolbarTint.primary:
          bg = theme.colorScheme.primary.withValues(alpha: 0.1);
          fg = theme.colorScheme.primary;
        case _ToolbarTint.neutral:
          // The original 取消: grey[500] @ 0.1 fill, `text.secondary` ink.
          bg = const Color(0x1A9E9E9E);
          fg = theme.colorScheme.onSurfaceVariant;
      }
    }

    // MUI text Button: minWidth 64, ~36.5px tall, `borderRadius:2` (16px), and
    // a startIcon whose −4px left / 8px right margins net to 4px before the
    // glyph and 8px before the label inside the 8px horizontal padding.
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 64, minHeight: 36.5),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 14,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    final tappable = onTap == null
        ? content
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: content,
          );

    // AppBar lays its `actions` out in a `CrossAxisAlignment.stretch` Row, which
    // would stretch the pill to the full 56px toolbar height. Center keeps it at
    // the intrinsic 36.5px and vertically centered, matching the MUI button.
    return Center(child: tappable);
  }
}

/// The original's 编辑供应商 dialog (`handleEditProvider` → `handleSaveProvider`):
/// an outlined name field over a provider-type dropdown, with a weight-600
/// title and a tonal 保存 that greys out while the name is blank. Pops the
/// edited `(name, type)` on save, or null on cancel.
class _EditProviderDialog extends StatefulWidget {
  const _EditProviderDialog({required this.provider});

  final ModelProvider provider;

  // The original `providerTypeOptions` (value, label), verbatim.
  static const List<(String, String)> typeOptions = [
    ('openai', 'OpenAI'),
    ('openai-response', 'OpenAI (Responses API)'),
    ('anthropic', 'Anthropic'),
    ('deepseek', 'DeepSeek'),
    ('zhipu', '智谱AI'),
    ('google', 'Google'),
    ('azure-openai', 'Azure OpenAI'),
    ('siliconflow', 'SiliconFlow'),
    ('volcengine', '火山引擎'),
    ('grok', 'Grok'),
    ('custom', '自定义'),
  ];

  @override
  State<_EditProviderDialog> createState() => _EditProviderDialogState();
}

class _EditProviderDialogState extends State<_EditProviderDialog> {
  late final TextEditingController _name;
  String? _type;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.provider.name);
    // Seed the dropdown only when the stored type is one of the options;
    // otherwise leave it unselected (the original `provider.providerType || ''`
    // would simply show no matching MenuItem).
    final stored = widget.provider.providerType;
    _type = _EditProviderDialog.typeOptions.any((o) => o.$1 == stored)
        ? stored
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _name.text.trim().isNotEmpty;

    return AlertDialog(
      title: const Text('编辑供应商', style: TextStyle(fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '供应商名称',
                hintText: '例如: 我的智谱AI',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '供应商类型',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final option in _EditProviderDialog.typeOptions)
                  DropdownMenuItem<String>(
                    value: option.$1,
                    child: Text(option.$2),
                  ),
              ],
              onChanged: (value) => setState(() => _type = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
          onPressed: canSave
              ? () =>
                    Navigator.of(context).pop((_name.text.trim(), _type ?? ''))
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
