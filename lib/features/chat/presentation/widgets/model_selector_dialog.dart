import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Opens the model selector — a 1:1 visual port of the original SolidJS
/// `DialogModelSelector` (`src/solid/components/ModelSelector/
/// DialogModelSelector.solid.{tsx,css}`).
///
/// Reproduces the original CSS exactly: a centered rounded card
/// (`max-width: 600`, `width: 90%`, `max-height: 80vh`, `border-radius: 8`) over
/// a `rgba(0,0,0,0.5)` backdrop, entering with the `fadeIn` + `slideUp`
/// animation; a header (「选择模型」 + the `⚡ SolidJS` badge + a circular close
/// button), a horizontally-scrollable tab strip (「全部」 + the current provider,
/// then the rest) with left/right scroll arrows that appear on overflow, and a
/// model list whose rows are a 28×28 icon, name + description, and a check on
/// the selection. Colours map onto the same theme tokens the original's CSS
/// variables resolve to.
Future<void> showModelSelectorDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '选择模型',
    barrierColor: const Color(0x80000000), // rgba(0,0,0,0.5)
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => const _ModelSelectorDialog(),
    transitionBuilder: (_, animation, _, child) {
      // fadeIn + slideUp (translateY(20px) -> 0), ease-out.
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - curved.value)),
          child: child,
        ),
      );
    },
  );
}

class _ModelSelectorDialog extends ConsumerStatefulWidget {
  const _ModelSelectorDialog();

  @override
  ConsumerState<_ModelSelectorDialog> createState() =>
      _ModelSelectorDialogState();
}

class _ModelSelectorDialogState extends ConsumerState<_ModelSelectorDialog> {
  final ScrollController _tabsController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  /// Active tab id: `'all'` or a provider id. Seeded to the current provider on
  /// first build (mirrors the original auto-switch to 「常用」).
  String? _activeTab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _tabsController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!_tabsController.hasClients) return;
    final pos = _tabsController.position;
    final left = pos.pixels > 0;
    final right = pos.pixels < pos.maxScrollExtent - 1;
    if (left != _showLeftArrow || right != _showRightArrow) {
      setState(() {
        _showLeftArrow = left;
        _showRightArrow = right;
      });
    }
  }

  void _scrollTabs(bool left) {
    if (!_tabsController.hasClients) return;
    final target = (_tabsController.offset + (left ? -200 : 200)).clamp(
      0.0,
      _tabsController.position.maxScrollExtent,
    );
    _tabsController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _Palette(theme);
    final media = MediaQuery.of(context);
    final size = media.size;
    final isNarrow = size.width <= 600;

    final providers = ref.watch(appModelProvidersProvider).value ?? const [];
    final current = ref.watch(appCurrentModelProvider).value;

    // Only enabled models from enabled providers, like the original
    // `useModelSelection` hook (treats an unset flag as enabled).
    final populated = <ModelProvider>[
      for (final p in providers)
        if ((p.isEnabled) && p.models.any((m) => m.enabled ?? true))
          p.copyWith(
            models: [
              for (final m in p.models)
                if (m.enabled ?? true) m,
            ],
          ),
    ];
    final currentProviderId = current?.provider.id;
    final selectedKey = current == null
        ? null
        : _identity(current.provider.id, current.model.id);

    final tabProviders = <ModelProvider>[
      for (final p in populated)
        if (p.id == currentProviderId) p,
      for (final p in populated)
        if (p.id != currentProviderId) p,
    ];
    final activeTab = _activeTab ?? currentProviderId ?? 'all';
    final displayed = _displayedModels(populated, activeTab);

    final dialogWidth = isNarrow ? size.width * 0.95 : size.width * 0.9;
    final maxHeight = size.height * (isNarrow ? 0.9 : 0.8);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(dialogWidth, 600),
          maxHeight: maxHeight,
        ),
        child: Material(
          color: palette.paper,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          // MUI dialog (Paper elevation 24) three-layer shadow.
          elevation: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 11),
                  blurRadius: 15,
                  spreadRadius: -7,
                ),
                BoxShadow(
                  color: Color(0x24000000),
                  offset: Offset(0, 24),
                  blurRadius: 38,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: Color(0x1F000000),
                  offset: Offset(0, 9),
                  blurRadius: 46,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(theme, palette, isNarrow),
                _tabsWrapper(theme, palette, tabProviders, activeTab, isNarrow),
                Flexible(
                  child: displayed.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '尚未配置任何模型',
                            style: TextStyle(
                              fontSize: 14,
                              color: palette.textSecondary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            isNarrow ? 12 : 16,
                            8,
                            isNarrow ? 12 : 16,
                            isNarrow ? 12 : 16,
                          ),
                          itemCount: displayed.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final entry = displayed[index];
                            return _ModelItem(
                              palette: palette,
                              provider: entry.provider,
                              model: entry.model,
                              isSelected:
                                  selectedKey ==
                                  _identity(entry.provider.id, entry.model.id),
                              onTap: () => _select(entry.provider, entry.model),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, _Palette palette, bool isNarrow) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : 24,
        vertical: 16,
      ).copyWith(right: isNarrow ? 8 : 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '选择模型',
                  style: TextStyle(
                    fontSize: 20, // 1.25rem
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '⚡ SolidJS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF90CAF9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            color: palette.textSecondary,
            splashRadius: 22,
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _tabsWrapper(
    ThemeData theme,
    _Palette palette,
    List<ModelProvider> tabProviders,
    String activeTab,
    bool isNarrow,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          if (_showLeftArrow) _scrollArrow(palette, left: true),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _updateArrows();
                return false;
              },
              child: SingleChildScrollView(
                controller: _tabsController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tab(
                      palette,
                      label: '全部',
                      id: 'all',
                      activeTab: activeTab,
                      isNarrow: isNarrow,
                    ),
                    for (final provider in tabProviders)
                      _tab(
                        palette,
                        label: provider.name,
                        id: provider.id,
                        activeTab: activeTab,
                        isNarrow: isNarrow,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_showRightArrow) _scrollArrow(palette, left: false),
        ],
      ),
    );
  }

  Widget _scrollArrow(_Palette palette, {required bool left}) {
    return Container(
      decoration: BoxDecoration(
        color: palette.paper,
        border: Border(
          left: left ? BorderSide.none : BorderSide(color: palette.border),
          right: left ? BorderSide(color: palette.border) : BorderSide.none,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _scrollTabs(left),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Icon(
            left ? Icons.chevron_left : Icons.chevron_right,
            size: 24,
            color: palette.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _tab(
    _Palette palette, {
    required String label,
    required String id,
    required String activeTab,
    required bool isNarrow,
  }) {
    final active = activeTab == id;
    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrow ? 12 : 16,
          vertical: isNarrow ? 10 : 12,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? palette.primary : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: isNarrow ? 13 : 14, // 0.8125rem / 0.875rem
            fontWeight: FontWeight.w500,
            color: active ? palette.primary : palette.textSecondary,
          ),
        ),
      ),
    );
  }

  List<_ModelEntry> _displayedModels(
    List<ModelProvider> populated,
    String activeTab,
  ) {
    if (activeTab == 'all') {
      return [
        for (final p in populated)
          for (final m in p.models) _ModelEntry(p, m),
      ];
    }
    for (final p in populated) {
      if (p.id == activeTab) {
        return [for (final m in p.models) _ModelEntry(p, m)];
      }
    }
    return const [];
  }

  Future<void> _select(ModelProvider provider, Model model) async {
    await ref
        .read(modelStoreProvider.notifier)
        .selectCurrentModel(providerId: provider.id, modelId: model.id);
    if (mounted) Navigator.of(context).pop();
  }

  static String _identity(String providerId, String modelId) =>
      '$providerId::$modelId';
}

