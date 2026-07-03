import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/model_access.dart';
import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/core/utils/id_generator.dart';
import 'package:aetherlink_flutter/features/debate/application/debate_controller.dart';
import 'package:aetherlink_flutter/features/debate/application/debate_engine.dart';
import 'package:aetherlink_flutter/features/debate/application/debate_settings_controller.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_models.dart';
import 'package:aetherlink_flutter/features/debate/domain/debate_templates.dart';
import 'package:aetherlink_flutter/shared/domain/model_provider.dart';

/// 输入框 AI辩论 按钮的入口：辩论进行中则停止，否则打开开始面板。
///
/// 开箱即用：没有配置过角色时自动套用「基础辩论」模板并把模型轮流分配到
/// 已有的不同模型上，用户填个辩题即可开场（web 版此时只会提示「未配置」）。
Future<void> openDebateEntry(
  BuildContext context,
  WidgetRef ref, {
  String? initialTopic,
}) async {
  if (ref.read(debateControllerProvider).isDebating) {
    ref.read(debateControllerProvider.notifier).stop();
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DebateStartSheet(initialTopic: initialTopic),
  );
}

class DebateStartSheet extends ConsumerStatefulWidget {
  const DebateStartSheet({super.key, this.initialTopic});

  final String? initialTopic;

  @override
  ConsumerState<DebateStartSheet> createState() => _DebateStartSheetState();
}

class _DebateStartSheetState extends ConsumerState<DebateStartSheet> {
  late final TextEditingController _topicController;

  @override
  void initState() {
    super.initState();
    _topicController = TextEditingController(
      text: widget.initialTopic?.trim() ?? '',
    );
    // 首次使用（无角色）时自动套用基础场景，做到开箱即用。
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDefaultRoles());
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _ensureDefaultRoles() async {
    final settings = ref.read(debateSettingsControllerProvider);
    if (settings.roles.isNotEmpty) return;
    final providers = await ref.read(appModelProvidersProvider.future);
    final modelKeys = <String>[
      for (final p in providers)
        for (final m in p.models) '${p.id}/${m.id}',
    ];
    final basic = kDebateQuickSetups.first;
    final roles = <DebateRole>[];
    var i = 0;
    for (final key in basic.templateKeys) {
      final template = debateRoleTemplateByKey(key);
      if (template == null) continue;
      roles.add(
        template.instantiate(
          id: generateId('debate_role'),
          modelKey: modelKeys.isEmpty ? '' : modelKeys[i++ % modelKeys.length],
        ),
      );
    }
    ref.read(debateSettingsControllerProvider.notifier).replaceRoles(roles);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(debateSettingsControllerProvider);
    final providers =
        ref.watch(appModelProvidersProvider).value ?? const <ModelProvider>[];
    final canStart = settings.isConfigured;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '开始 AI 辩论',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(LucideIcons.settings, size: 18),
                  tooltip: '辩论设置',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(AppRouter.debateSettingsPath);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: '辩论主题',
                hintText: '输入或从下方预设辩题中选择',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _PresetTopicPicker(
              onPick: (topic) =>
                  setState(() => _topicController.text = topic),
            ),
            const SizedBox(height: 12),
            Text(
              '参与角色（${settings.roles.length}）',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final role in settings.roles)
                  _RoleChip(
                    role: role,
                    configured: _modelExists(providers, role.modelKey),
                  ),
              ],
            ),
            if (settings.roles.any(
              (r) => !_modelExists(providers, r.modelKey),
            )) ...[
              const SizedBox(height: 6),
              Text(
                '⚠️ 标灰的角色未配置有效模型，届时会跳过其发言。可在辩论设置中指定模型。',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '最多 ${settings.maxRounds} 轮 · '
              '${settings.moderatorEnabled ? '主持人可提前收束' : '主持人不参与'} · '
              '${settings.summaryEnabled ? '结束后生成 AI 总结' : '不生成总结'}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(LucideIcons.play, size: 16),
                label: const Text('开始辩论'),
                onPressed:
                    canStart && _topicController.text.trim().isNotEmpty
                    ? _start
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _modelExists(List<ModelProvider> providers, String modelKey) {
    final slash = modelKey.indexOf('/');
    if (slash <= 0) return false;
    final providerId = modelKey.substring(0, slash);
    final modelId = modelKey.substring(slash + 1);
    for (final p in providers) {
      if (p.id != providerId) continue;
      for (final m in p.models) {
        if (m.id == modelId) return true;
      }
    }
    return false;
  }

  void _start() {
    final settings = ref.read(debateSettingsControllerProvider);
    final config = DebateRunConfig(
      topic: _topicController.text.trim(),
      roles: settings.roles,
      maxRounds: settings.maxRounds,
      turnGapSeconds: settings.turnGapSeconds,
      historyWindow: settings.historyWindow,
      maxCharsPerTurn: settings.maxCharsPerTurn,
      moderatorEnabled: settings.moderatorEnabled,
      summaryEnabled: settings.summaryEnabled,
      verdictEnabled: settings.verdictEnabled,
    );
    Navigator.pop(context);
    ref.read(debateControllerProvider.notifier).start(config);
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role, required this.configured});

  final DebateRole role;
  final bool configured;

  @override
  Widget build(BuildContext context) {
    final color = configured
        ? Color(role.stance.colorValue)
        : Theme.of(context).disabledColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${role.name} · ${role.stance.label}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PresetTopicPicker extends StatelessWidget {
  const _PresetTopicPicker({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 12.5),
        ),
        icon: const Icon(LucideIcons.lightbulb, size: 14),
        label: const Text('预设辩题'),
        onPressed: () async {
          final picked = await showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: theme.colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) => DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              builder: (context, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final entry in kDebatePresetTopics.entries) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        entry.key,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final topic in entry.value)
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        title: Text(
                          topic,
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () => Navigator.pop(context, topic),
                      ),
                  ],
                ],
              ),
            ),
          );
          if (picked != null) onPick(picked);
        },
      ),
    );
  }
}
