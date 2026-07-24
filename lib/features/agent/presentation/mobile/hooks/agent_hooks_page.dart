// 「Hooks」设置页（智能体三点菜单 / 工作区管理 → Hooks）。
//
// 信息架构：仓库 hooks 信任状态置顶（安全敏感，待审阅会亮红）；
// 已配置的手动 hooks 按事件分组直接展示；未配置事件收进按生命周期
// 阶段（AGENT / TURN / TOOL / SUBAGENT）折叠的「添加」区；无任何配置
// 时展示可一键预填的模板。编辑走全屏页（hook_edit_page.dart，支持试跑）。
// 手动 hooks 全局生效（存储见 application/agent_manual_hooks.dart）；
// 仓库 hooks 审阅/信任见 repo_hooks_page.dart。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/features/agent/application/agent_hooks_settings.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_manual_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/hooks/hook_edit_page.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/hooks/hook_meta.dart';
import 'package:aetherlink_flutter/features/agent/presentation/mobile/hooks/repo_hooks_page.dart';
import 'package:aetherlink_flutter/features/settings/presentation/widgets/model_settings_widgets.dart';

/// 打开 Hooks 设置页。
Future<void> showAgentHooksPage(BuildContext context) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const AgentHooksPage(),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

/// 空状态一键预填模板。
typedef _HookTemplate = ({String title, String subtitle, AgentManualHook hook});

const List<_HookTemplate> _kTemplates = [
  (
    title: '推送前检查',
    subtitle: 'git push 前跑检查脚本，退出码 2 可拦截',
    hook: AgentManualHook(
      name: '推送前检查',
      hook: AgentHook(
        event: AgentHookEvent.preToolUse,
        matcher: 'terminal_execute',
        pattern: 'git push *',
        command: 'sh check-push.sh',
      ),
    ),
  ),
  (
    title: '收尾前静态分析',
    subtitle: '任务收尾前跑 analyze，有问题就要求继续修',
    hook: AgentManualHook(
      name: '收尾前静态分析',
      hook: AgentHook(
        event: AgentHookEvent.stop,
        command: 'flutter analyze --no-pub || exit 2',
      ),
    ),
  ),
  (
    title: '写文件安全裁决',
    subtitle: '用模型审一遍写文件调用是否安全',
    hook: AgentManualHook(
      name: '写文件安全裁决',
      hook: AgentHook(
        event: AgentHookEvent.preToolUse,
        type: AgentHookType.prompt,
        matcher: 'write',
        prompt:
            r'检查这次写文件调用是否安全（不要覆盖重要配置/删除内容）：'
            r'$ARGUMENTS',
      ),
    ),
  ),
];

