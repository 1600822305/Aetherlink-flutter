// 「Hooks」设置页（智能体三点菜单 / 工作区管理 → Hooks）。
//
// 信息架构：仓库 hooks 信任状态置顶（安全敏感，待审阅会亮红）；
// 已配置的手动 hooks 按事件分组直接展示；未配置事件收进按生命周期
// 阶段（AGENT / TURN / TOOL / SUBAGENT）折叠的「添加」区；无任何配置
// 时展示可一键预填的模板。编辑走全屏页（支持试跑），不再用底部弹层。
// 手动 hooks 全局生效（存储见 application/agent_manual_hooks.dart）；
// 仓库 `.aetherlink/hooks.json` 携带的 hooks 需审阅并信任后才会执行
// （信任存储见 application/agent_hooks_trust.dart），内容变更时展示
// 与已信任版本的行级差异。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/app/di/workspace_access.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_hooks_settings.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_hooks_trust.dart';
import 'package:aetherlink_flutter/features/agent/application/agent_manual_hooks.dart';
import 'package:aetherlink_flutter/features/agent/domain/agent_hooks.dart';

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

/// hook 类型的展示元数据（徽标/表单文案共用）。
typedef _TypeMeta = ({String label, Color color, IconData icon});

_TypeMeta _typeMetaOf(AgentHookType type) => switch (type) {
      AgentHookType.command => (
          label: '命令',
          color: Colors.blueGrey,
          icon: LucideIcons.terminal,
        ),
      AgentHookType.prompt => (
          label: '提示词',
          color: Colors.indigo,
          icon: LucideIcons.sparkles,
        ),
      AgentHookType.http => (
          label: 'HTTP',
          color: Colors.green,
          icon: LucideIcons.globe,
        ),
      AgentHookType.agent => (
          label: '智能体',
          color: Colors.deepPurple,
          icon: LucideIcons.bot,
        ),
    };