class _ModelEntry {
  const _ModelEntry(this.provider, this.model);

  final ModelProvider provider;
  final Model model;
}

class _ModelItem extends StatelessWidget {
  const _ModelItem({
    required this.palette,
    required this.provider,
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final _Palette palette;
  final ModelProvider provider;
  final Model model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? palette.selectedBg : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: palette.hoverBg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _icon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model.name,
                      style: TextStyle(
                        fontSize: 16, // 1rem
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (model.description != null &&
                              model.description!.isNotEmpty)
                          ? model.description!
                          : '${provider.name}模型',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12, // 0.75rem
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 20, color: palette.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // No provider-icon assets in this port, so render the original's image-error
  // fallback: a `bg-elevated` rounded square with the provider's initial.
  Widget _icon() {
    final label = provider.name.isNotEmpty
        ? provider.name.characters.first
        : '?';
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.elevated,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

/// Maps the original CSS theme variables onto the app's theme tokens.
class _Palette {
  _Palette(ThemeData theme)
    : paper = theme.colorScheme.surface,
      primary = theme.colorScheme.primary,
      textPrimary = theme.colorScheme.onSurface,
      textSecondary = theme.colorScheme.onSurfaceVariant,
      border = theme.dividerColor,
      hoverBg = theme.colorScheme.onSurface.withValues(alpha: 0.04),
      selectedBg = theme.colorScheme.primary.withValues(alpha: 0.08),
      elevated = Color.alphaBlend(
        theme.colorScheme.onSurface.withValues(alpha: 0.06),
        theme.colorScheme.surface,
      );

  final Color paper;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color hoverBg;
  final Color selectedBg;
  final Color elevated;
}
