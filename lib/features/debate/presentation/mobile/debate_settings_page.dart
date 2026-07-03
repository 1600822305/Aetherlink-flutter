import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/chat/presentation/widgets/model_selector_dialog.dart';
import 'package:aetherlink_flutter/features/debate/application/debate_settings_controller.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_models.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_templates.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// 设置 → AI 辩论：基本参数、一键场景、角色管理与场景快照。
class DebateSettingsPage extends ConsumerWidget {
  const DebateSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(debateSettingsControllerProvider);
    final controller = ref.read(debateSettingsControllerProvider.notifier);
    final providers =
        ref.watch(appModelProvidersProvider).value ?? const <ModelProvider>[];

    return Scaffold(
      appBar: const ModelSettingsAppBar(title: 'AI 辩论'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('基本设置'),
                const SizedBox(height: 8),
                _StepperRow(
                  title: '最大辩论轮数',
                  value: settings.maxRounds,
                  min: 1,
                  max: 20,
                  onChanged: controller.setMaxRounds,
                ),
                _StepperRow(
                  title: '发言间隔（秒）',
                  value: settings.turnGapSeconds,
                  min: 0,
                  max: 10,
                  onChanged: controller.setTurnGapSeconds,
                ),
                _StepperRow(
                  title: '上下文携带的发言条数',
                  value: settings.historyWindow,
                  min: 2,
                  max: 20,
                  step: 2,
                  onChanged: controller.setHistoryWindow,
                ),
                _StepperRow(
                  title: '单次发言字数上限',
                  value: settings.maxCharsPerTurn,
                  min: 50,
                  max: 1000,
                  step: 50,
                  onChanged: controller.setMaxCharsPerTurn,
                ),
                const SizedBox(height: 4),
                _SwitchRow(
                  title: '主持人参与',
                  description: '主持人可推动讨论并在充分辩论后收束',
                  value: settings.moderatorEnabled,
                  onChanged: controller.setModeratorEnabled,
                ),
                const SizedBox(height: 8),
                _SwitchRow(
                  title: '辩论结束后生成 AI 总结',
                  description: '由总结角色（或任一已配模型的角色）输出结构化总结',
                  value: settings.summaryEnabled,
                  onChanged: controller.setSummaryEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModelSectionTitle('一键场景'),
                const SizedBox(height: 4),
                Text(
                  '快速套用内置角色组合（替换当前角色列表），套用后请为各角色指定模型',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                for (final setup in kDebateQuickSetups)
                  _QuickSetupRow(
                    setup: setup,
                    onApply: () =>
                        _applyQuickSetup(context, ref, setup, providers),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: ModelSectionTitle('辩论角色')),
                    ModelTonalButton(
                      label: '添加角色',
                      icon: LucideIcons.plus,
                      onPressed: () => _editRole(context, ref, null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (settings.roles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '暂无角色。可通过上方「一键场景」快速配置，或手动添加。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final role in settings.roles)
                    _RoleRow(
                      role: role,
                      modelName: _modelDisplayName(providers, role.modelKey),
                      onTap: () => _editRole(context, ref, role),
                      onDelete: () => ref
                          .read(debateSettingsControllerProvider.notifier)
                          .removeRole(role.id),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ModelSettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: ModelSectionTitle('场景快照')),
                    ModelTonalButton(
                      label: '保存当前',
                      icon: LucideIcons.save,
                      onPressed: settings.roles.isEmpty
                          ? null
                          : () => _saveScene(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (settings.scenes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '把当前角色与参数保存为场景，之后可随时一键载入。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final scene in settings.scenes)
                    _SceneRow(
                      scene: scene,
                      onLoad: () {
                        controller.loadScene(scene.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已载入场景「${scene.name}」')),
                        );
                      },
                      onDelete: () => controller.removeScene(scene.id),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 套用一键场景：为每个模板实例化角色，模型轮流分配已有 provider 的
  /// 不同模型（避免全员同一模型导致观点同质化）。
  void _applyQuickSetup(
    BuildContext context,
    WidgetRef ref,
    DebateQuickSetup setup,
    List<ModelProvider> providers,
  ) {
    final modelKeys = <String>[
      for (final p in providers)
        for (final m in p.models) '${p.id}/${m.id}',
    ];
    final roles = <DebateRole>[];
    var i = 0;
    for (final key in setup.templateKeys) {
      final template = debateRoleTemplateByKey(key);
      if (template == null) continue;
      roles.add(
        template.instantiate(
          id: generateId('debate_role'),
          modelKey: modelKeys.isEmpty
              ? ''
              : modelKeys[i++ % modelKeys.length],
        ),
      );
    }
    ref.read(debateSettingsControllerProvider.notifier).replaceRoles(roles);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已套用「${setup.name}」（${roles.length} 个角色）')),
    );
  }

  String _modelDisplayName(List<ModelProvider> providers, String modelKey) {
    if (modelKey.isEmpty) return '未配置模型';
    final slash = modelKey.indexOf('/');
    if (slash <= 0) return modelKey;
    final providerId = modelKey.substring(0, slash);
    final modelId = modelKey.substring(slash + 1);
    for (final p in providers) {
      if (p.id != providerId) continue;
      for (final m in p.models) {
        if (m.id == modelId) return '${p.name} / ${m.name}';
      }
    }
    return '模型已失效';
  }

  Future<void> _editRole(
    BuildContext context,
    WidgetRef ref,
    DebateRole? role,
  ) async {
    final result = await showModalBottomSheet<DebateRole>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RoleEditSheet(role: role),
    );
    if (result != null) {
      ref.read(debateSettingsControllerProvider.notifier).upsertRole(result);
    }
  }

  Future<void> _saveScene(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('保存场景'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '场景名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    ref.read(debateSettingsControllerProvider.notifier).saveScene(name: name);
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.minus, size: 16),
            onPressed: value > min ? () => onChanged(value - step) : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.plus, size: 16),
            onPressed: value < max ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _QuickSetupRow extends StatelessWidget {
  const _QuickSetupRow({required this.setup, required this.onApply});

  final DebateQuickSetup setup;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  setup.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  setup.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ModelTonalButton(label: '套用', onPressed: onApply),
        ],
      ),
    );
  }
}

class _StanceBadge extends StatelessWidget {
  const _StanceBadge({required this.stance});

  final DebateStance stance;

  @override
  Widget build(BuildContext context) {
    final color = Color(stance.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        stance.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.modelName,
    required this.onTap,
    required this.onDelete,
  });

  final DebateRole role;
  final String modelName;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _StanceBadge(stance: role.stance),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    modelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: role.hasModel
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                LucideIcons.trash2,
                size: 16,
                color: theme.colorScheme.error,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneRow extends StatelessWidget {
  const _SceneRow({
    required this.scene,
    required this.onLoad,
    required this.onDelete,
  });

  final DebateScene scene;
  final VoidCallback onLoad;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scene.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${scene.roles.length} 个角色 · ${scene.maxRounds} 轮',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          ModelTonalButton(label: '载入', onPressed: onLoad),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              LucideIcons.trash2,
              size: 16,
              color: theme.colorScheme.error,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// 角色编辑底部弹层：名称、立场、人设提示词、模板套用与模型选择。
class _RoleEditSheet extends ConsumerStatefulWidget {
  const _RoleEditSheet({this.role});

  final DebateRole? role;

  @override
  ConsumerState<_RoleEditSheet> createState() => _RoleEditSheetState();
}

class _RoleEditSheetState extends ConsumerState<_RoleEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _promptController;
  late DebateStance _stance;
  late String _modelKey;

  @override
  void initState() {
    super.initState();
    final role = widget.role;
    _nameController = TextEditingController(text: role?.name ?? '');
    _descriptionController = TextEditingController(
      text: role?.description ?? '',
    );
    _promptController = TextEditingController(text: role?.systemPrompt ?? '');
    _stance = role?.stance ?? DebateStance.neutral;
    _modelKey = role?.modelKey ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final providers =
        ref.watch(appModelProvidersProvider).value ?? const <ModelProvider>[];
    String modelLabel = '选择模型';
    if (_modelKey.isNotEmpty) {
      modelLabel = _modelKey;
      final slash = _modelKey.indexOf('/');
      if (slash > 0) {
        final providerId = _modelKey.substring(0, slash);
        final modelId = _modelKey.substring(slash + 1);
        for (final p in providers) {
          if (p.id != providerId) continue;
          for (final m in p.models) {
            if (m.id == modelId) modelLabel = '${p.name} / ${m.name}';
          }
        }
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.role == null ? '添加角色' : '编辑角色',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final template in kDebateRoleTemplates)
                  ActionChip(
                    label: Text(
                      template.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      _nameController.text = template.name;
                      _descriptionController.text = template.description;
                      _promptController.text = template.systemPrompt;
                      _stance = template.stance;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ModelFormField(
              label: '名称',
              hint: '如：正方辩手',
              controller: _nameController,
            ),
            const SizedBox(height: 12),
            ModelFormField(
              label: '简介',
              hint: '一句话描述该角色',
              controller: _descriptionController,
            ),
            const SizedBox(height: 12),
            Text(
              '立场',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final stance in DebateStance.values)
                  ChoiceChip(
                    label: Text(
                      stance.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                    selected: _stance == stance,
                    selectedColor: Color(
                      stance.colorValue,
                    ).withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _stance = stance),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ModelFormField(
              label: '人设提示词',
              hint: '角色的 system prompt',
              controller: _promptController,
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            Text(
              '模型',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.cpu, size: 16),
              label: Text(modelLabel, overflow: TextOverflow.ellipsis),
              onPressed: () => showModelSelectorDialog(
                context,
                onSelect: (p, m) =>
                    setState(() => _modelKey = '${p.id}/${m.id}'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(
                      context,
                      DebateRole(
                        id: widget.role?.id ?? generateId('debate_role'),
                        name: name,
                        description: _descriptionController.text.trim(),
                        systemPrompt: _promptController.text.trim(),
                        modelKey: _modelKey,
                        stance: _stance,
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
