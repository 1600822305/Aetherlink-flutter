import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

Future<void> showModelSelectorDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    pageBuilder: (context, _, _) => const _ModelSelectorView(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 200),
  );
}

class _ModelSelectorView extends ConsumerStatefulWidget {
  const _ModelSelectorView();

  @override
  ConsumerState<_ModelSelectorView> createState() => _ModelSelectorViewState();
}

class _ModelSelectorViewState extends ConsumerState<_ModelSelectorView> {
  final ScrollController _tabsController = ScrollController();
  final ScrollController _listController = ScrollController();

  String? _activeTab;
  String? _lastScrolledSelection;
  bool _showLeftArrow = false;
  bool _showRightArrow = false;

  @override
  void initState() {
    super.initState();
    _tabsController.addListener(_updateTabArrows);
  }

  @override
  void dispose() {
    _tabsController
      ..removeListener(_updateTabArrows)
      ..dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers = ref.watch(appModelProvidersProvider).value ?? const [];
    final current = ref.watch(appCurrentModelProvider).value;

    final populated = [
      for (final provider in providers)
        if (provider.models.isNotEmpty) provider,
    ];
    final currentProviderId = current?.provider.id;
    final selectedKey = current == null
        ? null
        : _identity(current.provider.id, current.model.id);
    final tabProviders = <ModelProvider>[
      for (final provider in populated)
        if (provider.id == currentProviderId) provider,
      for (final provider in populated)
        if (provider.id != currentProviderId) provider,
    ];

    final activeTab = _activeTab ?? currentProviderId ?? 'all';
    final displayed = _displayedModels(populated, activeTab);

    _scheduleArrowUpdate();
    _scrollSelectedIntoView(displayed, selectedKey, activeTab);

    return Material(
      color: _surfaceColor(theme),
      child: SafeArea(
        child: Column(
          children: [
            _header(theme),
            Divider(height: 1, color: _dividerColor(theme)),
            _tabs(theme, tabProviders, activeTab),
            Divider(height: 1, color: _dividerColor(theme)),
            Expanded(
              child: displayed.isEmpty
                  ? _emptyState(theme)
                  : ListView.separated(
                      controller: _listController,
                      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                      itemCount: displayed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final entry = displayed[index];
                        final isSelected =
                            selectedKey ==
                            _identity(entry.provider.id, entry.model.id);
                        return _ModelItem(
                          provider: entry.provider,
                          model: entry.model,
                          isSelected: isSelected,
                          onTap: () => _select(entry.provider, entry.model),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return SizedBox(
      height: 88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 20, 0),
        child: Row(
          children: [
            Text(
              '选择模型',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                height: 1.6,
                fontWeight: FontWeight.w500,
                color: _primaryTextColor(theme),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '⚡',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                color: const Color(0xFFFACC15),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'SolidJS',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF90CAF9),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 30),
              color: _secondaryTextColor(theme),
              tooltip: '关闭',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(
    ThemeData theme,
    List<ModelProvider> tabProviders,
    String activeTab,
  ) {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          SingleChildScrollView(
            controller: _tabsController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _tab(theme, label: '全部', id: 'all', activeTab: activeTab),
                for (final provider in tabProviders)
                  _tab(
                    theme,
                    label: provider.name.toUpperCase(),
                    id: provider.id,
                    activeTab: activeTab,
                  ),
              ],
            ),
          ),
          if (_showLeftArrow)
            _tabArrow(
              theme,
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left,
              onTap: () => _scrollTabs(-200),
            ),
          if (_showRightArrow)
            _tabArrow(
              theme,
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right,
              onTap: () => _scrollTabs(200),
            ),
        ],
      ),
    );
  }

  Widget _tab(
    ThemeData theme, {
    required String label,
    required String id,
    required String activeTab,
  }) {
    final active = activeTab == id;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = id;
          _lastScrolledSelection = null;
        });
      },
      child: Container(
        height: 56,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? _activeTabColor(theme) : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.43,
            fontWeight: FontWeight.w500,
            color: active ? _activeTabColor(theme) : _secondaryTextColor(theme),
          ),
        ),
      ),
    );
  }

  Widget _tabArrow(
    ThemeData theme, {
    required Alignment alignment,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Align(
      alignment: alignment,
      child: Material(
        color: _surfaceColor(theme),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 56,
            child: Icon(icon, size: 28, color: _secondaryTextColor(theme)),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Text(
        '尚未配置任何模型',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: _secondaryTextColor(theme),
        ),
      ),
    );
  }

  List<_ModelEntry> _displayedModels(
    List<ModelProvider> populated,
    String activeTab,
  ) {
    final entries = <_ModelEntry>[];
    if (activeTab == 'all') {
      for (final provider in populated) {
        entries.addAll(_entriesForProvider(provider));
      }
    } else {
      for (final provider in populated) {
        if (provider.id == activeTab) {
          entries.addAll(_entriesForProvider(provider));
          break;
        }
      }
    }
    return entries;
  }

  List<_ModelEntry> _entriesForProvider(ModelProvider provider) {
    final models = [...provider.models]
      ..sort((left, right) {
        final leftRank = _modelRank(left);
        final rightRank = _modelRank(right);
        if (leftRank != rightRank) {
          return leftRank.compareTo(rightRank);
        }
        return 0;
      });
    return [for (final model in models) _ModelEntry(provider, model)];
  }

  int _modelRank(Model model) {
    final id = model.id.toLowerCase();
    if (id == 'deepseek-v4-pro') return 0;
    if (id == 'deepseek-v4-flash') return 1;
    return 10;
  }

  Future<void> _select(ModelProvider provider, Model model) async {
    await ref
        .read(modelStoreProvider.notifier)
        .selectCurrentModel(providerId: provider.id, modelId: model.id);
    if (mounted) Navigator.of(context).pop();
  }

  void _scrollTabs(double delta) {
    if (!_tabsController.hasClients) return;
    final position = _tabsController.position;
    final target = (_tabsController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _tabsController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _updateTabArrows() {
    if (!_tabsController.hasClients) return;
    final position = _tabsController.position;
    final showLeft = position.pixels > position.minScrollExtent + 1;
    final showRight = position.pixels < position.maxScrollExtent - 1;
    if (showLeft == _showLeftArrow && showRight == _showRightArrow) return;
    setState(() {
      _showLeftArrow = showLeft;
      _showRightArrow = showRight;
    });
  }

  void _scheduleArrowUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateTabArrows();
    });
  }

  void _scrollSelectedIntoView(
    List<_ModelEntry> displayed,
    String? selectedKey,
    String activeTab,
  ) {
    if (selectedKey == null) return;
    final scrollKey = '$activeTab::$selectedKey';
    if (_lastScrolledSelection == scrollKey) return;
    final index = displayed.indexWhere(
      (entry) => selectedKey == _identity(entry.provider.id, entry.model.id),
    );
    if (index < 0) return;
    _lastScrolledSelection = scrollKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients) return;
      final position = _listController.position;
      final target = (index * 72.0)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      _listController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  static Color _activeTabColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF90CAF9)
        : const Color(0xFF64748B);
  }

  static Color _dividerColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF334155)
        : const Color(0xFFE0E0E0);
  }

  static Color _primaryTextColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF111827);
  }

  static Color _secondaryTextColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
  }

  static Color _selectedColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE5E7EB);
  }

  static Color _surfaceColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF111827)
        : Colors.white;
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
    required this.provider,
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  final ModelProvider provider;
  final Model model;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? _ModelSelectorViewState._selectedColor(theme)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _ProviderIcon(provider: provider, model: model),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName(model),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: _ModelSelectorViewState._primaryTextColor(
                            theme,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _description(provider, model),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.35,
                          color: _ModelSelectorViewState._secondaryTextColor(
                            theme,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check,
                      size: 24,
                      color: _ModelSelectorViewState._secondaryTextColor(theme),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _displayName(Model model) {
    final raw = model.name.isNotEmpty ? model.name : model.id;
    final id = model.id.toLowerCase();
    if (id == 'deepseek-v4-pro') return 'DeepSeek-V4-Pro';
    if (id == 'deepseek-v4-flash') return 'DeepSeek-V4-Flash';
    return raw;
  }

  static String _description(ModelProvider provider, Model model) {
    final description = model.description?.trim();
    if (description != null &&
        description.isNotEmpty &&
        description != '${provider.name}模型' &&
        description != '${provider.id}模型') {
      return description;
    }
    final id = model.id.toLowerCase();
    if (id == 'deepseek-v4-pro') {
      return 'DeepSeek-V4 旗舰模型（1.6T/49B），1M 上下文，混合思考模式。';
    }
    if (id == 'deepseek-v4-flash') {
      return 'DeepSeek-V4 高性价比模型（284B/13B），1M 上下文，混合思考模式。';
    }
    return '${provider.name}模型';
  }
}

class _ProviderIcon extends StatelessWidget {
  const _ProviderIcon({required this.provider, required this.model});

  final ModelProvider provider;
  final Model model;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = _assetPath(theme);
    if (asset != null) {
      return Image.asset(
        asset,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _fallback(theme),
      );
    }
    return _fallback(theme);
  }

  String? _assetPath(ThemeData theme) {
    final providerId =
        (model.provider.isNotEmpty ? model.provider : provider.id)
            .toLowerCase()
            .replaceAll('_', '-');
    final modelId = model.id.toLowerCase();
    final isDeepSeek =
        providerId.contains('deepseek') ||
        modelId.contains('deepseek') ||
        provider.name.toLowerCase().contains('deepseek');
    if (!isDeepSeek) return null;
    return theme.brightness == Brightness.dark
        ? 'assets/images/provider_deepseek_dark.png'
        : 'assets/images/provider_deepseek_light.png';
  }

  Widget _fallback(ThemeData theme) {
    final label = provider.avatar.isNotEmpty
        ? provider.avatar.characters.first
        : (provider.name.isNotEmpty ? provider.name.characters.first : '?');
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _ModelSelectorViewState._secondaryTextColor(theme),
        ),
      ),
    );
  }
}
