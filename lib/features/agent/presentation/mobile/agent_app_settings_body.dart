// App 级设置页的「智能体设置」视图：设置页顶栏切换到智能体后渲染的正文。
// 复用 settings 的 SettingGroup 卡片形态（presentation 跨界允许），内容全是
// 智能体自己的项；聊天/通用设置正文不受影响。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_profile_edit_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_group.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/setting_item.dart';

/// 智能体设置正文（设置 hub 同款分组卡片列表）。
class AgentAppSettingsBody extends ConsumerWidget {
  const AgentAppSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(agentProfilesProvider);
    final profileId = ref.watch(selectedAgentProfileIdProvider);
    final profile = profiles.firstWhere(
      (p) => p.id == profileId,
      orElse: () => profiles.first,
    );
    final s = ref.watch(agentUiSettingsControllerProvider);
    final c = ref.read(agentUiSettingsControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SettingGroup(
          title: '当前智能体',
          children: [
            SettingItem(
              icon: LucideIcons.bot,
              title: '${profile.emoji} ${profile.name}',
              description: '编辑名称 / 提示词 / 工具集 / 绑定工作区',
              onTap: () => showAgentProfileEditPage(context, profile: profile),
            ),
            _StaticRow(title: '绑定工作区', value: profile.workspaceName ?? '未绑定'),
            _StaticRow(
              title: '工具集',
              value: profile.tools.map(_toolGroupLabel).join(' / '),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingGroup(
          title: '执行设置',
          children: [
            _ChoiceRow<AgentSessionMode>(
              title: '新话题默认模式',
              description: 'Code=执行 / Ask=只问答 / Plan=只读规划',
              value: s.defaultMode,
              options: [
                for (final m in AgentSessionMode.values) (m, _modeLabel(m)),
              ],
              onChanged: c.setDefaultMode,
            ),
          ],
        ),
        const SizedBox(height: 24),
        SettingGroup(
          title: '事件流显示',
          children: [
            _SwitchRow(
              title: '自动折叠工作段',
              description: '一段工作完成后折叠为「工作了 Ns · N 个操作」摘要块',
              value: s.autoCollapseWorkSessions,
              onChanged: c.setAutoCollapseWorkSessions,
            ),
            _SwitchRow(
              title: '焦点跟随智能体活动',
              description: '右页焦点 tab 自动切到智能体当前在做的事',
              value: s.followAiFile,
              onChanged: c.setFollowAiFile,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SettingGroup(
          title: '权限与审批',
          children: [
            SettingItem(
              icon: LucideIcons.shieldCheck,
              title: '工具授权白名单',
              description: '与工作区共用（工作区管理页 → 偏好 → 工具授权）',
              enabled: false,
            ),
            _StaticRow(title: '越界命令', value: '永远强制审批（不可关闭）'),
          ],
        ),
      ],
    );
  }
}

String _modeLabel(AgentSessionMode mode) => switch (mode) {
  AgentSessionMode.code => 'Code',
  AgentSessionMode.ask => 'Ask',
  AgentSessionMode.plan => 'Plan',
};

String _toolGroupLabel(AgentToolGroup g) => switch (g) {
  AgentToolGroup.fileEditor => '文件',
  AgentToolGroup.terminal => '终端',
  AgentToolGroup.webSearch => '网搜',
  AgentToolGroup.knowledgeBase => '知识库',
  AgentToolGroup.skills => '技能',
};

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _RowText(title: title, description: description),
          ),
          CustomSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.title,
    required this.description,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String description;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowText(title: title, description: description),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final (v, label) in options)
                ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  selected: v == value,
                  selectedColor: cs.primary.withValues(alpha: 0.12),
                  onSelected: (_) => onChanged(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaticRow extends StatelessWidget {
  const _StaticRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
    );
  }
}
