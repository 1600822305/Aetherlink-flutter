import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Opens the model selector — a 1:1 port of the original SolidJS
/// `DialogModelSelector` (`src/solid/components/ModelSelector`). A full-screen
/// dialog on mobile: a header (「选择模型」 + close), a horizontally-scrollable
/// provider tab row (「全部」 + the current provider first, then the rest), and a
/// grouped model list where each row shows a provider-tinted avatar, the model
/// name + description, and a check on the current selection. Picking a model
/// persists it as the app-level current chat model.
Future<void> showModelSelectorDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: _ModelSelectorView(),
    ),
  );
}

class _ModelSelectorView extends ConsumerStatefulWidget {
  const _ModelSelectorView();

  @override
  ConsumerState<_ModelSelectorView> createState() => _ModelSelectorViewState();
}

class _ModelSelectorViewState extends ConsumerState<_ModelSelectorView> {
  /// The active tab id: `'all'` or a provider id. Seeded to the current
  /// provider when the dialog opens (mirrors the original's auto-switch to
  /// 「常用」), falling back to `'all'`.
  String? _activeTab;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers = ref.watch(appModelProvidersProvider).value ?? const [];
    final current = ref.watch(appCurrentModelProvider).value;

    // Providers that actually have models, in user-defined order.
    final populated = [
      for (final p in providers)
        if (p.models.isNotEmpty) p,
    ];
    final currentProviderId = current?.provider.id;
    final selectedKey = current == null
        ? null
        : _identity(current.provider.id, current.model.id);

    // Tab order: 全部, the current provider (if it has models), then the rest.
    final tabProviders = <ModelProvider>[
      for (final p in populated)
        if (p.id == currentProviderId) p,
      for (final p in populated)
        if (p.id != currentProviderId) p,
    ];

    final activeTab = _activeTab ?? currentProviderId ?? 'all';
    final displayed = _displayedModels(populated, activeTab);

    return SafeArea(
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            _header(theme),
            Divider(height: 1, color: theme.dividerColor),
            _tabs(theme, tabProviders, activeTab),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: displayed.isEmpty
                  ? Center(
                      child: Text(
                        '尚未配置任何模型',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: displayed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final entry = displayed[index];
                        return _ModelItem(
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
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '选择模型',
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _tabs(
    ThemeData theme,
    List<ModelProvider> tabProviders,
    String activeTab,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tab(theme, label: '全部', id: 'all', activeTab: activeTab),
          for (final provider in tabProviders)
            _tab(
              theme,
              label: provider.name,
              id: provider.id,
              activeTab: activeTab,
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
      onTap: () => setState(() => _activeTab = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? theme.colorScheme.primary : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
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
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _avatar(theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      model.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w400,
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
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(ThemeData theme) {
    final color = _parseColor(provider.color) ?? theme.colorScheme.primary;
    final label = provider.avatar.isNotEmpty
        ? provider.avatar.characters.first
        : (provider.name.isNotEmpty ? provider.name.characters.first : '?');
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null) return null;
    var value = hex.replaceAll('#', '').trim();
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
}
