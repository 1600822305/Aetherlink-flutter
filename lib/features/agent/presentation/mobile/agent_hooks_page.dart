// 「Hooks」设置页（智能体三点菜单 / 工作区管理 → Hooks）。
//
// 对标 LiveAgent 的生命周期 Hooks 设计：按生命周期阶段（AGENT / TURN /
// TOOL）分组展示全部事件，每个事件下直接新增/编辑/删除/启用 hook。
// 手动 hooks 全局生效（存储见 application/agent_manual_hooks.dart）；
// 仓库 `.aetherlink/hooks.json` 携带的 hooks 收在页尾单独入口，仍需
// 审阅并信任后才会执行（信任存储见 application/agent_hooks_trust.dart）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:aetherlink_flutter/app/di/agent_runtime_access.dart';
import 'package:aetherlink_flutter/app/di/workspace_access.dart';
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
          stage: 'AGENT 阶段',
          color: Colors.purple,
          title: 'taskStart',
          description: '任务启动/续跑时触发。',
          canBlock: false,
        ),
      AgentHookEvent.turnStart => (
          stage: 'TURN 阶段',
          color: Colors.blue,
          title: 'turnStart',
          description: '每轮开始（模型调用前）触发。',
          canBlock: false,
        ),
      AgentHookEvent.preToolUse => (
          stage: 'TOOL 阶段',
          color: Colors.orange,
          title: 'preToolUse',
          description: '工具执行前触发；退出码 2 可拦截本次调用。',
          canBlock: true,
        ),
      AgentHookEvent.postToolUse => (
          stage: 'TOOL 阶段',
          color: Colors.orange,
          title: 'postToolUse',
          description: '工具成功执行后触发；输出可回填给模型（如格式化报错）。',
          canBlock: true,
        ),
      AgentHookEvent.turnEnd => (
          stage: 'TURN 阶段',
          color: Colors.blue,
          title: 'turnEnd',
          description: '每轮结束（本轮工具全部执行完）触发。',
          canBlock: false,
        ),
      AgentHookEvent.stop => (
          stage: 'AGENT 阶段',
          color: Colors.purple,
          title: 'stop',
          description: '任务收尾前触发；退出码 2 可阻止收尾并要求继续。',
          canBlock: true,
        ),
    };

class AgentHooksPage extends ConsumerWidget {
  const AgentHooksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hooks = ref.watch(agentManualHooksProvider);
    final enabledCount = hooks.where((h) => h.enabled).length;

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
            '为任务生命周期事件配置 shell 命令：命令跑在任务绑定工作区的'
            '终端里，按事件自动触发。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          for (final event in AgentHookEvent.values) ...[
            _EventSection(event: event),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          _RepoHooksEntry(theme: theme),
        ],
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

/// 一个生命周期事件的卡片：阶段徽标 + 事件说明 + hooks 列表 + 新增。
class _EventSection extends ConsumerWidget {
  const _EventSection({required this.event});

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
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
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
                  onPressed: () => _showEditSheet(context, ref),
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text('新增'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
            child: Text(
              meta.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in entries) ...[
            Divider(height: 1, indent: 12, color: theme.dividerColor),
            ListTile(
              dense: true,
              title: Text(
                entry.hook.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                entry.hook.hook.command,
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
              onTap: () => _showEditSheet(context, ref, index: entry.index),
            ),
          ],
        ],
      ),
    );
  }

  /// 添加/编辑弹层；[index] 为空 = 新增。
  void _showEditSheet(BuildContext context, WidgetRef ref, {int? index}) {
    final existing =
        index == null ? null : ref.read(agentManualHooksProvider)[index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _ManualHookForm(
          event: event,
          existing: existing,
          onSubmit: (hook) {
            final notifier = ref.read(agentManualHooksProvider.notifier);
            if (index == null) {
              notifier.add(hook);
            } else {
              notifier.updateAt(index, hook);
            }
            Navigator.of(sheetContext).pop();
          },
          onDelete: index == null
              ? null
              : () {
                  ref.read(agentManualHooksProvider.notifier).removeAt(index);
                  Navigator.of(sheetContext).pop();
                },
        ),
      ),
    );
  }
}

