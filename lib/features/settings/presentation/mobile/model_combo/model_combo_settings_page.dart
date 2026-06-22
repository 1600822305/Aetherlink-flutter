import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/features/settings/application/model_combo_controller.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_combo/create_combo_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/mobile/model_combo/edit_combo_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_group.dart';
import 'package:aetherlink_flutter/shared/domain/model_combo.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// The model combo settings page — lists existing combos and offers creation.
class ModelComboSettingsPage extends ConsumerWidget {
  const ModelComboSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final comboState = ref.watch(modelComboControllerProvider);
    // Use .value — providers are always loaded before the user can reach
    // settings, so this resolves synchronously (no loading frame).
    final providers = ref.watch(appModelProvidersProvider).value ?? const [];

    final recommendations = _buildRecommendations(providers, comboState.combos);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('模型组合'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick-create section
            SettingGroup(
              title: '快速创建',
              children: [
                _QuickCreateRow(
                  icon: LucideIcons.brain,
                  label: '思考 + 生成',
                  description: '推理模型思考，生成模型回答',
                  onTap: () => _pushCreate(
                    context,
                    ModelComboStrategy.sequential,
                    providers,
                  ),
                ),
                Divider(height: 1, color: theme.dividerColor),
                _QuickCreateRow(
                  icon: LucideIcons.gitCompareArrows,
                  label: '模型对比',
                  description: '多模型并行回答，选最佳',
                  onTap: () => _pushCreate(
                    context,
                    ModelComboStrategy.comparison,
                    providers,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Existing combos
            if (comboState.combos.isNotEmpty) ...[
              SettingGroup(
                title: '我的组合',
                children: [
                  for (var i = 0; i < comboState.combos.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: theme.dividerColor),
                    _ComboCard(
                      combo: comboState.combos[i],
                      providers: providers,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Recommended combos
            if (recommendations.isNotEmpty)
              SettingGroup(
                title: '推荐组合',
                children: [
                  for (var i = 0; i < recommendations.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: theme.dividerColor),
                    _RecommendationRow(
                      rec: recommendations[i],
                      onUse: () {
                        final now = DateTime.now().toIso8601String();
                        final combo = ModelComboConfig(
                          id: 'combo_${DateTime.now().millisecondsSinceEpoch}',
                          name: recommendations[i].name,
                          description: recommendations[i].description,
                          strategy: recommendations[i].strategy,
                          models: recommendations[i].models,
                          createdAt: now,
                          updatedAt: now,
                        );
                        ref
                            .read(modelComboControllerProvider.notifier)
                            .addCombo(combo);
                      },
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _pushCreate(
    BuildContext context,
    ModelComboStrategy strategy,
    List<ModelProvider> providers,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CreateComboPage(strategy: strategy, providers: providers),
      ),
    );
  }

  List<_Recommendation> _buildRecommendations(
    List<ModelProvider> providers,
    List<ModelComboConfig> existing,
  ) {
    final allModels = <_FlatModel>[];
    for (final p in providers) {
      if (!p.isEnabled) continue;
      for (final m in p.models) {
        allModels.add(
          _FlatModel(
            providerId: p.id,
            modelId: m.id,
            name: m.name,
            providerName: p.name,
          ),
        );
      }
    }

    final existingNames = existing.map((c) => c.name).toSet();
    final recs = <_Recommendation>[];

    // Find thinking models (deepseek r1, qwen qwq, etc.)
    final thinkingModels = allModels.where((m) {
      final lower = m.modelId.toLowerCase();
      return lower.contains('r1') ||
          lower.contains('qwq') ||
          lower.contains('thinking') ||
          lower.contains('reason');
    }).toList();

    // Find powerful generation models
    final genModels = allModels.where((m) {
      final lower = m.modelId.toLowerCase();
      return lower.contains('claude') ||
          lower.contains('gpt-4') ||
          lower.contains('gemini');
    }).toList();

    if (thinkingModels.isNotEmpty && genModels.isNotEmpty) {
      final think = thinkingModels.first;
      final gen = genModels.first;
      final name = '${_shortName(think.name)} + ${_shortName(gen.name)}';
      if (!existingNames.contains(name)) {
        recs.add(
          _Recommendation(
            name: name,
            description: '${think.name} 思考，${gen.name} 生成',
            strategy: ModelComboStrategy.sequential,
            models: [
              ComboModelEntry(
                modelId: '${think.providerId}/${think.modelId}',
                role: 'thinking',
                priority: 0,
              ),
              ComboModelEntry(
                modelId: '${gen.providerId}/${gen.modelId}',
                role: 'generating',
                priority: 1,
              ),
            ],
            icon: '🧠',
          ),
        );
      }
    }

    // Comparison: if 2+ powerful models available
    if (genModels.length >= 2) {
      final a = genModels[0];
      final b = genModels[1];
      final name = '${_shortName(a.name)} vs ${_shortName(b.name)}';
      if (!existingNames.contains(name)) {
        recs.add(
          _Recommendation(
            name: name,
            description: '对比 ${a.name} 和 ${b.name} 的回答',
            strategy: ModelComboStrategy.comparison,
            models: [
              ComboModelEntry(
                modelId: '${a.providerId}/${a.modelId}',
                role: 'candidate',
              ),
              ComboModelEntry(
                modelId: '${b.providerId}/${b.modelId}',
                role: 'candidate',
              ),
            ],
            icon: '⚡',
          ),
        );
      }
    }

    return recs;
  }

  String _shortName(String name) {
    // Keep first word + version, e.g. "DeepSeek R1" → "DeepSeek R1"
    if (name.length > 20) return '${name.substring(0, 17)}...';
    return name;
  }
}

class _FlatModel {
  const _FlatModel({
    required this.providerId,
    required this.modelId,
    required this.name,
    required this.providerName,
  });

  final String providerId;
  final String modelId;
  final String name;
  final String providerName;
}

class _Recommendation {
  const _Recommendation({
    required this.name,
    required this.description,
    required this.strategy,
    required this.models,
    required this.icon,
  });

  final String name;
  final String description;
  final ModelComboStrategy strategy;
  final List<ComboModelEntry> models;
  final String icon;
}

class _QuickCreateRow extends StatelessWidget {
  const _QuickCreateRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComboCard extends ConsumerWidget {
  const _ComboCard({required this.combo, required this.providers});

  final ModelComboConfig combo;
  final List<ModelProvider> providers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strategyLabel = combo.strategy == ModelComboStrategy.sequential
        ? '思考+生成'
        : '对比';
    final modelNames = _resolveModelNames(combo.models, providers);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EditComboPage(combo: combo, providers: providers),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          combo.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          strategyLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    modelNames,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Enable/disable toggle
            Switch.adaptive(
              value: combo.enabled,
              onChanged: (_) => ref
                  .read(modelComboControllerProvider.notifier)
                  .toggleComboEnabled(combo.id),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveModelNames(
    List<ComboModelEntry> models,
    List<ModelProvider> providers,
  ) {
    final names = <String>[];
    for (final entry in models) {
      final parts = entry.modelId.split('/');
      final pId = parts.length >= 2 ? parts[0] : '';
      final mId = parts.length >= 2
          ? parts.sublist(1).join('/')
          : entry.modelId;
      String? resolved;
      for (final p in providers) {
        if (p.id == pId) {
          for (final m in p.models) {
            if (m.id == mId) {
              resolved = m.name;
              break;
            }
          }
          break;
        }
      }
      names.add(resolved ?? mId);
    }
    if (models.length == 2 && models[0].role == 'thinking') {
      return '${names[0]} → ${names[1]}';
    }
    return names.join(' ↔ ');
  }
}

class _RecommendationRow extends StatelessWidget {
  const _RecommendationRow({required this.rec, required this.onUse});

  final _Recommendation rec;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(rec.icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rec.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onUse, child: const Text('用这个')),
        ],
      ),
    );
  }
}
