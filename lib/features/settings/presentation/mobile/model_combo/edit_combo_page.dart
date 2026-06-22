import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_group.dart';
import 'package:aetherlink_flutter/shared/domain/model.dart';
import 'package:aetherlink_flutter/shared/domain/model_combo.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// Edit an existing model combo: rename, swap models, toggle options, delete.
class EditComboPage extends ConsumerStatefulWidget {
  const EditComboPage({
    super.key,
    required this.combo,
    required this.providers,
  });

  final ModelComboConfig combo;
  final List<ModelProvider> providers;

  @override
  ConsumerState<EditComboPage> createState() => _EditComboPageState();
}

class _EditComboPageState extends ConsumerState<EditComboPage> {
  late final TextEditingController _nameController;
  late bool _enabled;
  late bool _showThinking;
  late List<ComboModelEntry> _models;

  late final List<_FlatModel> _allModels;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.combo.name);
    _enabled = widget.combo.enabled;
    _showThinking = widget.combo.showThinking;
    _models = List.of(widget.combo.models);
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

  String _resolveModelName(String modelKey) {
    for (final m in _allModels) {
      if (m.key == modelKey) return m.model.name;
    }
    final parts = modelKey.split('/');
    return parts.length >= 2 ? parts.sublist(1).join('/') : modelKey;
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final updated = widget.combo.copyWith(
      name: name,
      enabled: _enabled,
      showThinking: _showThinking,
      models: _models,
      updatedAt: DateTime.now().toIso8601String(),
    );
    ref.read(modelComboControllerProvider.notifier).updateCombo(updated);
    Navigator.of(context).pop();
  }

  void _delete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除组合'),
        content: Text('确定要删除 "${widget.combo.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        ref
            .read(modelComboControllerProvider.notifier)
            .deleteCombo(widget.combo.id);
        Navigator.of(context).pop();
      }
    });
  }

  void _swapModel(int index) {
    final current = _models[index];
    _showModelPicker(
      context,
      selectedKey: current.modelId,
      onSelect: (key) {
        setState(() {
          _models[index] = current.copyWith(modelId: key);
        });
      },
    );
  }

  void _showModelPicker(
    BuildContext context, {
    required String selectedKey,
    required ValueChanged<String> onSelect,
  }) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final grouped = <String, List<_FlatModel>>{};
        for (final m in _allModels) {
          grouped.putIfAbsent(m.providerName, () => []).add(m);
        }
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollController) => Column(
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSequential = widget.combo.strategy == ModelComboStrategy.sequential;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.combo.name),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic info
            SettingGroup(
              title: '基本信息',
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: '名称',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '策略',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isSequential ? '思考+生成' : '对比',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                SwitchListTile.adaptive(
                  title: const Text('启用'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Model configuration
            SettingGroup(
              title: '模型配置',
              children: [
                for (var i = 0; i < _models.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: theme.dividerColor),
                  _ModelEntryRow(
                    entry: _models[i],
                    resolvedName: _resolveModelName(_models[i].modelId),
                    isSequential: isSequential,
                    onSwap: () => _swapModel(i),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Options (sequential only)
            if (isSequential) ...[
              SettingGroup(
                title: '高级选项',
                children: [
                  SwitchListTile.adaptive(
                    title: const Text('显示思考过程'),
                    subtitle: const Text('在聊天界面展示推理模型的思考过程'),
                    value: _showThinking,
                    onChanged: (v) => setState(() => _showThinking = v),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Delete
            Center(
              child: TextButton.icon(
                onPressed: _delete,
                icon: Icon(
                  LucideIcons.trash2,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  '删除组合',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ModelEntryRow extends StatelessWidget {
  const _ModelEntryRow({
    required this.entry,
    required this.resolvedName,
    required this.isSequential,
    required this.onSwap,
  });

  final ComboModelEntry entry;
  final String resolvedName;
  final bool isSequential;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = switch (entry.role) {
      'thinking' => '🧠 推理',
      'generating' => '✍️ 生成',
      _ => '候选',
    };

    return InkWell(
      onTap: onSwap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                roleLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                resolvedName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              LucideIcons.arrowLeftRight,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
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