/// 类型徽标（图标 + 文字，不只靠颜色区分）。
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final AgentHookType type;

  @override
  Widget build(BuildContext context) {
    final meta = _typeMetaOf(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 11, color: meta.color),
          const SizedBox(width: 3),
          Text(
            meta.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: meta.color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// 生命周期事件的展示元数据（阶段分组对标 LiveAgent）。
typedef _EventMeta = ({
  String stage,
  Color color,
  String title,
  String description,
  bool canBlock,
});

_EventMeta _metaOf(AgentHookEvent event, ColorScheme scheme) =>
    switch (event) {
      AgentHookEvent.taskStart => (
          stage: 'AGENT',
          color: Colors.purple,
          title: 'taskStart',
          description: '任务启动/续跑时触发。',
          canBlock: false,
        ),
      AgentHookEvent.userPromptSubmit => (
          stage: 'AGENT',
          color: Colors.purple,
          title: 'userPromptSubmit',
          description: '用户消息进入任务前触发；hook 可拦截本条消息，'
              '也可注入 additionalContext 上下文。',
          canBlock: true,
        ),
      AgentHookEvent.turnStart => (
          stage: 'TURN',
          color: Colors.blue,
          title: 'turnStart',
          description: '每轮开始（模型调用前）触发。',
          canBlock: false,
        ),
      AgentHookEvent.preToolUse => (
          stage: 'TOOL',
          color: Colors.orange,
          title: 'preToolUse',
          description: '工具执行前触发；hook 可拦截本次调用，'
              '也可裁决免审 / 强制审批。',
          canBlock: true,
        ),
      AgentHookEvent.postToolUse => (
          stage: 'TOOL',
          color: Colors.orange,
          title: 'postToolUse',
          description: '工具成功执行后触发；hook 反馈会回填给模型（如格式化报错）。',
          canBlock: true,
        ),
      AgentHookEvent.postToolUseFailure => (
          stage: 'TOOL',
          color: Colors.orange,
          title: 'postToolUseFailure',
          description: '工具执行失败后触发；hook 反馈会回填给模型（如失败原因分析）。',
          canBlock: true,
        ),
      AgentHookEvent.permissionRequest => (
          stage: 'TOOL',
          color: Colors.orange,
          title: 'permissionRequest',
          description: '审批弹窗弹出前触发（仅本要弹审批时）；hook 可免审放行、'
              '强制拒绝或照常审批（越工作区 root 的命令不可免审）。',
          canBlock: true,
        ),
      AgentHookEvent.permissionDenied => (
          stage: 'TOOL',
          color: Colors.orange,
          title: 'permissionDenied',
          description: '用户拒绝审批后触发（观测型，不阻断）；拒绝原因经 '
              'tool_response 传入，可用于记录/通知。',
          canBlock: false,
        ),
      AgentHookEvent.notification => (
          stage: 'TOOL',
          color: Colors.orange,
          title: 'notification',
          description: '需要用户注意时触发（审批挂起 / 提问等待；观测型，不阻断）；'
              '可接外部通知。matcher 匹配通知类型（approval / question）。',
          canBlock: false,
        ),
      AgentHookEvent.fileChanged => (
          stage: 'TOOL',
          color: Colors.orange,
          title: 'fileChanged',
          description: '工作区文件变更时触发（去抖后；观测型，不阻断）。'
              'matcher 匹配变更类型（created / modified / deleted / moved），'
              'pattern 匹配文件路径；路径经 file_path、变更类型经 event 传入。',
          canBlock: false,
        ),
      AgentHookEvent.turnEnd => (
          stage: 'TURN',
          color: Colors.blue,
          title: 'turnEnd',
          description: '每轮结束（本轮工具全部执行完）触发。',
          canBlock: false,
        ),
      AgentHookEvent.stop => (
          stage: 'AGENT',
          color: Colors.purple,
          title: 'stop',
          description: '任务收尾前触发；hook 可阻止收尾并要求继续。',
          canBlock: true,
        ),
      AgentHookEvent.subagentStart => (
          stage: 'SUBAGENT',
          color: Colors.teal,
          title: 'subagentStart',
          description: '子智能体启动时触发。',
          canBlock: false,
        ),
      AgentHookEvent.subagentStop => (
          stage: 'SUBAGENT',
          color: Colors.teal,
          title: 'subagentStop',
          description: '子智能体收尾前触发；hook 可阻止收尾并要求继续。',
          canBlock: true,
        ),
      AgentHookEvent.taskEnd => (
          stage: 'AGENT',
          color: Colors.purple,
          title: 'taskEnd',
          description: '主任务正常完成后触发。',
          canBlock: false,
        ),
      AgentHookEvent.preCompact => (
          stage: 'AGENT',
          color: Colors.purple,
          title: 'preCompact',
          description: '上下文压缩前触发（观测型，不阻断）；matcher 匹配触发'
              '方式（目前仅 auto）。',
          canBlock: false,
        ),
      AgentHookEvent.postCompact => (
          stage: 'AGENT',
          color: Colors.purple,
          title: 'postCompact',
          description: '上下文压缩后触发（观测型，不阻断）；压缩摘要经 '
              'tool_response 传入；matcher 匹配触发方式（目前仅 auto）。',
          canBlock: false,
        ),
    };

/// 添加区的阶段分组顺序（同阶段事件聚在一起，与枚举顺序解耦）。
const List<(String, List<AgentHookEvent>)> _kStageGroups = [
  (
    'AGENT 阶段',
    [
      AgentHookEvent.taskStart,
      AgentHookEvent.userPromptSubmit,
      AgentHookEvent.stop,
      AgentHookEvent.taskEnd,
      AgentHookEvent.preCompact,
      AgentHookEvent.postCompact,
    ]
  ),
  ('TURN 阶段', [AgentHookEvent.turnStart, AgentHookEvent.turnEnd]),
  (
    'TOOL 阶段',
    [
      AgentHookEvent.preToolUse,
      AgentHookEvent.postToolUse,
      AgentHookEvent.postToolUseFailure,
      AgentHookEvent.permissionRequest,
      AgentHookEvent.permissionDenied,
      AgentHookEvent.notification,
      AgentHookEvent.fileChanged,
    ]
  ),
  (
    'SUBAGENT 阶段',
    [AgentHookEvent.subagentStart, AgentHookEvent.subagentStop]
  ),
];

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
        prompt: r'检查这次写文件调用是否安全（不要覆盖重要配置/删除内容）：'
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
          const _RepoHooksEntry(),
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
          for (final (stage, events) in _kStageGroups) ...[
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
      child: SwitchListTile(
        value: disabled,
        onChanged: (v) =>
            ref.read(agentDisableAllHooksProvider.notifier).set(v),
        secondary: Icon(
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
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
              leading: _TypeBadge(type: template.hook.hook.type),
              title: Text(template.title),
              subtitle: Text(
                template.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 16),
              onTap: () => _openHookEditPage(
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
    final meta = _metaOf(event, theme.colorScheme);
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                  onPressed: () => _openHookEditPage(context, event: event),
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
                  _TypeBadge(type: entry.hook.hook.type),
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
              trailing: Switch(
                value: entry.hook.enabled,
                onChanged: (value) => ref
                    .read(agentManualHooksProvider.notifier)
                    .updateAt(
                      entry.index,
                      entry.hook.copyWith(enabled: value),
                    ),
              ),
              onTap: () => _openHookEditPage(
                context,
                event: event,
                index: entry.index,
              ),
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
    final color = _metaOf(events.first, theme.colorScheme).color;

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
              Builder(builder: (context) {
                final meta = _metaOf(event, theme.colorScheme);
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
                  onTap: () => _openHookEditPage(context, event: event),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// 打开全屏编辑页；[index] 为空 = 新增，[template] 为模板预填。
void _openHookEditPage(
  BuildContext context, {
  required AgentHookEvent event,
  int? index,
  AgentManualHook? template,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => _HookEditPage(
        event: event,
        index: index,
        template: template,
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ),
  );
}

/// 常见工具名建议（matcher 快捷填入；仍可自由输入）。
const List<String> _kMatcherSuggestions = [
  '*',
  'terminal_execute',
  'terminal_*',
  'write',
  'edit',
  'read_file',
  'search_files',
  'delete_file',
  'web_search',
  'mcp:*',
];

/// http header 行（值默认遮蔽，可切换明文）。
class _HeaderRow {
  _HeaderRow(String key, String value)
      : keyCtrl = TextEditingController(text: key),
        valueCtrl = TextEditingController(text: value);

  final TextEditingController keyCtrl;
  final TextEditingController valueCtrl;
  bool obscure = true;

  void dispose() {
    keyCtrl.dispose();
    valueCtrl.dispose();
  }
}

/// 全屏编辑页：按类型的表单 + 试跑 + 删除确认。
class _HookEditPage extends ConsumerStatefulWidget {
  const _HookEditPage({required this.event, this.index, this.template});

  final AgentHookEvent event;
  final int? index;
  final AgentManualHook? template;

  @override
  ConsumerState<_HookEditPage> createState() => _HookEditPageState();
}

class _HookEditPageState extends ConsumerState<_HookEditPage> {
  AgentManualHook? get _existing => widget.index == null
      ? null
      : ref.read(agentManualHooksProvider)[widget.index!];

  late final AgentManualHook? _initial =
      widget.index != null ? _existing : widget.template;

  late AgentHookType _type = _initial?.hook.type ?? AgentHookType.command;
  late final TextEditingController _name =
      TextEditingController(text: _initial?.name ?? '');
  // 三种类型各自的载体输入，切换类型不丢已输入内容。
  late final TextEditingController _command =
      TextEditingController(text: _initial?.hook.command ?? '');
  late final TextEditingController _prompt =
      TextEditingController(text: _initial?.hook.prompt ?? '');
  late final TextEditingController _url =
      TextEditingController(text: _initial?.hook.url ?? '');
  late final TextEditingController _matcher =
      TextEditingController(text: _initial?.hook.matcher ?? '*');
  late final TextEditingController _pattern =
      TextEditingController(text: _initial?.hook.pattern ?? '*');
  late final TextEditingController _timeout = TextEditingController(
    text: '${_initial?.hook.timeoutSeconds ?? kAgentHookDefaultTimeoutSeconds}',
  );
  late final TextEditingController _model =
      TextEditingController(text: _initial?.hook.model ?? '');
  late final TextEditingController _statusMessage =
      TextEditingController(text: _initial?.hook.statusMessage ?? '');
  late bool _once = _initial?.hook.once ?? false;
  late bool _asyncRewake = _initial?.hook.asyncRewake ?? false;
  late final List<_HeaderRow> _headers = [
    for (final e in (_initial?.hook.headers ?? const {}).entries)
      _HeaderRow(e.key, e.value),
  ];
  String? _error;
  bool _tryRunning = false;

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _prompt.dispose();
    _url.dispose();
    _matcher.dispose();
    _pattern.dispose();
    _timeout.dispose();
    _model.dispose();
    _statusMessage.dispose();
    for (final row in _headers) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _toolEvent =>
      widget.event == AgentHookEvent.preToolUse ||
      widget.event == AgentHookEvent.postToolUse ||
      widget.event == AgentHookEvent.postToolUseFailure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _metaOf(widget.event, theme.colorScheme);
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
        title: Text(
          widget.index == null ? '新增 ${meta.title}' : '编辑 ${meta.title}',
        ),
        actions: [
          TextButton(onPressed: _submit, child: const Text('保存')),
          const SizedBox(width: 4),
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
            meta.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AgentHookType>(
            segments: [
              for (final type in AgentHookType.values)
                ButtonSegment(
                  value: type,
                  icon: Icon(_typeMetaOf(type).icon, size: 14),
                  label: Text(_typeMetaOf(type).label),
                ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名称（可选）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          ..._payloadFields(theme),
          if (_toolEvent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _matcher,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '匹配工具（* 全部）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (final suggestion in _kMatcherSuggestions)
                  ActionChip(
                    label: Text(
                      suggestion,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        setState(() => _matcher.text = suggestion),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pattern,
              decoration: InputDecoration(
                labelText: '匹配 pattern（* 全部）',
                helperText: _patternHelper(),
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _timeout,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '超时（秒）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (_type == AgentHookType.prompt ||
              _type == AgentHookType.agent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                labelText: '裁决模型 id（可选，缺省用当前默认模型）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _statusMessage,
            decoration: const InputDecoration(
              labelText: '运行中文案（可选，显示在任务时间线）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          SwitchListTile(
            value: _once,
            onChanged: (v) => setState(() => _once = v),
            title: const Text('只触发一次（once）'),
            subtitle: const Text('本次任务内命中一次后不再触发'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          if (_type == AgentHookType.command)
            SwitchListTile(
              value: _asyncRewake,
              onChanged: (v) => setState(() => _asyncRewake = v),
              title: const Text('后台运行并叫醒（asyncRewake）'),
              subtitle: const Text(
                  '不阻塞主链；后台跑完若阻断（退出码 2）把反馈注入任务叫醒模型'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _tryRunning ? null : _tryRun,
            icon: _tryRunning
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.play, size: 14),
            label: Text(_tryRunning ? '试跑中…' : '试跑（用示例上下文执行一次）'),
          ),
          if (widget.index != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _confirmDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('删除此 hook'),
            ),
          ],
        ],
      ),
    );
  }

  /// pattern 的语义随 matcher 变化：终端工具匹配子命令，其余匹配文件路径。
  String _patternHelper() {
    final matcher = _matcher.text.trim();
    if (matcher.startsWith('terminal')) {
      return '终端工具：匹配子命令，如 git push * / rm *';
    }
    if (matcher == '*' || matcher.isEmpty) {
      return '终端工具匹配子命令（git push *）；文件工具匹配路径 glob（lib/**）';
    }
    return '文件类工具：匹配文件路径 glob，如 lib/** / *.dart';
  }

  /// 按类型的载体输入区：命令 / 提示词 / URL+headers。
  List<Widget> _payloadFields(ThemeData theme) => switch (_type) {
        AgentHookType.command => [
            TextField(
              controller: _command,
              maxLines: 4,
              minLines: 1,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                labelText: '命令（必填）',
                helperText: '跑在任务绑定工作区的终端里；stdin 喷入 hook 输入 JSON，'
                    '退出码 2 阻断，stdout 可输出 decision JSON',
                helperMaxLines: 3,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        AgentHookType.prompt => [
            TextField(
              controller: _prompt,
              maxLines: 10,
              minLines: 4,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: '提示词（必填）',
                helperText: '用当前默认模型做一次裁决；\$ARGUMENTS 替换为 hook 输入 '
                    'JSON（缺省追加到末尾），模型回 {"ok":false,"reason":"..."} 即阻断',
                helperMaxLines: 3,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        AgentHookType.agent => [
            TextField(
              controller: _prompt,
              maxLines: 10,
              minLines: 4,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: '校验提示词（必填）',
                helperText: '多轮带工具（工作区终端）的小智能体校验；'
                    '\$ARGUMENTS 替换为 hook 输入 JSON，智能体通过 '
                    'submit_result 交回 {"ok":false,"reason":"..."} 即阻断',
                helperMaxLines: 3,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        AgentHookType.http => [
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'URL（必填，http/https）',
                helperText: 'POST hook 输入 JSON；响应体按 decision JSON 协议解析',
                helperMaxLines: 2,
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '自定义 headers（可选）',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _headers.add(_HeaderRow('', ''))),
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text('添加'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            for (var i = 0; i < _headers.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _headers[i].keyCtrl,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Header',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _headers[i].valueCtrl,
                      obscureText: _headers[i].obscure,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      decoration: InputDecoration(
                        labelText: '值',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          onPressed: () => setState(() =>
                              _headers[i].obscure = !_headers[i].obscure),
                          icon: Icon(
                            _headers[i].obscure
                                ? LucideIcons.eye
                                : LucideIcons.eyeOff,
                            size: 14,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _headers.removeAt(i).dispose();
                    }),
                    icon: const Icon(LucideIcons.x, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ],
      };

  /// 表单校验；通过时返回构建好的 hook，否则设置 [_error] 并返回 null。
  AgentManualHook? _validate() {
    final payload = switch (_type) {
      AgentHookType.command => _command.text.trim(),
      AgentHookType.prompt || AgentHookType.agent => _prompt.text.trim(),
      AgentHookType.http => _url.text.trim(),
    };
    if (payload.isEmpty) {
      setState(() => _error = switch (_type) {
            AgentHookType.command => '命令不能为空',
            AgentHookType.prompt ||
            AgentHookType.agent =>
              '提示词不能为空',
            AgentHookType.http => 'URL 不能为空',
          });
      return null;
    }
    if (_type == AgentHookType.http) {
      final uri = Uri.tryParse(payload);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        setState(() => _error = 'URL 必须是合法的 http/https 地址');
        return null;
      }
    }
    final timeoutText = _timeout.text.trim();
    final timeout = int.tryParse(timeoutText);
    if (timeoutText.isNotEmpty && (timeout == null || timeout <= 0)) {
      setState(() => _error = '超时必须是正整数（秒）');
      return null;
    }
    final headers = <String, String>{
      for (final row in _headers)
        if (row.keyCtrl.text.trim().isNotEmpty)
          row.keyCtrl.text.trim(): row.valueCtrl.text,
    };
    final name = _name.text.trim();
    final matcher = _matcher.text.trim();
    final pattern = _pattern.text.trim();
    setState(() => _error = null);
    return AgentManualHook(
      name: name.isEmpty ? payload : name,
      enabled: _existing?.enabled ?? true,
      hook: AgentHook(
        event: widget.event,
        type: _type,
        matcher: matcher.isEmpty ? '*' : matcher,
        pattern: pattern.isEmpty ? '*' : pattern,
        command: _type == AgentHookType.command ? payload : '',
        prompt: _type == AgentHookType.prompt || _type == AgentHookType.agent
            ? payload
            : '',
        url: _type == AgentHookType.http ? payload : '',
        headers: _type == AgentHookType.http ? headers : const {},
        timeoutSeconds: timeout != null && timeout > 0
            ? timeout
            : kAgentHookDefaultTimeoutSeconds,
        model: _type == AgentHookType.prompt || _type == AgentHookType.agent
            ? _model.text.trim()
            : '',
        statusMessage: _statusMessage.text.trim(),
        once: _once,
        asyncRewake: _type == AgentHookType.command ? _asyncRewake : false,
      ),
    );
  }

  void _submit() {
    final hook = _validate();
    if (hook == null) return;
    final notifier = ref.read(agentManualHooksProvider.notifier);
    if (widget.index == null) {
      notifier.add(hook);
    } else {
      notifier.updateAt(widget.index!, hook);
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除此 hook？'),
        content: Text('「${_existing?.name ?? ''}」删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(agentManualHooksProvider.notifier).removeAt(widget.index!);
    Navigator.of(context).pop();
  }

  /// 试跑：用当前表单值（未保存也可以）+ 示例上下文执行一次。
  /// command 型需要选一个工作区（跑在它的终端里）。
  Future<void> _tryRun() async {
    final manual = _validate();
    if (manual == null) return;
    String? workspaceId;
    if (_type == AgentHookType.command || _type == AgentHookType.agent) {
      final workspaces = ref.read(recentWorkspacesViewProvider);
      if (workspaces.isEmpty) {
        setState(() => _error = '试跑此类型 hook 需要先打开过一个工作区');
        return;
      }
      if (!mounted) return;
      workspaceId = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('在哪个工作区试跑？'),
          children: [
            for (final ws in workspaces)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(ws.id),
                child: Text(ws.name),
              ),
          ],
        ),
      );
      if (workspaceId == null) return;
    }
    setState(() => _tryRunning = true);
    final stopwatch = Stopwatch()..start();
    final result = await ref.read(agentHookTryRunProvider)(
      manual.hook,
      workspaceId: workspaceId,
    );
    stopwatch.stop();
    if (!mounted) return;
    setState(() => _tryRunning = false);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _TryRunResultDialog(result: result, elapsed: stopwatch.elapsed),
    );
  }
}

/// 试跑结果弹窗：裁决 + 原因 + 注入上下文 + 耗时。
class _TryRunResultDialog extends StatelessWidget {
  const _TryRunResultDialog({required this.result, required this.elapsed});

  final AgentHookResult result;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, label) = switch (result.outcome) {
      AgentHookOutcome.proceed => (
          LucideIcons.check,
          theme.colorScheme.tertiary,
          result.isAsync ? '放行（async 转后台）' : '放行',
        ),
      AgentHookOutcome.allow => (
          LucideIcons.check,
          theme.colorScheme.tertiary,
          '免审放行',
        ),
      AgentHookOutcome.ask => (
          LucideIcons.circleHelp,
          Colors.orange,
          '强制审批',
        ),
      AgentHookOutcome.block => (
          LucideIcons.ban,
          theme.colorScheme.error,
          '阻断',
        ),
      AgentHookOutcome.failed => (
          LucideIcons.triangleAlert,
          Colors.orange,
          'hook 自身失败（不阻断）',
        ),
    };
    final seconds = (elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    return AlertDialog(
      title: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text('试跑结果：$label')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result.message.isNotEmpty) ...[
            Text('原因/输出', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              result.message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
          ],
          if (result.additionalContext.isNotEmpty) ...[
            Text('注入上下文', style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              result.additionalContext,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
          ],
          if (result.preventContinuation)
            Text(
              '⏹ 该 hook 要求终止整个任务'
              '${result.stopReason.isNotEmpty ? '：${result.stopReason}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          Text(
            '耗时 ${seconds}s',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 仓库 hooks 入口（置顶）：有待审阅/内容变更的工作区时亮红提示。
class _RepoHooksEntry extends ConsumerWidget {
  const _RepoHooksEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    final trusted = ref.watch(agentHooksTrustProvider);
    var pending = 0;
    for (final ws in workspaces) {
      final raw = ref.watch(workspaceHooksFileProvider(ws.id)).value;
      if (raw != null && raw.trim().isNotEmpty && trusted[ws.id] != raw) {
        pending += 1;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pending > 0 ? theme.colorScheme.error : theme.dividerColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: Icon(
          LucideIcons.folderGit2,
          size: 18,
          color: pending > 0
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('仓库 hooks（.aetherlink/hooks.json）'),
        subtitle: Text(
          pending > 0
              ? '$pending 个工作区的 hooks 待审阅或内容已变更'
              : '仓库携带的 hooks 需审阅并信任后才会执行',
          style: theme.textTheme.bodySmall?.copyWith(
            color: pending > 0
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 16),
        onTap: () => Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const _RepoHooksPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
      ),
    );
  }
}

/// 仓库 hooks.json 审阅/信任页（工作区列表）。
class _RepoHooksPage extends ConsumerWidget {
  const _RepoHooksPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final workspaces = ref.watch(recentWorkspacesViewProvider);
    final trusted = ref.watch(agentHooksTrustProvider);

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
        title: const Text('仓库 hooks'),
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
            '工作区根目录的 .aetherlink/hooks.json 可随仓库共享 hooks 配置。'
            'hook 是任意命令，出于安全必须先审阅内容并信任后才会执行；'
            '文件内容一变，信任自动失效，需重新审阅。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          if (workspaces.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '还没有打开过工作区',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < workspaces.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 12,
                        color: theme.dividerColor,
                      ),
                    _WorkspaceHooksRow(
                      theme: theme,
                      workspaceId: workspaces[i].id,
                      workspaceName: workspaces[i].name,
                      trustedContent: trusted[workspaces[i].id],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceHooksRow extends ConsumerWidget {
  const _WorkspaceHooksRow({
    required this.theme,
    required this.workspaceId,
    required this.workspaceName,
    required this.trustedContent,
  });

  final ThemeData theme;
  final String workspaceId;
  final String workspaceName;
  final String? trustedContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileAsync = ref.watch(workspaceHooksFileProvider(workspaceId));
    final raw = fileAsync.value;
    final loading = fileAsync.isLoading;
    final hasFile = raw != null && raw.trim().isNotEmpty;
    final config = hasFile ? decodeAgentHooksConfig(raw) : null;

    final (color, label) = switch ((loading, hasFile, trustedContent == raw)) {
      (true, _, _) => (theme.colorScheme.onSurfaceVariant, '读取中…'),
      (_, false, _) => (theme.colorScheme.onSurfaceVariant, '未配置'),
      (_, true, true) => (theme.colorScheme.tertiary, '已信任'),
      _ => (
          theme.colorScheme.error,
          trustedContent == null ? '待审阅' : '内容已变更',
        ),
    };

    return ListTile(
      dense: true,
      title: Text(workspaceName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: hasFile
          ? Text(
              config == null
                  ? 'hooks.json 解析失败'
                  : '${config.hooks.length} 条 hook',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onTap: hasFile ? () => _showReviewSheet(context, ref, raw) : null,
    );
  }

  /// 审阅弹层：内容已变更时先展示与已信任版本的行级差异；按条结构化
  /// 列出 hooks（http 型高亮外部 URL），原文可展开 + 信任/撤销。
  void _showReviewSheet(BuildContext context, WidgetRef ref, String raw) {
    final isTrusted = trustedContent == raw;
    final config = decodeAgentHooksConfig(raw);
    final diff = trustedContent != null && trustedContent != raw
        ? _diffLines(trustedContent!, raw)
        : null;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$workspaceName · hooks.json',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (diff != null) ...[
                        Text(
                          '与已信任版本的差异（重点审阅新增/修改行）：',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _DiffView(theme: theme, diff: diff),
                        const SizedBox(height: 10),
                      ],
                      if (config == null)
                        Text(
                          '解析失败：不是合法的 hooks.json（每条 hook 需带 '
                          'type: command / prompt / http）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                      else if (config.hooks.isEmpty)
                        Text(
                          '没有解析出任何有效 hook（缺 type 或缺对应载体的条目会被丢弃）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        for (final hook in config.hooks) ...[
                          _RepoHookCard(theme: theme, hook: hook),
                          const SizedBox(height: 8),
                        ],
                      Theme(
                        data: theme.copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(
                            '查看原文',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme
                                    .colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                raw,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isTrusted)
                FilledButton.tonal(
                  onPressed: () {
                    ref
                        .read(agentHooksTrustProvider.notifier)
                        .revoke(workspaceId);
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('撤销信任'),
                )
              else
                FilledButton(
                  onPressed: () {
                    ref
                        .read(agentHooksTrustProvider.notifier)
                        .trust(workspaceId, raw);
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('信任并启用这些 hooks'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 行级 diff 项：' ' 未变 / '-' 删除 / '+' 新增。
typedef _DiffLine = (String tag, String line);

/// 简单 LCS 行级 diff（hooks.json 都很小，O(n·m) 足够）。
List<_DiffLine> _diffLines(String oldText, String newText) {
  final a = oldText.split('\n');
  final b = newText.split('\n');
  final lcs = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      lcs[i][j] = a[i] == b[j]
          ? lcs[i + 1][j + 1] + 1
          : (lcs[i + 1][j] > lcs[i][j + 1] ? lcs[i + 1][j] : lcs[i][j + 1]);
    }
  }
  final out = <_DiffLine>[];
  var i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      out.add((' ', a[i]));
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      out.add(('-', a[i]));
      i++;
    } else {
      out.add(('+', b[j]));
      j++;
    }
  }
  while (i < a.length) {
    out.add(('-', a[i++]));
  }
  while (j < b.length) {
    out.add(('+', b[j++]));
  }
  return out;
}

/// diff 渲染：新增绿底、删除红底、未变灰字。
class _DiffView extends StatelessWidget {
  const _DiffView({required this.theme, required this.diff});

  final ThemeData theme;
  final List<_DiffLine> diff;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (tag, line) in diff)
            Container(
              color: switch (tag) {
                '+' => Colors.green.withValues(alpha: 0.15),
                '-' => Colors.red.withValues(alpha: 0.15),
                _ => null,
              },
              child: Text(
                '$tag $line',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                  color: switch (tag) {
                    '+' => Colors.green.shade800,
                    '-' => Colors.red.shade800,
                    _ => theme.colorScheme.onSurfaceVariant,
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 仓库 hooks 审阅里的单条 hook 卡片：类型徽标 + 事件/匹配 + 载体（http URL 高亮）。
class _RepoHookCard extends StatelessWidget {
  const _RepoHookCard({required this.theme, required this.hook});

  final ThemeData theme;
  final AgentHook hook;

  @override
  Widget build(BuildContext context) {
    final scopeParts = [
      if (hook.matcher != '*') 'matcher: ${hook.matcher}',
      if (hook.pattern != '*') 'pattern: ${hook.pattern}',
      if (hook.timeoutSeconds != kAgentHookDefaultTimeoutSeconds)
        '超时 ${hook.timeoutSeconds}s',
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TypeBadge(type: hook.type),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hook.event.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hook.payload,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.4,
              // http 型高亮外部 URL：这是审阅的安全重点（数据会 POST 出去）。
              color: hook.type == AgentHookType.http
                  ? theme.colorScheme.error
                  : null,
              fontWeight:
                  hook.type == AgentHookType.http ? FontWeight.w600 : null,
            ),
          ),
          if (hook.type == AgentHookType.http && hook.headers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '自定义 headers：${hook.headers.keys.join('、')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (scopeParts.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              scopeParts.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