class _ManualHookForm extends StatefulWidget {
  const _ManualHookForm({
    required this.event,
    this.existing,
    required this.onSubmit,
    this.onDelete,
  });

  final AgentHookEvent event;
  final AgentManualHook? existing;
  final void Function(AgentManualHook hook) onSubmit;
  final VoidCallback? onDelete;

  @override
  State<_ManualHookForm> createState() => _ManualHookFormState();
}

class _ManualHookFormState extends State<_ManualHookForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _command =
      TextEditingController(text: widget.existing?.hook.command ?? '');
  late final TextEditingController _matcher =
      TextEditingController(text: widget.existing?.hook.matcher ?? '*');
  late final TextEditingController _pattern =
      TextEditingController(text: widget.existing?.hook.pattern ?? '*');
  late final TextEditingController _timeout = TextEditingController(
    text:
        '${widget.existing?.hook.timeoutSeconds ?? kAgentHookDefaultTimeoutSeconds}',
  );

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _matcher.dispose();
    _pattern.dispose();
    _timeout.dispose();
    super.dispose();
  }

  bool get _toolEvent =>
      widget.event == AgentHookEvent.preToolUse ||
      widget.event == AgentHookEvent.postToolUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _metaOf(widget.event, theme.colorScheme);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? '新增 ${meta.title} hook'
                    : '编辑 ${meta.title} hook',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meta.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
              const SizedBox(height: 10),
              TextField(
                controller: _command,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: '命令（必填，跑在任务绑定工作区的终端里）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              if (_toolEvent) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _matcher,
                  decoration: const InputDecoration(
                    labelText: '匹配工具（* 全部；如 terminal_execute / write_file）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pattern,
                  decoration: const InputDecoration(
                    labelText: '匹配 pattern（* 全部；如 git push * / lib/**）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _timeout,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '超时（秒）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final command = _command.text.trim();
                  if (command.isEmpty) return;
                  final name = _name.text.trim();
                  final matcher = _matcher.text.trim();
                  final pattern = _pattern.text.trim();
                  final timeout = int.tryParse(_timeout.text.trim());
                  widget.onSubmit(AgentManualHook(
                    name: name.isEmpty ? command : name,
                    enabled: widget.existing?.enabled ?? true,
                    hook: AgentHook(
                      event: widget.event,
                      matcher: matcher.isEmpty ? '*' : matcher,
                      pattern: pattern.isEmpty ? '*' : pattern,
                      command: command,
                      timeoutSeconds: timeout != null && timeout > 0
                          ? timeout
                          : kAgentHookDefaultTimeoutSeconds,
                    ),
                  ));
                },
                child: const Text('保存'),
              ),
              if (widget.onDelete != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.onDelete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('删除此 hook'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 页尾入口：仓库携带的 hooks.json 审阅/信任（收进单独页面，不铺屏）。
class _RepoHooksEntry extends StatelessWidget {
  const _RepoHooksEntry({required this.theme});

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
      child: ListTile(
        dense: true,
        leading: Icon(
          LucideIcons.folderGit2,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: const Text('仓库 hooks（.aetherlink/hooks.json）'),
        subtitle: Text(
          '仓库携带的 hooks 需审阅并信任后才会执行',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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

/// 仓库 hooks.json 审阅/信任页（原 Hooks 页的工作区列表）。
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

  /// 审阅弹层：展示 hooks.json 原文 + 信任/撤销。
  void _showReviewSheet(BuildContext context, WidgetRef ref, String raw) {
    final isTrusted = trustedContent == raw;
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
                constraints: const BoxConstraints(maxHeight: 320),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      raw,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
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
