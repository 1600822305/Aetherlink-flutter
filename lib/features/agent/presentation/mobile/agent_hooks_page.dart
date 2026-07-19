// 「Hooks」设置页（工作区管理 → Hooks）。
//
// 审阅/信任各工作区根目录 `.aetherlink/hooks.json` 声明的智能体 hooks
// （preToolUse / postToolUse / stop）。hook 是任意 shell 命令，仓库携带的
// hooks 必须在这里审阅并信任后才会执行；文件内容一变，信任自动失效。
// 配置模型见 domain/agent_hooks.dart，信任存储见
// application/agent_hooks_trust.dart。

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

class AgentHooksPage extends ConsumerWidget {
  const AgentHooksPage({super.key});

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
        title: const Text('Hooks'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _HintCard(
            theme: theme,
            text: 'hook 在任务的关键节点自动执行命令：taskStart（任务启动）、'
                'preToolUse（工具执行前校验，可拦截）、postToolUse（执行后反馈，'
                '如自动格式化报错）、stop（收尾校验，不满足可要求继续）。'
                '命令跑在任务绑定工作区的终端里，退出码 2 = 阻断（输出回给模型）。',
          ),
          const SizedBox(height: 12),
          Text(
            '我的 hooks',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const _ManualHooksSection(),
          const SizedBox(height: 20),
          Text(
            '仓库 hooks（.aetherlink/hooks.json）',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '仓库携带的 hooks 必须先审阅并信任后才会执行；文件内容一变，'
            '信任自动失效。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
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

/// 「我的 hooks」：设置页手动管理的全局 hooks（增/改/删/启用开关），
/// 不依赖仓库文件，天然可信。
class _ManualHooksSection extends ConsumerWidget {
  const _ManualHooksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hooks = ref.watch(agentManualHooksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hooks.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < hooks.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 12, color: theme.dividerColor),
                  ListTile(
                    dense: true,
                    title: Text(
                      hooks[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${hooks[i].hook.event.name} · ${hooks[i].hook.command}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                    trailing: Switch(
                      value: hooks[i].enabled,
                      onChanged: (value) => ref
                          .read(agentManualHooksProvider.notifier)
                          .updateAt(i, hooks[i].copyWith(enabled: value)),
                    ),
                    onTap: () => _showEditSheet(context, ref, index: i),
                  ),
                ],
              ],
            ),
          ),
        if (hooks.isNotEmpty) const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showEditSheet(context, ref),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: const Text('添加 hook'),
        ),
      ],
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
    this.existing,
    required this.onSubmit,
    this.onDelete,
  });

  final AgentManualHook? existing;
  final void Function(AgentManualHook hook) onSubmit;
  final VoidCallback? onDelete;

  @override
  State<_ManualHookForm> createState() => _ManualHookFormState();
}

class _ManualHookFormState extends State<_ManualHookForm> {
  late AgentHookEvent _event =
      widget.existing?.hook.event ?? AgentHookEvent.preToolUse;
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _command =
      TextEditingController(text: widget.existing?.hook.command ?? '');
  late final TextEditingController _matcher =
      TextEditingController(text: widget.existing?.hook.matcher ?? '*');
  late final TextEditingController _pattern =
      TextEditingController(text: widget.existing?.hook.pattern ?? '*');
  late final TextEditingController _timeout = TextEditingController(
    text: '${widget.existing?.hook.timeoutSeconds ?? kAgentHookDefaultTimeoutSeconds}',
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
      _event == AgentHookEvent.preToolUse ||
      _event == AgentHookEvent.postToolUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? '添加 hook' : '编辑 hook',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AgentHookEvent>(
                initialValue: _event,
                decoration: const InputDecoration(
                  labelText: '事件',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final event in AgentHookEvent.values)
                    DropdownMenuItem(
                      value: event,
                      child: Text(switch (event) {
                        AgentHookEvent.taskStart => 'taskStart · 任务启动',
                        AgentHookEvent.preToolUse => 'preToolUse · 工具执行前',
                        AgentHookEvent.postToolUse =>
                          'postToolUse · 工具执行后',
                        AgentHookEvent.stop => 'stop · 收尾校验',
                      }),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _event = value);
                },
              ),
              const SizedBox(height: 10),
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
                      event: _event,
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

class _HintCard extends StatelessWidget {
  const _HintCard({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.info,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
