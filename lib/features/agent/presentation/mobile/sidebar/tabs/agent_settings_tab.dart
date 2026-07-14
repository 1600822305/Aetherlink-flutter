// 设置 tab：智能体独立的侧边栏设置页——功能类型对齐聊天侧边栏设置 tab
// （分组 + 开关/选择行），但内容全是智能体自己的项，代码不与聊天共享。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/router/app_router.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_providers.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_profile.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_task.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/agent_profile_edit_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// 顶栏三点菜单 →「设置」：独立全屏设置页，正文复用 [AgentSettingsTab]。
Future<void> showAgentSettingsPage(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const AgentSettingsPage(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

class AgentSettingsPage extends StatelessWidget {
  const AgentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
      body: const SafeArea(child: AgentSettingsTab()),
    );
  }
}

class AgentSettingsTab extends ConsumerWidget {
  const AgentSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(agentProfilesProvider);
    final profileId = ref.watch(selectedAgentProfileIdProvider);
    final profile =
        profiles.where((p) => p.id == profileId).firstOrNull ??
        profiles.firstOrNull;
    final s = ref.watch(agentUiSettingsControllerProvider);
    final c = ref.read(agentUiSettingsControllerProvider.notifier);
    final taskId = ref.watch(selectedAgentTaskIdProvider);
    final task = ref
        .watch(agentTasksProvider)
        .where((t) => t.id == taskId)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      children: [
        if (profile != null) ...[
          _Group(
            title: '当前智能体',
            subtitle: '${profile.emoji} ${profile.name}',
            children: [
              _StaticRow(title: '绑定工作区', value: profile.workspaceName ?? '未绑定'),
              _StaticRow(
                title: '工具集',
                value: profile.tools.map(_toolGroupLabel).join(' / '),
              ),
              _EntryRow(
                title: '编辑智能体',
                description: '名称 / 提示词 / 工具集 / 绑定工作区',
                onTap: () =>
                    showAgentProfileEditPage(context, profile: profile),
              ),
            ],
          ),
          const _GroupDivider(),
        ],
        _Group(
          title: '执行设置',
          subtitle: '默认模式: ${_modeLabel(s.defaultMode)}',
          children: [
            _SelectRow<AgentSessionMode>(
              title: '新话题默认模式',
              description:
                  'Code=执行 / Auto=工作区内免审 / Ask=只问答 / Plan=只读规划；'
                  '与输入框模式 chip 同步',
              value: s.defaultMode,
              options: [
                for (final m in AgentSessionMode.values) (m, _modeLabel(m)),
              ],
              onChanged: c.setDefaultMode,
            ),
          ],
        ),
        const _GroupDivider(),
        _Group(
          title: '上下文',
          subtitle:
              '上限 ${_formatK(s.contextLimit)}'
              '${task != null && task.contextTokens > 0 ? ' · 当前已用 ${_formatK(task.contextTokens)}' : ''}',
          children: [
            _SelectRow<int>(
              title: '会话上下文长度',
              description: '按模型窗口设置；状态栏展示 已用/上限 与剩余量',
              value: s.contextLimit,
              options: const [
                (32000, '32k'),
                (64000, '64k'),
                (128000, '128k'),
                (200000, '200k'),
                (256000, '256k'),
                (1000000, '1M'),
              ],
              onChanged: c.setContextLimit,
            ),
            if (task != null)
              _StaticRow(
                title: '当前话题已用 / 剩余',
                value: task.contextTokens > 0
                    ? '${_formatK(task.contextTokens)} / 剩 ${_formatK((s.contextLimit - task.contextTokens).clamp(0, s.contextLimit))}'
                    : '暂无数据（运行一轮后更新）',
              ),
          ],
        ),
        const _GroupDivider(),
        _Group(
          title: '事件流显示',
          subtitle: '工作段折叠与工作台跟随',
          children: [
            _SwitchRow(
              title: '自动折叠工作段',
              description: '已完结过程折叠为摘要块（含时长与 +/− 行数），点段头展开',
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
        const _GroupDivider(),
        _Group(
          title: '权限与审批',
          subtitle: '白名单沿用工作区工具授权',
          children: [
            _EntryRow(
              title: '工具授权白名单',
              description: '与工作区共用（工作区管理页 → 偏好 → 工具授权）',
              onTap: () => context.push(AppRouter.workspaceManagementPath),
            ),
            const _StaticRow(title: '越界命令', value: '永远强制审批（不可关闭）'),
          ],
        ),
        const _GroupDivider(),
        // App 级设置入口（对齐聊天设置 tab 底部的「设置」行）：
        // 直达设置页的智能体视图。
        _SettingsEntryRow(
          onTap: () => context.push('${AppRouter.settingsPath}?mode=agent'),
        ),
      ],
    );
  }
}

class _SettingsEntryRow extends StatelessWidget {
  const _SettingsEntryRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        child: Row(
          children: [
            Icon(LucideIcons.cog, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '设置',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '进入完整设置页面（智能体视图）',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatK(int tokens) => tokens >= 1000000
    ? '${(tokens / 1000000).toStringAsFixed(tokens % 1000000 == 0 ? 0 : 1)}M'
    : tokens >= 1000
        ? '${(tokens / 1000).toStringAsFixed(tokens % 1000 == 0 ? 0 : 1)}k'
        : '$tokens';

String _modeLabel(AgentSessionMode mode) => switch (mode) {
  AgentSessionMode.code => 'Code',
  AgentSessionMode.auto => 'Auto',
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

/// 可折叠分组（对齐聊天设置 tab 的手风琴分组形态）。
class _Group extends StatefulWidget {
  const _Group({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  State<_Group> createState() => _GroupState();
}

class _GroupState extends State<_Group> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
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

class _SelectRow<T> extends StatelessWidget {
  const _SelectRow({
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
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowText(title: title, description: description),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
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

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: _RowText(title: title, description: description),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
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
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.bodySmall)),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.6),
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
        Text(title, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          description,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
