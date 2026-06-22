import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_combo.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Create a new model combo — sequential (thinking + generating) or comparison.
class CreateComboPage extends ConsumerStatefulWidget {
  const CreateComboPage({
    super.key,
    required this.strategy,
    required this.providers,
  });

  final ModelComboStrategy strategy;
  final List<ModelProvider> providers;

  @override
  ConsumerState<CreateComboPage> createState() => _CreateComboPageState();
}

class _CreateComboPageState extends ConsumerState<CreateComboPage> {
  final _nameController = TextEditingController();

  // Sequential: selected thinking + generating models
  String? _thinkingModelKey;
  String? _generatingModelKey;

  // Comparison: selected candidate models
  final Set<String> _candidateKeys = {};

  late final List<_FlatModel> _allModels;

  @override
  void initState() {
    super.initState();
    _allModels = _flattenModels(widget.providers);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<_FlatModel> _flattenModels(List<ModelProvider> providers) {
    final result = <_FlatModel>[];
    for (final p in providers) {
      if (!p.isEnabled) continue;
      for (final m in p.models) {
        result.add(
          _FlatModel(key: '${p.id}/${m.id}', model: m, providerName: p.name),
        );
      }
    }
    return result;
  }

  String _autoName() {
    if (widget.strategy == ModelComboStrategy.sequential) {
      final t = _allModels
          .where((m) => m.key == _thinkingModelKey)
          .firstOrNull
          ?.model
          .name;
      final g = _allModels
          .where((m) => m.key == _generatingModelKey)
          .firstOrNull
          ?.model
          .name;
      if (t != null && g != null) {
        return '${_short(t)} + ${_short(g)}';
      }
    } else {
      final names = _candidateKeys
          .map(
            (k) => _allModels.where((m) => m.key == k).firstOrNull?.model.name,
          )
          .whereType<String>()
          .map(_short)
          .toList();
      if (names.length >= 2) return names.join(' vs ');
    }
    return '';
  }

  String _short(String name) =>
      name.length > 15 ? '${name.substring(0, 12)}...' : name;

  bool get _canCreate {
    if (widget.strategy == ModelComboStrategy.sequential) {
      return _thinkingModelKey != null && _generatingModelKey != null;
    }
    return _candidateKeys.length >= 2;
  }

  void _create() {
    final name = _nameController.text.trim().isEmpty
        ? _autoName()
        : _nameController.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    final models = <ComboModelEntry>[];

    if (widget.strategy == ModelComboStrategy.sequential) {
      models.add(
        ComboModelEntry(
          modelId: _thinkingModelKey!,
          role: 'thinking',
          priority: 0,
        ),
      );
      models.add(
        ComboModelEntry(
          modelId: _generatingModelKey!,
          role: 'generating',
          priority: 1,
        ),
      );
    } else {
      for (final key in _candidateKeys) {
        models.add(ComboModelEntry(modelId: key, role: 'candidate'));
      }
    }

    final combo = ModelComboConfig(
      id: 'combo_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      strategy: widget.strategy,
      models: models,
      createdAt: now,
      updatedAt: now,
    );
    ref.read(modelComboControllerProvider.notifier).addCombo(combo);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSequential = widget.strategy == ModelComboStrategy.sequential;
    final title = isSequential ? '创建思考+生成组合' : '创建模型对比';

    // Auto-fill name field when models change
    if (_nameController.text.isEmpty) {
      final auto = _autoName();
      if (auto.isNotEmpty) {
        _nameController.text = auto;
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isSequential)
              ..._buildSequentialForm(theme)
            else
              ..._buildComparisonForm(theme),
            const SizedBox(height: 24),
            // Name field
            Text(
              '组合名称',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: '自动生成，可修改',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _canCreate ? _create : null,
                child: const Text('创建组合'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSequentialForm(ThemeData theme) {
    return [
      // Thinking model selector
      _ModelSelectorSection(
        icon: LucideIcons.brain,
        label: '推理模型（负责思考）',
        selectedKey: _thinkingModelKey,
        allModels: _allModels,
        onSelect: (key) => setState(() {
          _thinkingModelKey = key;
          _nameController.text = _autoName();
        }),
      ),
      const SizedBox(height: 16),
      Center(
        child: Icon(
          LucideIcons.arrowDown,
          size: 24,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      // Generating model selector
      _ModelSelectorSection(
        icon: LucideIcons.penTool,
        label: '生成模型（负责回答）',
        selectedKey: _generatingModelKey,
        allModels: _allModels,
        onSelect: (key) => setState(() {
          _generatingModelKey = key;
          _nameController.text = _autoName();
        }),
      ),
    ];
  }

  List<Widget> _buildComparisonForm(ThemeData theme) {
    return [
      Text(
        '选择要对比的模型（2-4个）',
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              for (var i = 0; i < _allModels.length; i++) ...[
                if (i > 0) Divider(height: 1, color: theme.dividerColor),
                CheckboxListTile(
                  value: _candidateKeys.contains(_allModels[i].key),
                  onChanged:
                      _candidateKeys.length >= 4 &&
                          !_candidateKeys.contains(_allModels[i].key)
                      ? null
                      : (val) {
                          setState(() {
                            if (val == true) {
                              _candidateKeys.add(_allModels[i].key);
                            } else {
                              _candidateKeys.remove(_allModels[i].key);
                            }
                            _nameController.text = _autoName();
                          });
                        },
                  title: Text(
                    _allModels[i].model.name,
                    style: theme.textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    _allModels[i].providerName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
              if (_allModels.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '没有可用的模型，请先在"配置模型"中添加',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _ModelSelectorSection extends StatelessWidget {
  const _ModelSelectorSection({
    required this.icon,
    required this.label,
    required this.selectedKey,
    required this.allModels,
    required this.onSelect,
  });

  final IconData icon;
  final String label;
  final String? selectedKey;
  final List<_FlatModel> allModels;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = allModels.where((m) => m.key == selectedKey).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showPicker(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: selected != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selected.model.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  selected.providerName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              '选择模型',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                    Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) {
            // Group models by provider
            final grouped = <String, List<_FlatModel>>{};
            for (final m in allModels) {
              grouped.putIfAbsent(m.providerName, () => []).add(m);
            }

            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '选择模型',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 12,
                            bottom: 4,
                          ),
                          child: Text(
                            entry.key,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        for (final m in entry.value)
                          ListTile(
                            title: Text(m.model.name),
                            trailing: m.key == selectedKey
                                ? Icon(
                                    LucideIcons.check,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            dense: true,
                            onTap: () {
                              onSelect(m.key);
                              Navigator.of(ctx).pop();
                            },
                          ),
                      ],
                      if (allModels.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              '没有可用的模型',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _FlatModel {
  const _FlatModel({
    required this.key,
    required this.model,
    required this.providerName,
  });

  final String key;
  final Model model;
  final String providerName;
}