class AgentHooksPage extends ConsumerWidget {
  const AgentHooksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hooks = ref.watch(agentManualHooksProvider);
    final enabledCount = hooks.where((h) => h.enabled).length;
    final configuredEvents = [
      for (final event in AgentHookEvent.values)
        if (hooks.any((h) => h.hook.event == event)) event,
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        centerTitle: false,
        titleSpacing: 0,
        shape: Border(bottom: BorderSide(color: theme.dividerColor)),
        leadingWidth: 44,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(LucideIcons.arrowLeft, size: 24),
            color: theme.colorScheme.primary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
        title: const Text('Hooks'),
        actions: [
          if (hooks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _CountBadge(
                  theme: theme,
                  total: hooks.length,
                  enabled: enabledCount,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            '为任务生命周期事件配置 hooks，按事件自动触发：命令型跑在任务'
            '绑定工作区的终端里，提示词型用一次模型调用裁决，HTTP 型 POST '
            '到回调 URL。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          // disableAllHooks 全局总开关：应急/调试时一键停用所有 hooks。
          const _DisableAllHooksCard(),
          const SizedBox(height: 12),
          // 仓库 hooks 置顶：待审阅/内容变更是安全敏感状态，必须先看到。
          const RepoHooksEntry(),
          const SizedBox(height: 12),
          if (hooks.isEmpty)
            _TemplatesCard(theme: theme)
          else ...[
            _SectionLabel(theme: theme, text: '已配置'),
            for (final event in configuredEvents) ...[
              _ConfiguredEventCard(event: event),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
          ],
          _SectionLabel(theme: theme, text: '按生命周期事件添加'),
          for (final (stage, events) in kHookStageGroups) ...[
            _StageGroup(stage: stage, events: events),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

/// disableAllHooks 全局总开关（对标 Claude Code 的 disableAllHooks）：
/// 开时所有事件的 hooks 暂停执行（含已信任的仓库 hooks），配置与
/// 信任状态不变，关掉即恢复；试跑是显式用户操作，不受开关限制。
/// 开时用警告色醒目提示，避免用户忘记关回。
class _DisableAllHooksCard extends ConsumerWidget {
  const _DisableAllHooksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final disabled = ref.watch(agentDisableAllHooksProvider);
    final color = disabled ? theme.colorScheme.error : theme.dividerColor;
    return Container(
      decoration: BoxDecoration(
        color: disabled
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: ListTile(
        onTap: () =>
            ref.read(agentDisableAllHooksProvider.notifier).set(!disabled),
        trailing: CustomSwitch(
          value: disabled,
          onChanged: (v) =>
              ref.read(agentDisableAllHooksProvider.notifier).set(v),
        ),
        leading: Icon(
          disabled ? LucideIcons.octagonPause : LucideIcons.power,
          size: 18,
          color: disabled
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          '停用所有 Hooks',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: disabled ? theme.colorScheme.error : null,
          ),
        ),
        subtitle: Text(
          disabled
              ? '所有事件的 hooks 已暂停执行（含已信任的仓库 hooks）。'
                    '配置与信任状态不受影响，关闭开关即恢复；试跑不受限制。'
              : '应急/调试用总开关：打开后所有事件的 hooks 暂停执行，'
                    '不改配置与信任状态。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: disabled
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.theme,
    required this.total,
    required this.enabled,
  });

  final ThemeData theme;
  final int total;
  final int enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '共 $total · 启用 $enabled',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 空状态：说明 + 一键预填模板。
class _TemplatesCard extends StatelessWidget {
  const _TemplatesCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text(
              '还没有配置 hook，从模板开始：',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final template in _kTemplates)
            ListTile(
              dense: true,
              leading: HookTypeBadge(type: template.hook.hook.type),
              title: Text(template.title),
              subtitle: Text(
                template.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () => openHookEditPage(
                context,
                event: template.hook.hook.event,
                template: template.hook,
              ),
            ),
        ],
      ),
    );
  }
}

/// 已配置事件卡片：事件标题 + 该事件下的 hooks。
class _ConfiguredEventCard extends ConsumerWidget {
  const _ConfiguredEventCard({required this.event});

  final AgentHookEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final meta = hookEventMetaOf(event);
    final all = ref.watch(agentManualHooksProvider);
    final entries = [
      for (var i = 0; i < all.length; i++)
        if (all[i].hook.event == event) (index: i, hook: all[i]),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    meta.stage,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: meta.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    meta.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => openHookEditPage(context, event: event),
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text('新增'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          for (final entry in entries) ...[
            Divider(height: 1, indent: 12, color: theme.dividerColor),
            ListTile(
              dense: true,
              title: Row(
                children: [
                  HookTypeBadge(type: entry.hook.hook.type),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      entry.hook.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                entry.hook.hook.payload,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
              trailing: CustomSwitch(
                value: entry.hook.enabled,
                onChanged: (value) => ref
                    .read(agentManualHooksProvider.notifier)
                    .updateAt(entry.index, entry.hook.copyWith(enabled: value)),
              ),
              onTap: () =>
                  openHookEditPage(context, event: event, index: entry.index),
            ),
          ],
        ],
      ),
    );
  }
}

/// 添加区：一个生命周期阶段的折叠分组，展开后列出事件。
class _StageGroup extends ConsumerWidget {
  const _StageGroup({required this.stage, required this.events});

  final String stage;
  final List<AgentHookEvent> events;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = hookEventMetaOf(events.first).color;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  stage,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${events.length} 个事件',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          children: [
            for (final event in events) ...[
              Divider(height: 1, indent: 12, color: theme.dividerColor),
              Builder(
                builder: (context) {
                  final meta = hookEventMetaOf(event);
                  return ListTile(
                    dense: true,
                    title: Text(
                      meta.title,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    subtitle: Text(
                      meta.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(LucideIcons.plus, size: 16),
                    onTap: () => openHookEditPage(context, event: event),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
