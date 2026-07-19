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

/// hook 类型的展示元数据（徽标/表单文案共用）。
typedef _TypeMeta = ({String label, Color color});

_TypeMeta _typeMetaOf(AgentHookType type) => switch (type) {
      AgentHookType.command => (label: '命令', color: Colors.blueGrey),
      AgentHookType.prompt => (label: '提示词', color: Colors.indigo),
      AgentHookType.http => (label: 'HTTP', color: Colors.green),
    };

/// 类型徽标（手动 hooks 列表 / 仓库 hooks 审阅共用）。
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
      child: Text(
        meta.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: meta.color,
              fontWeight: FontWeight.w700,
            ),
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
          stage: 'AGENT 阶段',
          color: Colors.purple,
          title: 'taskStart',
          description: '任务启动/续跑时触发。',
          canBlock: false,
        ),
      AgentHookEvent.userPromptSubmit => (
          stage: 'AGENT 阶段',
          color: Colors.purple,
          title: 'userPromptSubmit',
          description: '用户消息进入任务前触发；hook 可拦截本条消息，'
              '也可注入 additionalContext 上下文。',
          canBlock: true,
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
          description: '工具执行前触发；hook 可拦截本次调用，'
              '也可裁决免审 / 强制审批。',
          canBlock: true,
        ),
      AgentHookEvent.postToolUse => (
          stage: 'TOOL 阶段',
          color: Colors.orange,
          title: 'postToolUse',
          description: '工具成功执行后触发；hook 反馈会回填给模型（如格式化报错）。',
          canBlock: true,
        ),
      AgentHookEvent.postToolUseFailure => (
          stage: 'TOOL 阶段',
          color: Colors.orange,
          title: 'postToolUseFailure',
          description: '工具执行失败后触发；hook 反馈会回填给模型（如失败原因分析）。',
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
          description: '任务收尾前触发；hook 可阻止收尾并要求继续。',
          canBlock: true,
        ),
      AgentHookEvent.subagentStart => (
          stage: 'SUBAGENT 阶段',
          color: Colors.teal,
          title: 'subagentStart',
          description: '子智能体启动时触发。',
          canBlock: false,
        ),
      AgentHookEvent.subagentStop => (
          stage: 'SUBAGENT 阶段',
          color: Colors.teal,
          title: 'subagentStop',
          description: '子智能体收尾前触发；hook 可阻止收尾并要求继续。',
          canBlock: true,
        ),
      AgentHookEvent.taskEnd => (
          stage: 'AGENT 阶段',
          color: Colors.purple,
          title: 'taskEnd',
          description: '任务正常结束后触发。',
          canBlock: false,
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
            '为任务生命周期事件配置 hooks，按事件自动触发：命令型跑在任务'
            '绑定工作区的终端里，提示词型用一次模型调用裁决，HTTP 型 POST '
            '到回调 URL。',
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
  late AgentHookType _type =
      widget.existing?.hook.type ?? AgentHookType.command;
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  // 三种类型各自的载体输入，切换类型不丢已输入内容。
  late final TextEditingController _command =
      TextEditingController(text: widget.existing?.hook.command ?? '');
  late final TextEditingController _prompt =
      TextEditingController(text: widget.existing?.hook.prompt ?? '');
  late final TextEditingController _url =
      TextEditingController(text: widget.existing?.hook.url ?? '');
  late final TextEditingController _matcher =
      TextEditingController(text: widget.existing?.hook.matcher ?? '*');
  late final TextEditingController _pattern =
      TextEditingController(text: widget.existing?.hook.pattern ?? '*');
  late final TextEditingController _timeout = TextEditingController(
    text:
        '${widget.existing?.hook.timeoutSeconds ?? kAgentHookDefaultTimeoutSeconds}',
  );
  late final List<(TextEditingController, TextEditingController)> _headers = [
    for (final e in (widget.existing?.hook.headers ?? const {}).entries)
      (
        TextEditingController(text: e.key),
        TextEditingController(text: e.value),
      ),
  ];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _prompt.dispose();
    _url.dispose();
    _matcher.dispose();
    _pattern.dispose();
    _timeout.dispose();
    for (final (k, v) in _headers) {
      k.dispose();
      v.dispose();
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
              SegmentedButton<AgentHookType>(
                segments: const [
                  ButtonSegment(
                    value: AgentHookType.command,
                    label: Text('命令'),
                  ),
                  ButtonSegment(
                    value: AgentHookType.prompt,
                    label: Text('提示词'),
                  ),
                  ButtonSegment(
                    value: AgentHookType.http,
                    label: Text('HTTP'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
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
              ..._payloadFields(theme),
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
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(onPressed: _submit, child: const Text('保存')),
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
              maxLines: 8,
              minLines: 3,
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
            const SizedBox(height: 10),
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
                  onPressed: () => setState(() => _headers.add(
                        (TextEditingController(), TextEditingController()),
                      )),
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
                      controller: _headers[i].$1,
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
                      controller: _headers[i].$2,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: '值',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      final (k, v) = _headers.removeAt(i);
                      k.dispose();
                      v.dispose();
                    }),
                    icon: const Icon(LucideIcons.x, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ],
      };

  void _submit() {
    final payload = switch (_type) {
      AgentHookType.command => _command.text.trim(),
      AgentHookType.prompt => _prompt.text.trim(),
      AgentHookType.http => _url.text.trim(),
    };
    if (payload.isEmpty) {
      setState(() => _error = switch (_type) {
            AgentHookType.command => '命令不能为空',
            AgentHookType.prompt => '提示词不能为空',
            AgentHookType.http => 'URL 不能为空',
          });
      return;
    }
    if (_type == AgentHookType.http) {
      final uri = Uri.tryParse(payload);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        setState(() => _error = 'URL 必须是合法的 http/https 地址');
        return;
      }
    }
    final headers = <String, String>{
      for (final (k, v) in _headers)
        if (k.text.trim().isNotEmpty) k.text.trim(): v.text,
    };
    final name = _name.text.trim();
    final matcher = _matcher.text.trim();
    final pattern = _pattern.text.trim();
    final timeout = int.tryParse(_timeout.text.trim());
    widget.onSubmit(AgentManualHook(
      name: name.isEmpty ? payload : name,
      enabled: widget.existing?.enabled ?? true,
      hook: AgentHook(
        event: widget.event,
        type: _type,
        matcher: matcher.isEmpty ? '*' : matcher,
        pattern: pattern.isEmpty ? '*' : pattern,
        command: _type == AgentHookType.command ? payload : '',
        prompt: _type == AgentHookType.prompt ? payload : '',
        url: _type == AgentHookType.http ? payload : '',
        headers: _type == AgentHookType.http ? headers : const {},
        timeoutSeconds: timeout != null && timeout > 0
            ? timeout
            : kAgentHookDefaultTimeoutSeconds,
      ),
    ));
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

  /// 审阅弹层：按条结构化列出 hooks（http 型高亮外部 URL），原文可展开 + 信任/撤销。
  void _showReviewSheet(BuildContext context, WidgetRef ref, String raw) {
    final isTrusted = trustedContent == raw;
    final config = decodeAgentHooksConfig(raw);
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
                constraints: const BoxConstraints(maxHeight: 360),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
